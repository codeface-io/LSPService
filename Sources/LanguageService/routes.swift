import Vapor
import Foundation

func routes(_ app: Application) throws {
    launchSourceKitLSP()
    setupWebSocket(app)
}

// MARK: - Launch Language Server

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

// MARK: - Client WebSocket

func setupWebSocket(_ app: Application) {
    app.webSocket { request, ws in
        websocket = ws
        
        ws.onBinary { ws, byteBuffer in
            websocketDidSend(byteBuffer: byteBuffer)
        }
    }
}

func websocketDidSend(byteBuffer: ByteBuffer) {
    guard let data = byteBuffer.getData(at: 0,
                                        length: byteBuffer.readableBytes) else {
        print("error: could not get data from received byte buffer")
        return
    }
    
    let dataString = String(data: data,
                            encoding: .utf8) ?? "error decoding data"
    
    print("received data of \(data.count) bytes:\n\(dataString)")
    
    sendDataToLanguageServer(data)
}

fileprivate func sendDataToLanguageServer(_ data: Data) {
    do {
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
    } catch {
        print(error.localizedDescription)
    }
}

fileprivate var websocket: WebSocket?

// MARK: - Language Server Process

fileprivate let process = Process()
fileprivate let inputPipe = Pipe()
fileprivate let outputPipe = Pipe()
fileprivate let errorPipe = Pipe()
