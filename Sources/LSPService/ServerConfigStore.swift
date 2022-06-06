import SwiftLSP

struct ServerConfigStore {
    
    static var languages: [String] {
        configs.keys.map { $0.capitalized }
    }
    
    static func config(language: String) -> LSP.ServerExecutable.Configuration? {
        configs[language.lowercased()]
    }
    
    static func set(_ config: LSP.ServerExecutable.Configuration,
                    forLanguage language: String) {
        configs[language.lowercased()] = config
    }
    
    private static var configs: [LanguageKey: LSP.ServerExecutable.Configuration] = [
        "swift": .init(
            executablePath: "/usr/bin/xcrun",
            arguments: ["sourcekit-lsp"],
            environmentVariables: ["SOURCEKIT_LOGGING": "0"]
        ),
//            "python": .init(executablePath: "/Library/Frameworks/Python.framework/Versions/3.9/bin/pyls",
//                            arguments: [])
    ]
    
    typealias LanguageKey = String
}
