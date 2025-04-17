import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
public struct DefaultedMacroPlugin: CompilerPlugin {
    public init() {}
    
    public let providingMacros: [Macro.Type] = [
        DefaultedDecodableMacro.self
    ]
} 