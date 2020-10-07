import Vapor
import Foundation

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // register routes
    try routes(app)
    testSourceKitLSP()
}

func testSourceKitLSP() {
    process.executableURL = URL(fileURLWithPath: "/Users/seb/Desktop/sourcekit-lsp")
    
    let inputPipe = Pipe()
    process.standardInput = inputPipe
    
    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    
    let outputFile = outputPipe.fileHandleForReading
    outputFile.waitForDataInBackgroundAndNotify()
    
    NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable,
                                           object: outputFile,
                                           queue: nil) { _ in
        let outputData = outputFile.availableData
        print(String(data: outputData, encoding: .utf8) ?? "error decoding output")
    }
    
    let errorPipe = Pipe()
    process.standardError = errorPipe
    
    let errorFile = errorPipe.fileHandleForReading
    errorFile.waitForDataInBackgroundAndNotify()
    
    NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable,
                                           object: errorFile,
                                           queue: nil) { _ in
        let errorData = errorFile.availableData
        let errorString = String(data: errorData, encoding: .utf8) ?? "error decoding error"
        print(errorString)
    }
    
    do {
        try process.run()
    } catch {
        print(error.localizedDescription)
    }
    
    if let data = testMessageData() {
        inputPipe.fileHandleForWriting.write(data)
    }
}

let process = Process()

func testMessageData() -> Data? {
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
        return nil
    }
    
    var result = messageHeaderData
    result.append(messageContentData)
    return result
}
