import SwiftSyntaxMacros
import SwiftDiagnostics
import SwiftSyntax

public struct DefaultedDecodableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            return []
        }

        // Check if CodingKeys already exists
        let hasExistingCodingKeys = structDecl.memberBlock.members.contains { member in
            if let enumDecl = member.decl.as(EnumDeclSyntax.self),
               enumDecl.name.text == "CodingKeys" {
                return true
            }
            return false
        }

        let members: [VariableDeclSyntax] = structDecl.memberBlock.members.compactMap {
            $0.decl.as(VariableDeclSyntax.self)
        }

        var generatedDecls: [DeclSyntax] = []

        // Only generate CodingKeys if it doesn't exist
        if !hasExistingCodingKeys {
            let codingKeysCases = members.compactMap { variable -> String? in
                guard let binding = variable.bindings.first,
                      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                    return nil
                }
                return "case \(identifier)"
            }.joined(separator: "\n    ")
            
            let codingKeysEnum = """
            private enum CodingKeys: String, CodingKey {
                \(codingKeysCases)
            }
            """
            generatedDecls.append(DeclSyntax(stringLiteral: codingKeysEnum))
        }

        let assignments: [String] = members.compactMap { variable -> String? in
            guard let binding = variable.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  let type = binding.typeAnnotation?.type.description.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }

            // Check if the type is a struct that might use @DefaultedDecodable
            let isNestedStruct = type.contains(".") && !type.hasPrefix("[") && !type.hasSuffix("]")
            
            let decode: String
            if isNestedStruct {
                // For nested structs, we'll try to decode them directly
                decode = "try container.decode(\(type).self, forKey: .\(identifier))"
            } else {
                decode = "try container.decodeIfPresent(\(type).self, forKey: .\(identifier))"
            }

            let fallback: String

            if type.hasSuffix("?") {
                // For optional properties, just decode them without a default value
                return "self.\(identifier) = \(decode)"
            }

            switch type {
            case "String":
                fallback = """
                ?? {
                    #if DEBUG
                    assertionFailure("Missing key for field: \(identifier)")
                    #endif
                    return ""
                }()
                """
            case "Bool":
                fallback = """
                ?? {
                    #if DEBUG
                    assertionFailure("Missing key for field: \(identifier)")
                    #endif
                    return false
                }()
                """
            case "Int":
                fallback = """
                ?? {
                    #if DEBUG
                    assertionFailure("Missing key for field: \(identifier)")
                    #endif
                    return 0
                }()
                """
            case "Double":
                fallback = """
                ?? {
                    #if DEBUG
                    assertionFailure("Missing key for field: \(identifier)")
                    #endif
                    return 0.0
                }()
                """
            case let type where type.hasPrefix("[") && type.hasSuffix("]") && !type.contains(":"):
                fallback = """
                ?? {
                    #if DEBUG
                    assertionFailure("Missing key for field: \(identifier)")
                    #endif
                    return []
                }()
                """
            case let type where type.hasPrefix("[") && type.contains(":") && type.hasSuffix("]"):
                fallback = """
                ?? {
                    #if DEBUG
                    assertionFailure("Missing key for field: \(identifier)")
                    #endif
                    return [:]
                }()
                """
            default:
                if isNestedStruct {
                    // For nested structs, we don't need a fallback as they'll be decoded directly
                    return "self.\(identifier) = \(decode)"
                }
                // For unsupported types, try to decode them directly
                return """
                do {
                    self.\(identifier) = try container.decode(\(type).self, forKey: .\(identifier))
                } catch {
                    #if DEBUG
                    assertionFailure("Failed to decode field: \(identifier) of type: \(type). Error: \\(error)")
                    #endif
                    throw error
                }
                """
            }

            return "self.\(identifier) = \(decode) \(fallback)"
        }

        let initFunction = """
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            \(assignments.joined(separator: "\n    "))
        }
        """

        generatedDecls.append(DeclSyntax(stringLiteral: initFunction))
        return generatedDecls
    }
}
