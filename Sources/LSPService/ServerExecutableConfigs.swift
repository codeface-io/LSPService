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
        
        if let configsFromFile = [LanguageKey : CodableConfiguration](fromFilePath: filePath),
           !configsFromFile.isEmpty {
            return configsFromFile.mapValues {
                Executable.Configuration(path: $0.path,
                                         arguments: $0.arguments,
                                         environment: $0.environment)
            }
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
            
            let codableConfigs = hardcodedConfigs.mapValues {
                CodableConfiguration(path: $0.path,
                                    arguments: $0.arguments,
                                    environment: $0.environment)
            }
            
            codableConfigs.save(toFilePath: filePath)
            
            return hardcodedConfigs
        }
    }
    
    typealias LanguageKey = String
}

// FIXME: Add true codability directly to Executable.Configuration in FoundationToolz
public struct CodableConfiguration: Codable {
    
    public init(path: String,
                arguments: [String] = [],
                environment: [String : String] = [:]) {
        self.path = path
        self.arguments = arguments
        self.environment = environment
    }
    
    public var path: String
    public var arguments: [String]
    public var environment: [String: String]
}
