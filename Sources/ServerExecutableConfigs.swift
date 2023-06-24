import FoundationToolz
import Foundation
import SwiftyToolz

struct ServerExecutableConfigs {
    
    static func config(language: String) -> Executable.Configuration? {
        configs[language] ?? configs[language.lowercased()]
    }
    
    static func preload() {
        if configs.isEmpty {
            log(warning: "There are no server executables configured.")
        }
    }
    
    private static var configs = loadConfigs()
    
    private static func loadConfigs() -> Configs {
        let filePath = Bundle.main.bundlePath + "/LSPServiceConfig.json"
        
        if let configsFromFile = Configs(fromFilePath: filePath), !configsFromFile.isEmpty {
            log("Found config file with \(configsFromFile.count) server entries: " + filePath)
            return configsFromFile
        }
        
        let hardcodedConfigs: Configs = [
            "swift": .sourceKitLSP,
            
            /**
             the following are experimental example entries
             
             if you wann use or change them, remember to first delete the LSPServiceConfig.json file so it gets regenerated on next launch with these hardcoded defaults
             */
            
//            "python": .init(path: "/opt/homebrew/bin/pylsp",
//                            arguments: ["-v"], // verbose
//                            environment: [:])
             
//            "dart": .init(path: "/Users/seb/Desktop/flutter/bin/dart",
//                          arguments: ["language-server"]),
            
//            "kotlin": .init(path: "/opt/homebrew/bin/kotlin-language-server"),
            // the "SEVERE ..." log might be irrelevant https://github.com/eclipse-lsp4j/lsp4j/issues/658 ... or it might indicate that the KLS is in a "screwed up" state and that's the reason it does not react to the initialize request ...
            
//            "python": .init(path: "/Library/Frameworks/Python.framework/Versions/3.9/bin/pyls")
        ]
        
        if hardcodedConfigs.save(toFilePath: filePath,
                                 options: [.prettyPrinted, .withoutEscapingSlashes]) == nil {
            log(error: "Failed to save server executable configs to \(filePath)")
        }
        
        log("Created config file with \(hardcodedConfigs.count) server entries: " + filePath)
        
        return hardcodedConfigs
    }
    
    typealias Configs = [LanguageKey: Executable.Configuration]
    typealias LanguageKey = String
}
