import Foundation

/// Pure logic of the CLI. No Vapor here.
struct ConsoleInputProcessor {
    static var prompt: String { "💬  " }
    
    static func initialOutput() -> String {
        """
        
        👋🏻  Hello, I'm the LSPService. Configure me via commands. For example:
        ⌨️  languages                      ➡️  get all languages that have a language server path
        ⌨️  language Java                  ➡️  get the path of Java's language server
        ⌨️  language Java /path/to/javaLS  ➡️  set a (new) path for Java's language server
        """
    }

    static func response(forInput input: String) -> String {
        var argumentsToProcess = arguments(fromInput: input)

        guard argumentsToProcess.count > 0 else {
            return "🛑  Couldn't recognize your input as a command"
        }
        
        let command = argumentsToProcess.removeFirst()
        
        var output = ""
        
        switch command {
        case "languages":
            let languages = languagesJoined(by: ", ")
            output += "✅  LSP server paths are set for: \(languages)"
        case "language":
            guard argumentsToProcess.count > 0 else {
                return "🛑  Please specify a language after the command \"language\""
            }
            
            let language = argumentsToProcess.removeFirst()
            
            guard argumentsToProcess.count > 0 else {
                if let config = ServerConfigStore.configs[language.lowercased()] {
                    output += "✅  \(language.capitalized) has this LSP server executable path and arguments:\n   \"\(config.executablePath + " " + config.arguments.joined(separator: " "))\""
                } else {
                    output += "🛑  No LSP server path is set for language \"\(language.capitalized)\""
                }
                break
            }
            
            let newPath = argumentsToProcess.removeFirst()
            
            if URL(fromFilePath: newPath) != nil {
                ServerConfigStore.configs[language.lowercased()] = .init(executablePath: newPath,
                                                                         arguments: [])
                output += "✅  \(language.capitalized) now has a new LSP server path:\n   \"\(newPath)\""
            } else {
                output += "🛑  This is not a valid file path: \"\(newPath)\""
            }
        default:
            return "🛑  That's not an available command"
        }
        
        if argumentsToProcess.count > 0 {
            output += "\n⚠️  I'm gonna ignore these unexpected remaining arguments: \(argumentsToProcess)"
        }
        
        return output
    }

    private static func arguments(fromInput input: String) -> [String] {
        input.components(separatedBy: .whitespaces).filter { $0.count > 0 }
    }
}
