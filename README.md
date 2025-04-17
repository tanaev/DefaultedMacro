# DefaultedMacro

A Swift macro that automatically generates default values for missing fields in Decodable structs.

## Overview

DefaultedMacro is a Swift macro that helps you handle missing fields in JSON decoding by automatically providing default values. It's particularly useful when working with APIs that might omit certain fields, saving you from writing boilerplate code for handling optional values.

## Features

- Automatically generates `Decodable` conformance
- Provides sensible default values for common types:
  - `String`: empty string (`""`)
  - `Bool`: `false`
  - `Int`: `0`
  - `Double`: `0.0`
  - Arrays: empty array (`[]`)
  - Dictionaries: empty dictionary (`[:]`)
- Debug assertions for missing fields
- Customizable error handling for unsupported types
- Automatic handling of optional properties

## Requirements

- iOS 13.0+
- macOS 13.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/DefaultedMacro.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["DefaultedMacro"]
    )
]
```

## Usage

Add the `@DefaultedDecodable` attribute to any struct that conforms to `Decodable`:

```swift
import DefaultedMacro

@DefaultedDecodable
struct User: Decodable {
    let name: String
    let age: Int
    let isActive: Bool
    let scores: [Int]
    let metadata: [String: String]
}
```

The macro will automatically generate:
1. A `CodingKeys` enum for all properties
2. An `init(from:)` method that handles missing fields with default values:
   - `String` → `""`
   - `Int` → `0`
   - `Bool` → `false`
   - `[T]` → `[]`
   - `[K: V]` → `[:]`
   - Optional types (`T?`) remain optional and decode as `nil` if missing

### Example

```swift
// JSON with missing fields
let json = """
{
    "name": "John"
}
"""

// Will decode successfully with default values
let user = try JSONDecoder().decode(User.self, from: json.data(using: .utf8)!)
print(user) // User(name: "John", age: 0, isActive: false, scores: [], metadata: [:])
```

### Debug Mode

In debug mode, the macro will trigger an assertion failure when a field is missing, helping you catch missing fields during development:

```swift
#if DEBUG
assertionFailure("Missing key for field: age")
#endif
```

## How It Works

The macro automatically generates an `init(from:)` implementation that:
1. Attempts to decode each field using `decodeIfPresent`
2. If the field is missing, provides a default value based on the type:
   - `String` → `""`
   - `Bool` → `false`
   - `Int` → `0`
   - `Double` → `0.0`
   - `[T]` → `[]`
   - `[K: V]` → `[:]`
3. In debug builds, logs an assertion failure for missing fields
4. For unsupported types, throws a fatal error
5. Optional properties are handled by Swift's standard `Codable` implementation

## Debugging

In debug builds, the macro will log assertion failures when fields are missing:
```swift
// If "name" is missing in the JSON:
assertionFailure("Missing key for field: name")
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 