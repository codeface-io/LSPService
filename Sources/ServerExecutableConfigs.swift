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
        
//        if isDebugBuild {
//            return [ "swift": .init(path: "/Users/seb/Desktop/sourcekit-lsp") ]
//        }
        
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
        
        if hardcodedConfigs.save(toFilePath: filePath,
                                 options: [.prettyPrinted, .withoutEscapingSlashes]) == nil {
            log(error: "Failed to save server executable configs to \(filePath)")
        }
        
        return hardcodedConfigs
    }
    
//    private static var isDebugBuild: Bool {
//        #if DEBUG
//        true
//        #else
//        false
//        #endif
//    }
    
    typealias Configs = [LanguageKey: Executable.Configuration]
    typealias LanguageKey = String
}
