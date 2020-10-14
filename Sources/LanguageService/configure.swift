import Vapor
import Foundation

public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.logger.logLevel = .warning
    
    app.http.server.configuration.serverName = "Language Service Host"
    
    try registerRoutes(on: app)
    
    startProcessingConsoleInput(app: app)
}

func startProcessingConsoleInput(app: Application) {
    app.console.output("\n👋🏻  Hello, I'm the Language Service. Configure me with these commands:\n⌨️  <language> [<executable path>]\t\t➡️  get/set path to LSP server for language")
    let languages = languagesJoined(by: ", ")
    app.console.output("🗣  LSP server paths are set for: \(languages)".consoleText())
    processNextConsoleInput(app: app)
}

func processNextConsoleInput(app: Application) {
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
        app.console.output("Error: \(error.localizedDescription)".consoleText())
    }
}

func process(input: String, from console: Console) {
    var argumentsToProcess = arguments(fromInput: input)

    guard argumentsToProcess.count > 0 else {
        console.output("🛑  Couldn't recognize your input as a command".consoleText())
        return
    }
    
    let language = argumentsToProcess.removeFirst()
    
    guard argumentsToProcess.count > 0 else {
        guard let executablePath = executablePathsByLanguage[language.lowercased()] else {
            console.output("🛑  No LSP server path set for language \"\(language.capitalized)\"".consoleText())
            return
        }
        
        console.output("✅  \(language.capitalized) has this LSP server path set:\n   \"\(executablePath)\"".consoleText())
        return
    }
    
    let newExecutablePath = argumentsToProcess.removeFirst()
    
    executablePathsByLanguage[language.lowercased()] = newExecutablePath
    
    console.output("✅  \(language.capitalized) now has a new LSP server path:\n   \"\(newExecutablePath)\"".consoleText())
    
    if argumentsToProcess.count > 0 {
        console.output("⚠️  I'm gonna ignore unexpected remaining arguments: \(argumentsToProcess)".consoleText())
    }
}

func arguments(fromInput input: String) -> [String] {
    input.components(separatedBy: .whitespaces).filter { $0.count > 0 }
}
