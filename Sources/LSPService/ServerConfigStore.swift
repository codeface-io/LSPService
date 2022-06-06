func languagesJoined(by separator: String) -> String {
    ServerConfigStore.configs.keys.map {
        $0.capitalized
    }.joined(separator: separator)
}

func isAvailable(language: String) -> Bool {
    ServerConfigStore.configs[language.lowercased()] != nil
}

struct ServerConfigStore {
    static var configs: [LanguageKey: LanguageServer.Config] = [
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
