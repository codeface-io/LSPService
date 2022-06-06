import Foundation
import SwiftLSP
import SwiftyToolz

class LanguageServer {
    
    // MARK: - Life Cycle
    
    init(config: Config) throws {
        guard FileManager.default.fileExists(atPath: config.executablePath) else {
            throw "Executable does not exist at given path \(config.executablePath)"
        }
        
        didSend = { _ in
            log(warning: "\(Self.self) did send lsp packet, but handler has not been set")
        }
        
        didSendError = { _ in
            log(warning: "\(Self.self) did send error, but handler has not been set")
        }
        
        didTerminate = {
            log(warning: "\(Self.self) did terminate, but handler has not been set")
        }
        
        try setupProcess(with: config)
        setupInput()
        setupOutput()
        setupErrorOutput()
    }
    
    deinit { if isRunning { stop() } }
    
    // MARK: - LSP Packet Input
    
    private func setupInput() {
        process.standardInput = inPipe
    }
    
    func receive(lspPacket: Data) {
        guard isRunning else {
            log(error: "\(Self.self) cannot receive LSP Packet while not running.")
            return
        }
        
        if lspPacket.isEmpty {
            log(warning: "\(Self.self) received empty LSP Packet.")
        }
        
        do {
            if #available(OSX 10.15.4, *) {
                try inPipe.fileHandleForWriting.write(contentsOf: lspPacket)
            } else {
                inPipe.fileHandleForWriting.write(lspPacket)
            }
        } catch { log(error) }
    }
    
    private let inPipe = Pipe()
    
    // MARK: - LSP Packet Output
    
    private func setupOutput() {
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] outHandle in
            let serverOutput = outHandle.availableData
            if serverOutput.count > 0 {
                self?.packetDetector.read(serverOutput)
            }
        }
        
        packetDetector.didDetect = { [weak self] packet in
            self?.didSend(packet)
        }
        
        process.standardOutput = outPipe
    }
    
    private let packetDetector = LSP.PacketDetector()
    
    var didSend: (LSP.Packet) -> Void
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
    
    private func setupProcess(with config: Config) throws {
        process.executableURL = URL(fileURLWithPath: config.executablePath)
        
        let currentEnvironment = ProcessInfo.processInfo.environment
        let configEnvironment = config.environmentVariables ?? [:]
        let languageServerEnvironment = currentEnvironment.merging(configEnvironment) { $1 }
        process.environment = languageServerEnvironment
        
        process.arguments = config.arguments
        
        process.terminationHandler = { [weak self] process in
            log("\(Self.self) terminated. code: \(process.terminationReason.rawValue)")
            self?.didTerminate()
        }
    }
    
    var didTerminate: () -> Void
    
    func run() {
        guard process.executableURL != nil else {
            log(error: "\(Self.self) has no valid executable set")
            return
        }
        
        guard !isRunning else {
            log(warning: "\(Self.self) is already running.")
            return
        }
        
        do {
            try process.run()
        } catch {
            log(error)
        }
    }
    
    func stop() {
        process.terminate()
    }
    
    var isRunning: Bool { process.isRunning }
    
    private let process = Process()
    
    // MARK: - Configuration
    
    struct Config {
        var executablePath: String
        var arguments: [String]
        var environmentVariables: [String: String]?
    }
}
