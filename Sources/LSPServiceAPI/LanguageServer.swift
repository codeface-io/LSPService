import Vapor
import FoundationToolz
import Foundation
import SwiftyToolz


func languagesJoined(by separator: String) -> String {
    LanguageServer.Config.all.keys.map {
        $0.capitalized
    }.joined(separator: separator)
}

func isAvailable(language: String) -> Bool {
    LanguageServer.Config.all[language.lowercased()] != nil
}

class LanguageServer {
    
    // MARK: - Life Cycle
    
    init?(_ config: Config, logger: Logger) {
        guard FileManager.default.fileExists(atPath: config.executablePath) else {
            logger.error("Failed to create \(Self.self). Executable does not exist at given path \(config.executablePath)")
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
        
        setupProcess(with: config)
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
    
    func receive(lspPacket: Data) {
        guard isRunning else {
            log.error("\(Self.self) cannot receive LSP Packet while not running.")
            return
        }
        
        if lspPacket.count == 0 {
            log.warning("\(Self.self) received empty LSP Packet.")
        }
        
        do {
            let lspPacketWithProcessID = try addProcessIDIfNecessary(toLSPPacket: lspPacket)
            try inPipe.fileHandleForWriting.write(contentsOf: lspPacketWithProcessID)
        } catch {
            log.error("\(error.localizedDescription)")
        }
    }
    
    private func addProcessIDIfNecessary(toLSPPacket lspPacket: Data) throws -> Data {
        let messageData = try LSP.getMessageData(fromPacket: lspPacket)
        var messageJSON = try JSONObject(messageData)
        guard (try? messageJSON.str("method")) == "initialize" else { return lspPacket }
        var params = try messageJSON.obj("params")
        params["processId"] = ProcessInfo.processInfo.processIdentifier
        messageJSON["params"] = params
        return LSP.makePacket(withMessageData: try messageJSON.data())
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
    
    private func setupProcess(with config: Config) {
        process.executableURL = URL(fileURLWithPath: config.executablePath)
        process.environment = nil
        process.arguments = config.arguments
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
    
    struct Config {
        var executablePath: String
        var arguments: [String]
        
        static var all: [LanguageKey: Config] = [
            "swift": .init(executablePath: "/usr/bin/xcrun",
                           arguments: ["sourcekit-lsp"]),
            "python": .init(executablePath: "/Library/Frameworks/Python.framework/Versions/3.9/bin/pyls",
                            arguments: [])
        ]
        
        typealias LanguageKey = String
    }
    
    private let log: Logger
}
