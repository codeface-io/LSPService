import Vapor
import Foundation

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
        "Hello, I'm the Language Service.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))\n\nAnd all supported languages:\n\(listOfSupportedLanguages())"
    }
    
    registerRoutes(onDashboard: languageService.grouped("dashboard"), on: app)
    
    registerRoutes(onAPI: languageService.grouped("api"))
}

// MARK: - Dashboard

func registerRoutes(onDashboard dashboard: RoutesBuilder, on app: Application) {
    dashboard.on(.GET) { req in
        "Hello, I'm the Language Service.\n\nEndpoints (Vapor Routes):\n\(routeList(for: app))\nSupported Languages:\n\(listOfSupportedLanguages())"
    }

    let languageNameParameter = "languageName"

    dashboard.on(.GET, ":\(languageNameParameter)") { req -> String in
        let languageName = req.parameters.get(languageNameParameter)!
        let languageIsSupported = isSupported(language: languageName)
        return "Hello, I'm the Language Service.\n\nThe language \(languageName.capitalized) is \(languageIsSupported ? "already" : "not yet") supported."
    }
}

func routeList(for app: Application) -> String {
    app.routes.all.map { $0.description }.reduce("") { $0 + $1 + "\n" }
}

// MARK: - Websocket API

func registerRoutes(onAPI api: RoutesBuilder) {
    let languageNameParameter = "languageName"
    
    api.webSocket(":\(languageNameParameter)") { request, ws in
        let languageName = request.parameters.get(languageNameParameter)!
        guard isSupported(language: languageName) else {
            ws.send("Error accessing Language Service: \(languageName.capitalized) is currently not supported.")
            return
        }
        
        configureAndRunSwiftLanguageServer()
        
        websocket = ws
        
        ws.onBinary { ws, byteBuffer in
            let data = Data(buffer: byteBuffer)
            let dataString = String(data: data, encoding: .utf8) ?? "error decoding data"
            print("received data from socket \(ObjectIdentifier(ws).hashValue) at endpoint for \(languageName):\n\(dataString)")
            swiftLanguageServer.receive(data)
        }
        
        ws.onClose.whenComplete { result in
            switch result {
            case .success:
                print("websocket did close")
            case .failure(let error):
                print("websocket failed to close: \(error.localizedDescription)")
            }
        }
    }
}

fileprivate func configureAndRunSwiftLanguageServer() {
    swiftLanguageServer.didSendOutput = { output in
        let outputString = String(data: output,
                                  encoding: .utf8) ?? "error decoding output"
        print("received output from Swift language server:\n" + outputString)

        websocket?.send([UInt8](output))
    }

    swiftLanguageServer.run()
}

fileprivate var websocket: WebSocket?

// MARK: - Supported Languages

func listOfSupportedLanguages() -> String {
    lowercasedNamesOfSupportedLanguages.map {
        $0.capitalized
    }
    .reduce("") {
        $0 + $1 + "\n"
    }
}

func isSupported(language: String) -> Bool {
    lowercasedNamesOfSupportedLanguages.contains(language.lowercased())
}

let lowercasedNamesOfSupportedLanguages: Set<String> = ["swift"]

// MARK: - Swift Language Server

let swiftLanguageServer = SwiftLanguageServer()
