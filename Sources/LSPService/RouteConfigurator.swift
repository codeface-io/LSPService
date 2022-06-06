import Vapor
import SwiftLSP
import Foundation
import SwiftyToolz

struct RouteConfigurator {

    func registerRoutes(on app: Application) throws {
        app.on(.GET) { req in
            "Hello, I'm the Language Service Host.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))"
        }
        
        registerRoutes(onLSPService: app.grouped("lspservice"), on: app)
    }

    private func registerRoutes(onLSPService lspService: RoutesBuilder, on app: Application) {
        lspService.on(.GET) { _ in
            "👋🏻 Hello, I'm the Language Service.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))\n\nAvailable languages:\n\(ServerExecutableConfigs.languages.joined(separator: "\n"))"
        }

        let languageNameParameter = "languageName"

        lspService.on(.GET, ":\(languageNameParameter)") { req -> String in
            let language = req.parameters.get(languageNameParameter)!
            let executablePath = ServerExecutableConfigs.config(language: language)?.path
            return "Hello, I'm the Language Service.\n\nThe language \(language.capitalized) has this associated language server:\n\(executablePath ?? "None")"
        }
        
        registerRoutes(onAPI: lspService.grouped("api"))
    }

    private func routeList(for app: Application) -> String {
        app.routes.all.map { $0.description }.joined(separator: "\n")
    }

    // MARK: - API

    private func registerRoutes(onAPI api: RoutesBuilder) {
        api.on(.GET, "languages") { _ in
            ServerExecutableConfigs.languages
        }
        
        api.on(.GET, "processID") { _ in
            Int(ProcessInfo.processInfo.processIdentifier)
        }
        
        registerRoutes(onLanguage: api.grouped("language"))
    }

    private func registerRoutes(onLanguage language: RoutesBuilder) {
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
            
            do
            {
                try configureAndRunLanguageServer(forLanguage: languageName)
            }
            catch
            {
                let errorFeedbackWasSent = request.eventLoop.makePromise(of: Void.self)
                errorFeedbackWasSent.futureResult.whenComplete { _ in
                    newWebsocket.close(promise: nil)
                }
                
                let errorMessage = "\(languageName.capitalized) language server couldn't be initialized: \(error.readable.message)"
                newWebsocket.send(errorMessage, promise: errorFeedbackWasSent)
                
                return
            }
            
            newWebsocket.onBinary { ws, lspPacketBytes in
                let lspPacket = Data(buffer: lspPacketBytes)
                activeServerExecutable?.receive(input: lspPacket)
            }
            
            websocket?.close(promise: nil)
            websocket = newWebsocket
        }

        language.on(.GET, ":\(languageNameParameter)") { request -> String in
            let language = request.parameters.get(languageNameParameter)!
            guard let executablePath = ServerExecutableConfigs.config(language: language)?.path else {
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
            
            if var config = ServerExecutableConfigs.config(language: language)
            {
                config.path = executablePath
                ServerExecutableConfigs.set(config, forLanguage: language)
            }
            else
            {
                ServerExecutableConfigs.set(.init(path: executablePath),
                                      forLanguage: language)
            }
            
            return .ok
        }
    }
    
    // MARK: - Language Server

    private func configureAndRunLanguageServer(forLanguage lang: String) throws {
        guard let config = ServerExecutableConfigs.config(language: lang) else {
            throw "No LSP server config set for language \(lang.capitalized)"
        }
        
        let newServerExecutable = try LSP.ServerExecutable(config: config)
        
        activeServerExecutable?.stop()
        activeServerExecutable = newServerExecutable
        
        newServerExecutable.didSend = { lspPacket in
            websocket?.send([UInt8](lspPacket.data))
        }
        
        newServerExecutable.didSendError = { errorData in
            guard errorData.count > 0 else { return }
            var errorString = errorData.utf8String!
            if errorString.last == "\n" { errorString.removeLast() }
            log(warning: "\(lang.capitalized) language server stdErr:\n\(errorString)")
            websocket?.send(errorString)
        }
        
        newServerExecutable.didTerminate = {
            guard let websocket = websocket, !websocket.isClosed else { return }
            let errorFeedbackWasSent = websocket.eventLoop.makePromise(of: Void.self)
            errorFeedbackWasSent.futureResult.whenComplete { _ in
                websocket.close(promise: nil)
            }
            websocket.send("\(lang.capitalized) language server did terminate",
                           promise: errorFeedbackWasSent)
        }

        newServerExecutable.run()
    }
}

// MARK: - Basic Objects

fileprivate var websocket: Vapor.WebSocket?

fileprivate var activeServerExecutable: LSP.ServerExecutable?
