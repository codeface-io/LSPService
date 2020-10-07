import Vapor
import Foundation

func routes(_ app: Application) throws {
    app.get { getRequest -> String in
        print(process.isRunning)
        sendMessageToSourceKitLSP()
        return "Hello, I'm a Language Service. You sent me a get request."
    }

    app.post { postRequest -> String in
        return "Post request body: \(postRequest.body.string ?? "nil")"
    }
    
    startSourceKitLSP()
}

fileprivate func startSourceKitLSP() {
    // setup generally
    process.executableURL = URL(fileURLWithPath: "/Users/seb/Desktop/sourcekit-lsp")
    process.standardInput = inputPipe
    process.terminationHandler = { p in
        print("Terminated for reason \(p.terminationReason.rawValue)")
    }
    
    // read output
    process.standardOutput = outputPipe
    let outputFile = outputPipe.fileHandleForReading
    outputFile.waitForDataInBackgroundAndNotify()
    NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable,
                                           object: outputFile,
                                           queue: nil) { _ in
        let outputData = outputFile.availableData
        print(String(data: outputData, encoding: .utf8) ?? "error decoding output")
    }

    // read errors
    process.standardError = errorPipe
    let errorFile = errorPipe.fileHandleForReading
    errorFile.waitForDataInBackgroundAndNotify()
    NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable,
                                           object: errorFile,
                                           queue: nil) { _ in
        let errorData = errorFile.availableData
        print(String(data: errorData, encoding: .utf8) ?? "error decoding error")
    }
    
    // launch
    do {
        try process.run()
    } catch {
        print(error.localizedDescription)
    }
}

fileprivate func sendMessageToSourceKitLSP() {
    do {
        try inputPipe.fileHandleForWriting.write(contentsOf: testMessageData())
    } catch {
        print(error.localizedDescription)
    }
}

fileprivate func testMessageData() -> Data {
    let messageHeader = #"Content-Type: "application/vscode-jsonrpc; charset=utf-8"\r\n\r\n"#
    let messageContent = """
    {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
        }
    }
    """
    guard let messageHeaderData = messageHeader.data(using: .ascii),
        let messageContentData = messageContent.data(using: .utf8) else {
        print("Error encoding message")
        return Data()
    }
    
    var result = messageHeaderData
    result.append(messageContentData)
    return result
}

fileprivate let inputPipe = Pipe()
fileprivate let outputPipe = Pipe()
fileprivate let errorPipe = Pipe()
fileprivate let process = Process()
