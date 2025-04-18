import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct DefaultedDecodableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            return []
        }

        let members = structDecl.memberBlock.members
        let properties = members.compactMap { member -> (name: String, type: String, customKey: String?)? in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  let binding = variable.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let type = binding.typeAnnotation?.type else {
                return nil
            }
            return (identifier.identifier.text, type.description, nil)
        }

        // Check if CodingKeys already exists and get its cases
        var existingCodingKeysMap: [String: String] = [:]
        let hasExistingCodingKeys = members.contains { member in
            if let enumDecl = member.decl.as(EnumDeclSyntax.self),
               enumDecl.name.text == "CodingKeys" {
                // Extract existing CodingKeys cases
                enumDecl.memberBlock.members.forEach { member in
                    if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self),
                       let element = caseDecl.elements.first {
                        let name = element.name.text
                        if let rawValue = element.rawValue?.value.as(StringLiteralExprSyntax.self)?.segments.first?.description {
                            existingCodingKeysMap[rawValue.replacingOccurrences(of: "\"", with: "")] = name
                        } else {
                            existingCodingKeysMap[name] = name
                        }
                    }
                }
                return true
            }
            return false
        }

        var declarations: [DeclSyntax] = []

        // Generate CodingKeys if it doesn't exist
        if !hasExistingCodingKeys {
            let codingKeysDecl = generateCodingKeysEnum(properties: properties)
            declarations.append(DeclSyntax(stringLiteral: codingKeysDecl))
        }

        // Generate init(from:) implementation
        let initDecl = """
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                \(properties.map { property -> String in
                    let baseType = property.type.replacingOccurrences(of: "?", with: "")
                    let codingKey = existingCodingKeysMap[property.name] ?? property.name
                    if property.type.hasSuffix("?") {
                        return "self.\(property.name) = try container.decodeIfPresent(\(baseType).self, forKey: .\(codingKey))"
                    } else {
                        return generateDecodingExpression(property: property.name, type: baseType, codingKey: codingKey)
                    }
                }.joined(separator: "\n"))
            }
            """
        declarations.append(DeclSyntax(stringLiteral: initDecl))

        return declarations
    }

    static func generateCodingKeysEnum(properties: [(name: String, type: String, customKey: String?)]) -> String {
        let cases = properties.map { property in
            if let customKey = property.customKey {
                return "    case \(property.name) = \"\(customKey)\""
            } else {
                return "    case \(property.name)"
            }
        }.joined(separator: "\n")
        
        return """
        private enum CodingKeys: String, CodingKey {
        \(cases)
        }
        """
    }

    static func generateDecodingExpression(property: String, type: String, codingKey: String) -> String {
        let defaultValue: String
        let isOptional = type.hasSuffix("?")
        let baseType = isOptional ? String(type.dropLast()) : type
        
        switch baseType {
        case "String":
            defaultValue = "\"\""
        case "Int":
            defaultValue = "0"
        case "Double":
            defaultValue = "0.0"
        case "Bool":
            defaultValue = "false"
        case let dictType where dictType.hasPrefix("[") && dictType.contains(":") && dictType.hasSuffix("]"):
            defaultValue = "[:]"
        case let arrayType where arrayType.hasPrefix("[") && arrayType.hasSuffix("]"):
            defaultValue = "[]"
        default:
            return "self.\(property) = try container.decode(\(baseType).self, forKey: .\(codingKey))"
        }
        
        return """
            self.\(property) = try container.decodeIfPresent(\(baseType).self, forKey: .\(codingKey)) ?? {
            #if DEBUG
            assertionFailure("Missing key for field: \(property)")
            #endif
            return \(defaultValue)
            }()
            """
    }
}
