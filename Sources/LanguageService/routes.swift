import Vapor
import Foundation

// MARK: - Setup

func registerRoutes(on app: Application) throws {
    launchSourceKitLSP()
    
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

// MARK: - Launch SourceKitLSP (Language Server)

fileprivate func launchSourceKitLSP() {
    // setup generally
    process.executableURL = URL(fileURLWithPath: "/Users/seb/Desktop/sourcekit-lsp")
    process.arguments = []
    process.environment = nil
    process.standardInput = inputPipe
    process.terminationHandler = { p in
        print("Terminated with reason \(p.terminationReason.rawValue)")
    }
    
    // read output
    process.standardOutput = outputPipe
    let outputFileHandle = outputPipe.fileHandleForReading
    outputFileHandle.readabilityHandler = { fileHandle in
        let outputData = fileHandle.availableData
        let outputString = String(data: outputData,
                                  encoding: .utf8) ?? "error decoding output"
        print(outputString)
        websocket?.send(outputString)
    }

    // read errors
    process.standardError = errorPipe
    let errorFileHandle = errorPipe.fileHandleForReading
    errorFileHandle.readabilityHandler = { fileHandle in
        let errorData = fileHandle.availableData
        print(String(data: errorData, encoding: .utf8) ?? "error decoding error")
    }
    
    // launch
    do {
        try process.run()
    } catch {
        print(error.localizedDescription)
    }
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

// MARK: - API

func registerRoutes(onAPI api: RoutesBuilder) {
    let languageNameParameter = "languageName"
    
    api.webSocket(":\(languageNameParameter)") { request, ws in
        let languageName = request.parameters.get(languageNameParameter)!
        websocket = ws
        ws.onBinary { ws, byteBuffer in
            websocketDidSend(byteBuffer: byteBuffer,
                             forLanguage: languageName)
        }
    }
}

func websocketDidSend(byteBuffer: ByteBuffer, forLanguage language: String) {
    guard let data = byteBuffer.getData(at: 0,
                                        length: byteBuffer.readableBytes) else {
        print("error: could not get data from received byte buffer")
        return
    }
    
    let dataString = String(data: data,
                            encoding: .utf8) ?? "error decoding data"
    
    print("received data of \(data.count) bytes for \(language):\n\(dataString)")
    
    sendDataToLanguageServer(data)
}

fileprivate var websocket: WebSocket?

// MARK: - Language Server

fileprivate func sendDataToLanguageServer(_ data: Data) {
    do {
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
    } catch {
        print(error.localizedDescription)
    }
}

fileprivate let process = Process()
fileprivate let inputPipe = Pipe()
fileprivate let outputPipe = Pipe()
fileprivate let errorPipe = Pipe()

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
