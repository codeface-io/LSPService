import Vapor
import Foundation

struct ConsoleInputProcessing {
    static func start(app: Application) {
        app.console.output("\n👋🏻  Hello, I'm the Language Service. Configure me with these commands:\n⌨️  <language> [<executable path>]\t\t➡️  get/set path to LSP server for language")
        let languages = languagesJoined(by: ", ")
        app.console.output("🗣  LSP server paths are set for: \(languages)".consoleText())
        processNextConsoleInput(app: app)
    }

    private static func processNextConsoleInput(app: Application) {
        print("💬  ", terminator: "")
        
        let eventLoop = app.eventLoopGroup.next()
        
        let didReadConsole = app.threadPool.runIfActive(eventLoop: eventLoop) {
            app.console.input()
        }
        
        didReadConsole.whenSuccess { input in
            process(input: input, from: app.console)
            processNextConsoleInput(app: app)
        }
        
        didReadConsole.whenFailure { error in
            app.console.output("🛑  Reading your input failed: \(error.localizedDescription)".consoleText())
        }
    }

    private static func process(input: String, from console: Console) {
        var argumentsToProcess = arguments(fromInput: input)

        guard argumentsToProcess.count > 0 else {
            console.output("🛑  Couldn't recognize your input as a command".consoleText())
            return
        }
        
        let language = argumentsToProcess.removeFirst()
        
        guard argumentsToProcess.count > 0 else {
            guard let executablePath = executablePathsByLanguage[language.lowercased()] else {
                console.output("🛑  No LSP server path is set for language \"\(language.capitalized)\"".consoleText())
                return
            }
            
            console.output("✅  \(language.capitalized) has this LSP server path set:\n   \"\(executablePath)\"".consoleText())
            return
        }
        
        let newExecutablePath = argumentsToProcess.removeFirst()
        
        executablePathsByLanguage[language.lowercased()] = newExecutablePath
        
        console.output("✅  \(language.capitalized) now has a new LSP server path:\n   \"\(newExecutablePath)\"".consoleText())
        
        if argumentsToProcess.count > 0 {
            console.output("⚠️  I'm gonna ignore these unexpected remaining arguments: \(argumentsToProcess)".consoleText())
        }
    }

    private static func arguments(fromInput input: String) -> [String] {
        input.components(separatedBy: .whitespaces).filter { $0.count > 0 }
    }
}
