import Vapor
import SwiftLSP
import Foundation
import SwiftyToolz

struct RouteConfigurator {

    func registerRoutes(on app: Application) throws {
        app.on(.GET) { req in
            "LSPService Endpoints (Vapor Routes):\n\(routeList(for: app))"
        }
        
        registerRoutes(onAPI: app.grouped("lspservice").grouped("api"))
    }

    private func routeList(for app: Application) -> String {
        app.routes.all.map { $0.description }.joined(separator: "\n")
    }

    // MARK: - API

    private func registerRoutes(onAPI api: RoutesBuilder) {
        api.on(.GET, "processID") { _ in
            Int(ProcessInfo.processInfo.processIdentifier)
        }
        
        registerRoutes(onLanguage: api.grouped("language"))
    }

    private func registerRoutes(onLanguage language: RoutesBuilder) {
        let languageNameParameter = "languageName"
        
        language.webSocket(":\(languageNameParameter)", "websocket",
                           maxFrameSize: 1048576) { request in
            let languageName = request.parameters.get(languageNameParameter)!
            
            do {
                try configureAndRunLanguageServer(forLanguage: languageName)
                return request.eventLoop.makeSucceededFuture([:])
            } catch {
                log(error)
                return request.eventLoop.makeSucceededFuture(nil)
            }
        } onUpgrade: { request, newWebsocket in
            newWebsocket.onClose.whenComplete { result in
                switch result {
                case .success:
                    request.logger.info("websocket did close")
                case .failure(let error):
                    request.logger.error("websocket failed to close: \(error.localizedDescription)")
                }
            }
            
            newWebsocket.onBinary { ws, lspPacketBytes in
                let lspPacket = Data(buffer: lspPacketBytes)
                activeServerExecutable?.receive(input: lspPacket)
            }
            
            websocket?.close(promise: nil)
            websocket = newWebsocket
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
