import Vapor
import Foundation
import SwiftyToolz

public class LSPServiceApp: LogObserver {
    
    // MARK: - Life Cycle
    
    public init() throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        vaporApp = Application(env)
        Log.shared.minimumLevel = .off
        Log.shared.add(observer: self)
        try setupLSPServiceAPI(on: vaporApp)
    }
    
    deinit { vaporApp.shutdown() }
    
    // MARK: - Logging
    
    public func receive(_ entry: Log.Entry) {
        switch entry.level {
        case .info:
            vaporApp.logger.info("\(entry.description)")
        case .warning:
            vaporApp.logger.warning("\(entry.description)")
        case .error:
            vaporApp.logger.error("\(entry.description)")
        case .off:
            break
        }
    }
    
    // MARK: - Vapor App
    
    public func run() throws {
        try vaporApp.run()
    }
    
    private let vaporApp: Application
}

// MARK: - Configure App

func setupLSPServiceAPI(on app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.http.server.configuration.serverName = "Language Service Host"
    app.logger.logLevel = .debug
    
    try registerRoutes(on: app)
    
    startProcessingConsoleInput(app: app)
}

// MARK: - Console Input

fileprivate func startProcessingConsoleInput(app: Application) {
    app.console.output(ConsoleInputProcessing.initialOutput().consoleText())
    processNextConsoleInput(app: app)
}

fileprivate func processNextConsoleInput(app: Application) {
    app.console.output(ConsoleInputProcessing.prompt.consoleText(),
                       newLine: false)
    
    let eventLoop = app.eventLoopGroup.next()
    
    let didReadConsole = app.threadPool.runIfActive(eventLoop: eventLoop) {
        app.console.input()
    }
    
    didReadConsole.whenSuccess { input in
        app.console.output(ConsoleInputProcessing.response(forInput: input).consoleText())
        processNextConsoleInput(app: app)
    }
    
    didReadConsole.whenFailure { error in
        app.logger.error(.init(stringLiteral: error.localizedDescription))
    }
}

// MARK: - Register Routes

func registerRoutes(on app: Application) throws {
    app.on(.GET) { req in
        "Hello, I'm the Language Service Host.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))"
    }
    
    registerRoutes(onLSPService: app.grouped("lspservice"), on: app)
}

func registerRoutes(onLSPService lspService: RoutesBuilder, on app: Application) {
    lspService.on(.GET) { _ in
        "👋🏻 Hello, I'm the Language Service.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))\n\nAvailable languages:\n\(languagesJoined(by: "\n"))"
    }

    let languageNameParameter = "languageName"

    lspService.on(.GET, ":\(languageNameParameter)") { req -> String in
        let language = req.parameters.get(languageNameParameter)!
        let executablePath = LanguageServer.Config.all[language.lowercased()]?.executablePath
        return "Hello, I'm the Language Service.\n\nThe language \(language.capitalized) has this associated language server:\n\(executablePath ?? "None")"
    }
    
    registerRoutes(onAPI: lspService.grouped("api"))
}

func routeList(for app: Application) -> String {
    app.routes.all.map { $0.description }.joined(separator: "\n")
}

// MARK: - API

func registerRoutes(onAPI api: RoutesBuilder) {
    api.on(.GET, "languages") { _ in
        Array(LanguageServer.Config.all.keys)
    }
    
    api.on(.GET, "processID") { _ in
        Int(ProcessInfo.processInfo.processIdentifier)
    }
    
    registerRoutes(onLanguage: api.grouped("language"))
}

func registerRoutes(onLanguage language: RoutesBuilder) {
    let languageNameParameter = "languageName"
    
    language.webSocket(":\(languageNameParameter)", "websocket") { request, newWebsocket in
        newWebsocket.onClose.whenComplete { result in
            switch result {
            case .success:
                request.logger.info("websocket did close")
            case .failure(let error):
                request.logger.error("websocket failed to close: \(error.localizedDescription)")
            }
        }
        
        let languageName = request.parameters.get(languageNameParameter)!
        guard isAvailable(language: languageName) else {
            let errorFeedbackWasSent = request.eventLoop.makePromise(of: Void.self)
            errorFeedbackWasSent.futureResult.whenComplete { _ in
                newWebsocket.close(promise: nil)
            }
            
            // TODO: explore LSP standard: can these kind of generic issues be communicated via LSP messages/notifications?
            newWebsocket.send("Error: A language server for \(languageName.capitalized) is currently not available.",
                    promise: errorFeedbackWasSent)
            return
        }
        
        newWebsocket.onBinary { ws, lspPacketBytes in
            let lspPacket = Data(buffer: lspPacketBytes)
            let lspPacketString = lspPacket.utf8String!
            log("received data from socket \(ObjectIdentifier(ws).hashValue) at endpoint for \(languageName):\n\(lspPacketString)")
            languageServer?.receive(lspPacket: lspPacket)
        }
        
        websocket?.close(promise: nil)
        websocket = newWebsocket
        
        configureAndRunLanguageServer(forLanguage: languageName)
    }

    language.on(.GET, ":\(languageNameParameter)") { request -> String in
        let language = request.parameters.get(languageNameParameter)!
        guard let executablePath = LanguageServer.Config.all[language.lowercased()]?.executablePath else {
            throw Abort(.noContent,
                        reason: "No LSP server path has been set for \(language.capitalized)")
        }
        return executablePath
    }
    
    language.on(.POST, ":\(languageNameParameter)") { request -> HTTPStatus in
        let executablePath = request.body.string ?? ""
        guard URL(fromFilePath: executablePath) != nil else {
            throw Abort(.badRequest,
                        reason: "Request body contains no valid file path")
        }
        let language = request.parameters.get(languageNameParameter)!
        
        var config = LanguageServer.Config.all[language.lowercased()]
        config?.executablePath = executablePath
        LanguageServer.Config.all[language.lowercased()] = config
        
        return .ok
    }
}

// MARK: - Language Server

func configureAndRunLanguageServer(forLanguage lang: String) {
    languageServer?.stop()
    
    guard let newLanguageServer = createLanguageServer(forLanguage: lang) else {
        log(error: "Could not create language server")
        return
    }
    
    languageServer = newLanguageServer
    
    languageServer?.didSendLSPPacket = { lspPacket in
        guard lspPacket.count > 0 else { return }
        let outputString = lspPacket.utf8String ?? "error decoding output"
        log("received \(lspPacket.count) bytes output data from \(lang.capitalized) language server:\n\(outputString)")
        websocket?.send([UInt8](lspPacket))
    }
    
    languageServer?.didSendError = { errorData in
        guard errorData.count > 0 else { return }
        var errorString = errorData.utf8String ?? "error decoding error"
        if errorString.last == "\n" { errorString.removeLast() }
        log("received \(errorData.count) bytes error data from \(lang.capitalized) language server:\n\(errorString)")
        websocket?.send(errorString)
    }
    
    languageServer?.didTerminate = {
        guard let websocket = websocket, !websocket.isClosed else { return }
        let errorFeedbackWasSent = websocket.eventLoop.makePromise(of: Void.self)
        errorFeedbackWasSent.futureResult.whenComplete { _ in
            websocket.close(promise: nil)
        }
        websocket.send("\(lang.capitalized) language server did terminate",
                       promise: errorFeedbackWasSent)
    }

    languageServer?.run()
}

func createLanguageServer(forLanguage lang: String) -> LanguageServer? {
    guard let config = LanguageServer.Config.all[lang.lowercased()] else {
        log(error: "No LSP server config set for language \(lang.capitalized)")
        return nil
    }
    
    return LanguageServer(config)
}

var languageServer: LanguageServer?

// MARK: - Websocket

var websocket: Vapor.WebSocket?
