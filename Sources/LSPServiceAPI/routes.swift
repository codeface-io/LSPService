import Vapor
import FoundationToolz
import Foundation
import SwiftyToolz

// MARK: - Register Routes

func registerRoutes(on app: Application) throws {
    app.on(.GET) { req in
        "Hello, I'm the Language Service Host.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))"
    }
    
    registerRoutes(onLSPService: app.grouped("lspservice"), on: app)
}

func registerRoutes(onLSPService lspService: RoutesBuilder,
                    on app: Application) {
    lspService.on(.GET) { _ in
        "👋🏻 Hello, I'm the Language Service.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))\n\nAvailable languages:\n\(languagesJoined(by: "\n"))"
    }

    let languageNameParameter = "languageName"

    lspService.on(.GET, ":\(languageNameParameter)") { req -> String in
        let language = req.parameters.get(languageNameParameter)!
        let executablePath = LanguageServer.Config.all[language.lowercased()]?.executablePath
        return "Hello, I'm the Language Service.\n\nThe language \(language.capitalized) has this associated language server:\n\(executablePath ?? "None")"
    }
    
    registerRoutes(onAPI: lspService.grouped("api"), app: app)
}

func routeList(for app: Application) -> String {
    app.routes.all.map { $0.description }.joined(separator: "\n")
}

// MARK: - API

func registerRoutes(onAPI api: RoutesBuilder, app: Application) {
    api.on(.GET, "languages") { _ in
        Array(LanguageServer.Config.all.keys)
    }
    
    registerRoutes(onLanguage: api.grouped("language"), app: app)
}

func registerRoutes(onLanguage language: RoutesBuilder, app: Application) {
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
            app.logger.debug("received data from socket \(ObjectIdentifier(ws).hashValue) at endpoint for \(languageName):\n\(lspPacketString)")
            languageServer?.receive(lspPacket: lspPacket)
        }
        
        websocket?.close(promise: nil)
        websocket = newWebsocket
        
        configureAndRunLanguageServer(forLanguage: languageName, app: app)
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

func configureAndRunLanguageServer(forLanguage lang: String,
                                   app: Application) {
    languageServer?.stop()
    
    guard let newLanguageServer = createLanguageServer(forLanguage: lang,
                                                       app: app)
    else {
        app.logger.error("Could not create language server")
        return
    }
    
    languageServer = newLanguageServer
    
    languageServer?.didSendOutput = { lspPacket in
        guard lspPacket.count > 0 else { return }
        let outputString = lspPacket.utf8String ?? "error decoding output"
        app.logger.debug("received \(lspPacket.count) bytes output data from \(lang.capitalized) language server:\n\(outputString)")
        websocket?.send([UInt8](lspPacket))
    }
    
    languageServer?.didSendError = { errorData in
        guard errorData.count > 0 else { return }
        var errorString = errorData.utf8String ?? "error decoding error"
        if errorString.last == "\n" { errorString.removeLast() }
        app.logger.debug("received \(errorData.count) bytes error data from \(lang.capitalized) language server:\n\(errorString)")
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

func createLanguageServer(forLanguage lang: String, app: Application) -> LanguageServer? {
    guard let config = LanguageServer.Config.all[lang.lowercased()] else {
        app.logger.error("No LSP server config set for language \(lang.capitalized)")
        return nil
    }
    
    return LanguageServer(config, logger: app.logger)
}

var languageServer: LanguageServer?

// MARK: - Websocket

var websocket: Vapor.WebSocket?
