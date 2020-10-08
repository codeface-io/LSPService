import Vapor
import Foundation

func routes(_ app: Application) throws {
    app.get { getRequest -> String in
        return "Hello, I'm a Language Service. An LSP implementation is running, but I'm not doing anything yet 🙄"
    }

    app.post { postRequest -> String in
        return "Post request body: \(postRequest.body.string ?? "nil")"
    }
    
    testTalkingToSourceKitLSP()
}

fileprivate func testTalkingToSourceKitLSP() {
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
        let errorData = fileHandle.availableData
        print(String(data: errorData, encoding: .utf8) ?? "error decoding output")
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
    
    // send message
    sendMessageToSourceKitLSP()
}

fileprivate func sendMessageToSourceKitLSP() {
    let messageData = createTestMessageData()
    
    do {
        try inputPipe.fileHandleForWriting.write(contentsOf: messageData)
    } catch {
        print(error.localizedDescription)
    }
}

fileprivate func createTestMessageData() -> Data {
    let request = """
    {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params":
        {
            "capabilities": {},
            "trace": "off"
        }
    }
    """
    
    let messageContentData = request.data(using: .utf8)!
    let messageHeader = "Content-Length: \(messageContentData.count)\r\n\r\n"
    let messageHeaderData = messageHeader.data(using: .utf8)!
    return messageHeaderData + messageContentData
}

fileprivate let inputPipe = Pipe()
fileprivate let outputPipe = Pipe()
fileprivate let errorPipe = Pipe()
fileprivate let process = Process()
