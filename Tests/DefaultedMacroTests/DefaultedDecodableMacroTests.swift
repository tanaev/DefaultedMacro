import XCTest
import SwiftSyntaxMacrosTestSupport
import SwiftSyntax
import DefaultedMacroMacros
import DefaultedMacro

final class DefaultedDecodableMacroTests: XCTestCase {

    func testInitFromDecoderExpansion() {
        assertMacroExpansion(
            """
            @DefaultedDecodable
            struct UserDTO: Decodable {
                var name: String
                var isPremium: Bool
                var age: Int
                var balance: Double
                var tags: [String]
                var scores: [String: Int]
                var optionalField: String?
            }
            """,
            expandedSource: """
            struct UserDTO: Decodable {
                var name: String
                var isPremium: Bool
                var age: Int
                var balance: Double
                var tags: [String]
                var scores: [String: Int]
                var optionalField: String?

                private enum CodingKeys: String, CodingKey {
                    case name
                    case isPremium
                    case age
                    case balance
                    case tags
                    case scores
                    case optionalField
                }

                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: name")
                        #endif
                        return ""
                    }()
                    self.isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: isPremium")
                        #endif
                        return false
                    }()
                    self.age = try container.decodeIfPresent(Int.self, forKey: .age) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: age")
                        #endif
                        return 0
                    }()
                    self.balance = try container.decodeIfPresent(Double.self, forKey: .balance) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: balance")
                        #endif
                        return 0.0
                    }()
                    self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: tags")
                        #endif
                        return []
                    }()
                    self.scores = try container.decodeIfPresent([String: Int].self, forKey: .scores) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: scores")
                        #endif
                        return [:]
                    }()
                    self.optionalField = try container.decodeIfPresent(String.self, forKey: .optionalField)
                }
            }
            """,
            macros: ["DefaultedDecodable": DefaultedDecodableMacro.self]
        )
    }

    func testDecodingWithMissingFields() {
        assertMacroExpansion(
            """
            @DefaultedDecodable
            struct User: Decodable {
                var name: String
                var tags: [String]
                var scores: [String: Int]
                var optionalField: String?
            }
            """,
            expandedSource: """
            struct User: Decodable {
                var name: String
                var tags: [String]
                var scores: [String: Int]
                var optionalField: String?

                private enum CodingKeys: String, CodingKey {
                    case name
                    case tags
                    case scores
                    case optionalField
                }

                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: name")
                        #endif
                        return ""
                    }()
                    self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: tags")
                        #endif
                        return []
                    }()
                    self.scores = try container.decodeIfPresent([String: Int].self, forKey: .scores) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: scores")
                        #endif
                        return [:]
                    }()
                    self.optionalField = try container.decodeIfPresent(String.self, forKey: .optionalField)
                }
            }
            """,
            macros: ["DefaultedDecodable": DefaultedDecodableMacro.self]
        )
    }

    func testDecodingWithPresentFields() {
        assertMacroExpansion(
            """
            @DefaultedDecodable
            struct User: Decodable {
                var name: String
                var tags: [String]
                var scores: [String: Int]
                var optionalField: String?
            }
            """,
            expandedSource: """
            struct User: Decodable {
                var name: String
                var tags: [String]
                var scores: [String: Int]
                var optionalField: String?

                private enum CodingKeys: String, CodingKey {
                    case name
                    case tags
                    case scores
                    case optionalField
                }

                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: name")
                        #endif
                        return ""
                    }()
                    self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: tags")
                        #endif
                        return []
                    }()
                    self.scores = try container.decodeIfPresent([String: Int].self, forKey: .scores) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: scores")
                        #endif
                        return [:]
                    }()
                    self.optionalField = try container.decodeIfPresent(String.self, forKey: .optionalField)
                }
            }
            """,
            macros: ["DefaultedDecodable": DefaultedDecodableMacro.self]
        )
    }
}
