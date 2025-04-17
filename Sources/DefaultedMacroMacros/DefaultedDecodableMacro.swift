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

        let members: [VariableDeclSyntax] = structDecl.memberBlock.members.compactMap {
            $0.decl.as(VariableDeclSyntax.self)
        }

        // Generate CodingKeys enum
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

        let assignments: [String] = members.compactMap { variable -> String? in
            guard let binding = variable.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  let type = binding.typeAnnotation?.type.description.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }

            let decode = "try container.decodeIfPresent(\(type).self, forKey: .\(identifier))"
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
                fallback = """
                ?? {
                    #if DEBUG
                    assertionFailure("Missing default for field: \(identifier) of unsupported type: \(type)")
                    #endif
                    fatalError("Unsupported type")
                }()
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

        return [
            DeclSyntax(stringLiteral: codingKeysEnum),
            DeclSyntax(stringLiteral: initFunction)
        ]
    }
}
