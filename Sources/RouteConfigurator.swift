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
                return .init()
            } catch {
                SwiftyToolz.log(error.readable)
                throw error
            }
        } onUpgrade: { request, newWebsocket in
            newWebsocket.onClose.whenComplete { result in
                switch result {
                case .success:
                    log("WebSocket did close")
                case .failure(let error):
                    log(error: "WebSocket failed to close: \(error.localizedDescription)")
                }
            }

            newWebsocket.onBinary { ws, bufferedBytesFromWebSocket in
                let dataFromWebSocket = Data(buffer: bufferedBytesFromWebSocket)
                activeServerExecutable?.receive(input: dataFromWebSocket)
            }

            activeWebSocket?.close(promise: nil)
            activeWebSocket = newWebsocket
        }
    }
    
    // MARK: - Language Server

    private func configureAndRunLanguageServer(forLanguage lang: String) throws {
        guard let config = ServerExecutableConfigs.config(language: lang) else {
            throw "No LSP server config found for language \(lang.capitalized)"
        }
        
        let newServerExecutable = try LSP.ServerExecutable(config: config)
        
        activeServerExecutable?.stop()
        activeServerExecutable = newServerExecutable
        
        newServerExecutable.didSend = { packetFromServer in
            activeWebSocket?.send([UInt8](packetFromServer.data))
        }
        
        newServerExecutable.didSendError = { stdErrData in
            guard stdErrData.count > 0, var stdErrString = stdErrData.utf8String else {
                log(error: "\(lang.capitalized) language server sent empty or undecodable data via stdErr")
                return
            }
            
            if stdErrString.last == "\n" { stdErrString.removeLast() }
            
            log("\(lang.capitalized) language server sent message via stdErr:\n\(stdErrString)")
            
            activeWebSocket?.send(stdErrString)
        }
        
        newServerExecutable.didTerminate = {
            log(warning: "\(lang.capitalized) language server did terminate")
            
            guard let ws = activeWebSocket, !ws.isClosed else { return }
            
            let errorFeedbackWasSent = ws.eventLoop.makePromise(of: Void.self)
            
            errorFeedbackWasSent.futureResult.whenComplete { _ in
                ws.close(promise: nil)
                activeWebSocket = nil
            }
            
            ws.send("\(lang.capitalized) language server did terminate. LSPService will close the websocket.",
                    promise: errorFeedbackWasSent)
        }

        newServerExecutable.run()
    }
}

// MARK: - Basic Objects

fileprivate var activeWebSocket: Vapor.WebSocket?
fileprivate var activeServerExecutable: LSP.ServerExecutable?
