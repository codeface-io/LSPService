import Vapor
import FoundationToolz
import Foundation
import SwiftyToolz

// MARK: - Register Routes

func registerRoutes(on app: Application) throws {
    app.on(.GET) { req in
        "Hello, I'm the Language Service Host.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))"
    }
    
    registerRoutes(onLanguageService: app.grouped("languageservice"), on: app)
}

func registerRoutes(onLanguageService languageService: RoutesBuilder,
                    on app: Application) {
    languageService.on(.GET) { req in
        "Hello, I'm the Language Service.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))\n\nAnd all supported languages:\n\(languagesAsString())"
    }
    
    registerRoutes(onDashboard: languageService.grouped("dashboard"), on: app)
    
    registerRoutes(onAPI: languageService.grouped("api"), app: app)
}

// MARK: - Dashboard

func registerRoutes(onDashboard dashboard: RoutesBuilder, on app: Application) {
    dashboard.on(.GET) { req in
        "Hello, I'm the Language Service.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))\nSupported Languages:\n\(languagesAsString())"
    }

    let languageNameParameter = "languageName"

    dashboard.on(.GET, ":\(languageNameParameter)") { req -> String in
        let languageName = req.parameters.get(languageNameParameter)!
        let languageIsSupported = isAvailable(language: languageName)
        return "Hello, I'm the Language Service.\n\nThe language \(languageName.capitalized) is \(languageIsSupported ? "already" : "not yet") supported."
    }
}

func routeList(for app: Application) -> String {
    app.routes.all.map { $0.description }.reduce("") { $0 + $1 + "\n" }
}

// MARK: - API

func registerRoutes(onAPI api: RoutesBuilder, app: Application) {
    let languageNameParameter = "languageName"
    
    api.webSocket(":\(languageNameParameter)") { request, newWebsocket in
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
        
        newWebsocket.onBinary { ws, byteBuffer in
            let data = Data(buffer: byteBuffer)
            let dataString = data.utf8String ?? "error decoding data"
            print("received data from socket \(ObjectIdentifier(ws).hashValue) at endpoint for \(languageName):\n\(dataString)")
            languageServer?.receive(data)
        }
        
        websocket?.close(promise: nil)
        websocket = newWebsocket
        
        configureAndRunLanguageServer(forLanguage: languageName, app: app)
    }

    api.on(.GET, "languages") { _ in
        Array(languagesLowercased)
    }
}

// MARK: - Language Server

fileprivate func configureAndRunLanguageServer(forLanguage lang: String,
                                               app: Application) {
    languageServer?.stop()
    
    guard let newLanguageServer = createLanguageServer(forLanguage: lang,
                                                       app: app)
    else {
        app.logger.error("Could not create language server")
        return
    }
    
    languageServer = newLanguageServer
    
    languageServer?.didSendOutput = { outputData in
        guard outputData.count > 0 else { return }
        let outputString = outputData.utf8String ?? "error decoding output"
        print("received \(outputData.count) bytes output data from \(lang.capitalized) language server:\n" + outputString)
        websocket?.send([UInt8](outputData))
    }
    
    languageServer?.didSendError = { errorData in
        guard errorData.count > 0 else { return }
        let errorString = errorData.utf8String ?? "error decoding error"
        print("received \(errorData.count) bytes error data from \(lang.capitalized) language server:\n" + errorString)
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
    switch lang.lowercased() {
    case "swift": return LanguageServer(.swift, logger: app.logger)
    case "python": return LanguageServer(.python, logger: app.logger)
    default: return nil
    }
}

var languageServer: LanguageServer?

// MARK: - Supported Languages

func languagesAsString() -> String {
    languagesLowercased.map { $0.capitalized }.reduce("") { $0 + $1 + "\n" }
}

func isAvailable(language: String) -> Bool {
    languagesLowercased.contains(language.lowercased())
}

let languagesLowercased: Set<String> = ["swift", "python"]//, "java", "c++"]

// MARK: - Websocket

fileprivate var websocket: WebSocket?
