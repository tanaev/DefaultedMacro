import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import DefaultedMacro
@testable import DefaultedMacroMacros

let testMacros: [String: Macro.Type] = [
    "DefaultedDecodable": DefaultedDecodableMacro.self
]

final class DefaultedMacroTests: XCTestCase {
    func testDefaultedDecodable() throws {
        assertMacroExpansion(
            """
            @DefaultedDecodable
            struct User: Decodable {
                let name: String
                let age: Int
                let isActive: Bool
                let scores: [Int]
                let metadata: [String: String]
            }
            """,
            expandedSource: """
            struct User: Decodable {
                let name: String
                let age: Int
                let isActive: Bool
                let scores: [Int]
                let metadata: [String: String]
            
                private enum CodingKeys: String, CodingKey {
                    case name
                    case age
                    case isActive
                    case scores
                    case metadata
                }
            
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: name")
                        #endif
                        return ""
                    }()
                    self.age = try container.decodeIfPresent(Int.self, forKey: .age) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: age")
                        #endif
                        return 0
                    }()
                    self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: isActive")
                        #endif
                        return false
                    }()
                    self.scores = try container.decodeIfPresent([Int].self, forKey: .scores) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: scores")
                        #endif
                        return []
                    }()
                    self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: metadata")
                        #endif
                        return [:]
                    }()
                }
            }
            """,
            macros: testMacros
        )
    }

    func testNestedTypes() throws {
        assertMacroExpansion(
            """
            @DefaultedDecodable
            struct Address: Decodable {
                let street: String
                let city: String
            }
            @DefaultedDecodable
            struct User: Decodable {
                let name: String
                let address: Address
            }
            """,
            expandedSource: """
            struct Address: Decodable {
                let street: String
                let city: String
            
                private enum CodingKeys: String, CodingKey {
                    case street
                    case city
                }
            
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.street = try container.decodeIfPresent(String.self, forKey: .street) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: street")
                        #endif
                        return ""
                    }()
                    self.city = try container.decodeIfPresent(String.self, forKey: .city) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: city")
                        #endif
                        return ""
                    }()
                }
            }
            struct User: Decodable {
                let name: String
                let address: Address
            
                private enum CodingKeys: String, CodingKey {
                    case name
                    case address
                }
            
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: name")
                        #endif
                        return ""
                    }()
                    self.address = try container.decode(Address.self, forKey: .address)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testExistingCodingKeys() throws {
        assertMacroExpansion(
            """
            @DefaultedDecodable
            struct User: Decodable {
                enum CodingKeys: String, CodingKey {
                    case name
                    case userAge = "age"
                }
                
                let name: String
                let age: Int
            }
            """,
            expandedSource: """
            struct User: Decodable {
                enum CodingKeys: String, CodingKey {
                    case name
                    case userAge = "age"
                }
                
                let name: String
                let age: Int
            
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: name")
                        #endif
                        return ""
                    }()
                    self.age = try container.decodeIfPresent(Int.self, forKey: .userAge) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: age")
                        #endif
                        return 0
                    }()
                }
            }
            """,
            macros: testMacros
        )
    }

    func testUnsupportedType() throws {
        assertMacroExpansion(
            """
            @DefaultedDecodable
            struct User: Decodable {
                let name: String
                let customType: CustomType
            }
            """,
            expandedSource: """
            struct User: Decodable {
                let name: String
                let customType: CustomType
            
                private enum CodingKeys: String, CodingKey {
                    case name
                    case customType
                }
            
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? {
                        #if DEBUG
                        assertionFailure("Missing key for field: name")
                        #endif
                        return ""
                    }()
                    self.customType = try container.decode(CustomType.self, forKey: .customType)
                }
            }
            """,
            macros: testMacros
        )
    }
} 