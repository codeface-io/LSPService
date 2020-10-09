import Foundation

class SwiftLanguageServer {
    
    // MARK: - Life Cycle
    
    init(executable: URL) {
        self.executable = executable
        didSendOutput = { _ in
            print("\(Self.self) did send output, but output handler has not been set")
        }
        didSendError = { _ in
            print("\(Self.self) did send error, but error handler has not been set")
        }
        
        setupProcess()
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
            print("error: \(Self.self) cannot receive input while it's not running.")
            return
        }
        
        if input.count > 0 {
            print("warning: \(Self.self) received empty input data.")
        }
        
        do {
            try inPipe.fileHandleForWriting.write(contentsOf: input)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private let inPipe = Pipe()
    
    // MARK: - Output
    
    private func setupOutput() {
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] outHandle in
            self?.didSendOutput(outHandle.availableData)
        }
        process.standardOutput = outPipe
    }
    
    var didSendOutput: (Data) -> Void
    private let outPipe = Pipe()
    
    // MARK: - Error Output
    
    private func setupErrorOutput() {
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] errorHandle in
            self?.didSendError(errorHandle.availableData)
        }
        process.standardError = errorPipe
    }
    
    var didSendError: (Data) -> Void
    private let errorPipe = Pipe()
    
    // MARK: - Process
    
    private func setupProcess() {
        process.executableURL = executable
        process.environment = nil
        process.arguments = []
        process.terminationHandler = { process in
            print("\(Self.self) terminated. code: \(process.terminationReason.rawValue)")
        }
    }
    
    func run() {
        guard !isRunning else {
            print("warning: \(Self.self) is already running.")
            return
        }
        
        do {
            try process.run()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func stop() {
        process.terminate()
    }
    
    var isRunning: Bool { process.isRunning }
    
    private let process = Process()
    private let executable: URL
}
