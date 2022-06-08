import FoundationToolz
import Foundation
import SwiftyToolz

struct ServerExecutableConfigs {
    
    static var languages: [String] {
        configs.keys.map { $0.capitalized }
    }
    
    static func config(language: String) -> Executable.Configuration? {
        configs[language.lowercased()]
    }
    
    static func set(_ config: Executable.Configuration,
                    forLanguage language: String) {
        configs[language.lowercased()] = config
    }
    
    static func preload() {
        if configs.isEmpty {
            log(error: "Loading executable configurations failed")
        }
    }
    
    private static var configs = loadConfigs()
    
    private static func loadConfigs() -> [LanguageKey: Executable.Configuration] {
        let filePath = "LSPServiceConfig.json"
        
        if let configsFromFile = [LanguageKey : Executable.Configuration](fromFilePath: filePath),
           !configsFromFile.isEmpty {
            return configsFromFile
        } else {
            let hardcodedConfigs: [LanguageKey: Executable.Configuration] = [
                "swift": .init(
                    path: "/usr/bin/xcrun",
                    arguments: ["sourcekit-lsp"],
                    environment: ["SOURCEKIT_LOGGING": "0"]
                ),
                //            "python": .init(executablePath: "/Library/Frameworks/Python.framework/Versions/3.9/bin/pyls",
                //                            arguments: [])
            ]
            
            hardcodedConfigs.save(toFilePath: filePath)
            
            return hardcodedConfigs
        }
    }
    
    typealias LanguageKey = String
}
