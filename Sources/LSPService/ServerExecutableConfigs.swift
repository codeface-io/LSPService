import FoundationToolz
import Foundation
import SwiftyToolz

struct ServerExecutableConfigs {
    
    static func config(language: String) -> Executable.Configuration? {
        configs[language.lowercased()]
    }
    
    static func preload() {
        if configs.isEmpty {
            log(error: "Loading executable configurations failed")
        }
    }
    
    private static var configs = loadConfigs()
    
    private static func loadConfigs() -> Configs {
        let filePath = "LSPServiceConfig.json"
        
        if let configsFromFile = Configs(fromFilePath: filePath), !configsFromFile.isEmpty {
            return configsFromFile
        }
        
        let hardcodedConfigs: Configs = [
            "swift": .init(path: "/usr/bin/xcrun",
                           arguments: ["sourcekit-lsp"],
                           environment: ["SOURCEKIT_LOGGING": "0"]),
            //            "python": .init(executablePath: "/Library/Frameworks/Python.framework/Versions/3.9/bin/pyls",
            //                            arguments: [])
        ]
        
        if hardcodedConfigs.save(toFilePath: filePath) == nil {
            log(error: "Failed to save server executable configs to \(filePath)")
        }
        
        return hardcodedConfigs
    }
    
    typealias Configs = [LanguageKey: Executable.Configuration]
    typealias LanguageKey = String
}
