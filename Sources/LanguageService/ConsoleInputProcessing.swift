import Foundation

/// Pure logic of the CLI. No Vapor here.
struct ConsoleInputProcessing {
    static var inputPrefix: String { "💬  " }
    
    static func initialOutput() -> String {
        """
        
        👋🏻  Hello, I'm the Language Service. Configure me with these commands:
        ⌨️  <language> [<executable path>]\t\t➡️  get/set path to LSP server for language
        🗣  LSP server paths are set for: \(languagesJoined(by: ", "))
        """
    }

    static func response(forInput input: String) -> String {
        var argumentsToProcess = arguments(fromInput: input)

        guard argumentsToProcess.count > 0 else {
            return "🛑  Couldn't recognize your input as a command"
        }
        
        let command = argumentsToProcess.removeFirst()
        
        switch command {
        case "languages":
            let languages = languagesJoined(by: ", ")
            return "✅  LSP server paths are set for: \(languages)"
        case "language":
            guard argumentsToProcess.count > 0 else {
                return "🛑  Please specify a language after the command \"language\""
            }
            
            let language = argumentsToProcess.removeFirst()
            
            guard argumentsToProcess.count > 0 else {
                if let executablePath = executablePathsByLanguage[language.lowercased()] {
                    return "✅  \(language.capitalized) has this LSP server path set:\n   \"\(executablePath)\""
                } else {
                    return "🛑  No LSP server path is set for language \"\(language.capitalized)\""
                }
            }
            
            let newExecutablePath = argumentsToProcess.removeFirst()
            
            var output = ""
            
            if URL(fromFilePath: newExecutablePath) != nil {
                executablePathsByLanguage[language.lowercased()] = newExecutablePath
                output += "✅  \(language.capitalized) now has a new LSP server path:\n   \"\(newExecutablePath)\""
            } else {
                output += "🛑  This is not a valid file path: \"\(newExecutablePath)\""
            }
            
            if argumentsToProcess.count > 0 {
                output += "\n⚠️  I'm gonna ignore these unexpected remaining arguments: \(argumentsToProcess)"
            }
            
            return output
        default:
            return "🛑  That's not an available command"
        }
    }

    private static func arguments(fromInput input: String) -> [String] {
        input.components(separatedBy: .whitespaces).filter { $0.count > 0 }
    }
}
