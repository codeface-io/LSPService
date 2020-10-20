import Foundation

import Vapor
//import SwiftLSPClient

/// Pure logic of the CLI. No Vapor here.
struct ConsoleInputProcessing {
    static var prompt: String { "💬  " }
    
    static func initialOutput() -> String {
        """
        
        👋🏻  Hello, I'm the Language Service. Configure me via commands. For example:
        ⌨️  languages                      ➡️  get all languages that have a language server path
        ⌨️  language Java                  ➡️  get the path of Java's language server
        ⌨️  language Java /path/to/javaLS  ➡️  set a (new) path for Java's language server
        """
    }

    static func response(forInput input: String, _ app: Application) -> String {
        var argumentsToProcess = arguments(fromInput: input)

        guard argumentsToProcess.count > 0 else {
            return "🛑  Couldn't recognize your input as a command"
        }
        
        let command = argumentsToProcess.removeFirst()
        /*
        if command == "t" {
//            configureAndRunLanguageServer(forLanguage: "swift", app: app)
//            languageServer?.receive(Data())
            
            testWithSwiftLSPClient()
            return "did run test"
        }
        */
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
                if let executablePath = executablePathsByLanguage[language.lowercased()] {
                    output += "✅  \(language.capitalized) has this LSP server path set:\n   \"\(executablePath)\""
                } else {
                    output += "🛑  No LSP server path is set for language \"\(language.capitalized)\""
                }
                break
            }
            
            let newExecutablePath = argumentsToProcess.removeFirst()
            
            if URL(fromFilePath: newExecutablePath) != nil {
                executablePathsByLanguage[language.lowercased()] = newExecutablePath
                output += "✅  \(language.capitalized) now has a new LSP server path:\n   \"\(newExecutablePath)\""
            } else {
                output += "🛑  This is not a valid file path: \"\(newExecutablePath)\""
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


/*
//let host = LanguageServerProcessHost(path: "/Library/Frameworks/Python.framework/Versions/3.9/bin/pyls",
//                                     arguments: [],
//                                     environment: [:])

let host = LanguageServerProcessHost(path: "/Users/seb/Desktop/sourcekit-lsp",
                                     arguments: [],
                                     environment: [:])

func testWithSwiftLSPClient() {
    host.start { (server) in
        guard let server = server else {
            Swift.print("unable to launch server")
            return
        }
        
        // Set-up notificationResponder to see log/error messages from LSP server
//        server.notificationResponder = <object conforming to NotificationResponder>

        let processId = Int(ProcessInfo.processInfo.processIdentifier)
        let capabilities = ClientCapabilities(workspace: nil, textDocument: nil, experimental: nil)

        let params = InitializeParams(processId: processId,
                                      rootPath: "/Users/seb/Desktop/GitHub Repos/SwiftLSPClient",
                                      rootURI: nil,
                                      initializationOptions: nil,
                                      capabilities: capabilities,
                                      trace: Tracing.off,
                                      workspaceFolders: nil)

        server.initialize(params: params, block: { (result) in
            switch result {
            case .failure(let error):
                Swift.print("unable to initialize \(error)")
            case .success(let value):
                Swift.print("initialized \(value)")
                
                server.initialized(params: InitializedParams()) { error in
                    if let error = error {
                        Swift.print("error sending initialized notification: \(error)")
                        return
                    }
                    
                    let docSymbolParams = DocumentSymbolParams(textDocument: TextDocumentIdentifier(path: "/Users/seb/Desktop/GitHub Repos/SwiftLSPClient/SwiftLSPClient/LanguageServer.swift"))
                    
    //                let docSymbolParams = DocumentSymbolParams(textDocument: TextDocumentIdentifier(path: "/Users/seb/Desktop/Sonova Repos/App.Scripts/poeditor/backup_translations.py"))
                    
                    server.documentSymbol(params: docSymbolParams) { result in
                        switch result {
                        case .success(let response):
                            switch response {
                            case .documentSymbols(let symbols):
                                break
                            case .symbolInformation(let infos):
                                break
                            }
                        case .failure(let error):
                            Swift.print("doc symbol error: \(error)")
                        }
                    }    
                }
            }
        })
    }
}
*/
