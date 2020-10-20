import Vapor
import FoundationToolz
import Foundation
import SwiftyToolz

class LanguageServer {
    
    // MARK: - Life Cycle
    
    init?(_ executable: Executable, logger: Logger) {
        guard FileManager.default.fileExists(atPath: executable.path) else {
            logger.error("Failed to create \(Self.self). Executable does not exist at given path \(executable.path)")
            return nil
        }
        
        log = logger
        
        didSendOutput = { _ in
            print("\(Self.self) did send output, but output handler has not been set")
        }
        didSendError = { _ in
            print("\(Self.self) did send error, but error handler has not been set")
        }
        didTerminate = {
            print("\(Self.self) did terminate, but termination handler has not been set")
        }
        
        setupProcess(executable)
        setupInput()
        setupOutput()
        setupErrorOutput()
    }
    
    deinit {
        if isRunning { stop() }
    }
    
    // MARK: - Input
    
    private func setupInput() {
        process.standardInput = inPipe
    }
    
    func receive(_ input: Data) {
        guard isRunning else {
            log.error("\(Self.self) cannot receive input while it's not running.")
            return
        }
        
        if input.count == 0 {
            log.warning("\(Self.self) received empty input data.")
        }
        
        do {
            let inputWithProcessID = try addProcessIDToInitializeRequest(input)
            try inPipe.fileHandleForWriting.write(contentsOf: inputWithProcessID)
        } catch {
            log.error("\(error.localizedDescription)")
        }
    }
    
    private func addProcessIDToInitializeRequest(_ input: Data) throws -> Data {
        let messageData = try LSP.extractContent(fromFrame: input)
        var messageJSON = try JSONObject(messageData)
        guard (try? messageJSON.str("method")) == "initialize" else { return input }
        var params = try messageJSON.obj("params")
        params["processId"] = ProcessInfo.processInfo.processIdentifier
        messageJSON["params"] = params
        return LSP.makeFrame(withContent: try messageJSON.data())
    }
    
    private let inPipe = Pipe()
    
    // MARK: - Output
    
    private func setupOutput() {
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] outHandle in
            let outputData = outHandle.availableData
            if outputData.count > 0 { self?.didSendOutput(outputData) }
        }
        process.standardOutput = outPipe
    }
    
    var didSendOutput: (Data) -> Void
    private let outPipe = Pipe()
    
    // MARK: - Error Output
    
    private func setupErrorOutput() {
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] errorHandle in
            let errorData = errorHandle.availableData
            if errorData.count > 0 { self?.didSendError(errorData) }
        }
        process.standardError = errorPipe
    }
    
    var didSendError: (Data) -> Void
    private let errorPipe = Pipe()
    
    // MARK: - Process
    
    private func setupProcess(_ executable: Executable) {
        process.executableURL = URL(fileURLWithPath: executable.path)
        process.environment = nil
        process.arguments = []
        process.terminationHandler = { [weak self] process in
            self?.log.info("\(Self.self) terminated. code: \(process.terminationReason.rawValue)")
            self?.didTerminate()
        }
    }
    
    var didTerminate: () -> Void
    
    func run() {
        guard process.executableURL != nil else {
            log.error("\(Self.self) has no valid executable set")
            return
        }
        
        guard !isRunning else {
            log.warning("\(Self.self) is already running.")
            return
        }
        
        do {
            try process.run()
        } catch {
            print(error.localizedDescription)
        }
        
        if !process.isRunning {
            log.error("process is not running after successful call to run()")
        }
    }
    
    func stop() {
        process.terminate()
    }
    
    var isRunning: Bool { process.isRunning }
    
    private let process = Process()
    
    struct Executable {
        let path: String
    }
    
    private let log: Logger
}

// MARK: - Supported Languages

func languagesJoined(by separator: String) -> String {
    executablePathsByLanguage.keys.map { $0.capitalized }.joined(separator: separator)
}

func isAvailable(language: String) -> Bool {
    executablePathsByLanguage[language.lowercased()] != nil
}

var executablePathsByLanguage = retrieveExecutablePathsForLanguages()

func retrieveExecutablePathsForLanguages() -> [String : String] {
    var paths = [String : String]()
    
    paths["swift"] = {
        //return  "/Users/seb/Library/Developer/Xcode/DerivedData/sourcekit-lsp_Fork-asttkeaysojqnhakomxyeenamaml/Build/Products/Debug/sourcekit-lsp"
        
        var path = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp"
        
        do {
            let output = try runExecutable(at: "/usr/bin/xcrun",
                                           arguments: ["--find", "sourcekit-lsp"])
            if let firstLine = output.components(separatedBy: "\n").first {
                path = firstLine
            } else {
                print("Error: failed to get path from output of '/usr/bin/xcrun --find sourcekit-lsp'\nWill assume this path for sourcekit-lsp:\n\(path)")
            }
        } catch {
            print("Error: failed to run '/usr/bin/xcrun --find sourcekit-lsp': \(error.localizedDescription)\nWill assume this path for sourcekit-lsp:\n\(path)")
        }
        
        return path
    }()
    
    paths["python"] = "/Library/Frameworks/Python.framework/Versions/3.9/bin/pyls"
    
    return paths
}
