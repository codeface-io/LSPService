import Vapor
import SwiftLSP
import Foundation
import SwiftyToolz

struct RouteConfigurator {

    func registerRoutes(on app: Application) throws {
        app.get { req in
            "LSPService Endpoints (Vapor Routes):\n\(routeList(for: app))"
        }
        
        registerRoutes(onAPI: app.grouped("lspservice").grouped("api"))
    }

    private func routeList(for app: Application) -> String {
        app.routes.all.map { $0.description }.joined(separator: "\n")
    }

    // MARK: - API

    private func registerRoutes(onAPI api: RoutesBuilder) {
        registerWebSocketRoute(onLanguage: api.grouped("language"))
    }

    /**
     FIXME: Vapor calls `onUpgrade` and provides us the WebSocket for configuration AFTER returning a WebSocket connection to the client!
     
     That means the client (Codeface) might (and does!) send data via the WebSocket before Vapor gives us a chance to even configure the damn thing! 🤬
     
     Current workaround in Codeface is merely stochastic: wait 100 ms before sending first data (lsp request)
     
     https://github.com/vapor/vapor/issues/2927
     */
    private func registerWebSocketRoute(onLanguage language: RoutesBuilder) {
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
            newWebsocket.onBinary { ws, bufferedBytesFromWebSocket in
                let dataFromWebSocket = Data(buffer: bufferedBytesFromWebSocket)
                activeServerExecutable?.receive(input: dataFromWebSocket)
            }
            
            newWebsocket.onClose.whenComplete { result in
                switch result {
                case .success:
                    log("WebSocket did close without error")
                case .failure(let error):
                    log(error: "WebSocket failed to close: \(error.localizedDescription)")
                }
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
        
        let newServerExecutable = try LSP.ServerExecutable(config: config) { packetFromServer in
            activeWebSocket?.send([UInt8](packetFromServer.data))
        }
        
        activeServerExecutable?.stop()
        activeServerExecutable = newServerExecutable
        
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
            /**
             FIXME: sometimes the server terminates but this handler is never called, leading to this log:
             
             ℹ️ Running LSP server /Users/seb/Desktop/sourcekit-lsp
             ℹ️ ServerExecutable terminated. code: 2
             ℹ️ WebSocket did close
             */
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
        
        // TODO: check what we can/should improve in how we run the process: https://developer.apple.com/forums/thread/690310
        
        try newServerExecutable.run()
        
        log("Launched LSP server " + config.command + " " + config.arguments.joined(separator: " "))
    }
}

// MARK: - Basic Objects

fileprivate var activeWebSocket: Vapor.WebSocket?
fileprivate var activeServerExecutable: LSP.ServerExecutable?
