@attached(member, names: named(init), named(CodingKeys))
public macro DefaultedDecodable() = #externalMacro(
    module: "DefaultedMacroMacros",
    type: "DefaultedDecodableMacro"
)
