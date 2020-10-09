import Foundation

func runExecutable(at filePath: String, arguments: [String]) throws -> String {
    let input = Pipe()
    let output = Pipe()
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: filePath)
    process.standardInput = input
    process.standardOutput = output
    process.environment = nil
    process.arguments = arguments
    
    var outputData = Data()
    
    output.fileHandleForReading.readabilityHandler = { output in
        outputData += output.availableData
    }
    
    try process.run()
    process.waitUntilExit()
    
    return String(data: outputData, encoding: .utf8)!
}
