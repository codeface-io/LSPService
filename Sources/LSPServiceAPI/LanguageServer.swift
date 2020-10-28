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
    
    static var active: LanguageServer?
    
    // MARK: - Life Cycle
    
    init(languageKey: String) throws {
        guard let config = Config.all[languageKey.lowercased()] else {
            throw "No LSP server config set for language \(languageKey.capitalized)"
        }
        
        guard FileManager.default.fileExists(atPath: config.executablePath) else {
            throw "Executable does not exist at given path \(config.executablePath)"
        }
        
        didSendLSPPacket = { _ in
            log(warning: "\(Self.self) did send lsp packet, but handler has not been set")
        }
        didSendError = { _ in
            log(warning: "\(Self.self) did send error, but handler has not been set")
        }
        didTerminate = {
            log(warning: "\(Self.self) did terminate, but handler has not been set")
        }
        
        setupProcess(with: config)
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
            try inPipe.fileHandleForWriting.write(contentsOf: lspPacket)
        } catch {
            log(error: "\(error.localizedDescription)")
        }
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
        
        packetDetector.didDetectLSPPacket = { [weak self] packet in
            self?.didSendLSPPacket(packet)
        }
        
        process.standardOutput = outPipe
    }
    
    private let packetDetector = LSPPacketDetector()
    
    var didSendLSPPacket: (Data) -> Void
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
    
    // MARK: -
    
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
}
