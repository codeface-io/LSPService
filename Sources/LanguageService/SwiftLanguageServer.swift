import Foundation

class SwiftLanguageServer {
    
    // MARK: - Life Cycle
    
    init() {
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
        
        if input.count == 0 {
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
        updateExecutable()
        process.environment = nil
        process.arguments = []
        process.terminationHandler = { process in
            print("\(Self.self) terminated. code: \(process.terminationReason.rawValue)")
        }
    }
    
    func updateExecutable(filePath: String = getSourceKitLSPPath()) {
        guard let executable = actuallyExistingExecutable(for: filePath) else { return }
        process.executableURL = executable // just setting nil crashes
    }
    
    func run() {
        guard process.executableURL != nil else {
            print("Error: \(Self.self) has no valid executable set")
            return
        }
        
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
    
    // MARK: - Executable (sourcekit-lsp)
    
    func actuallyExistingExecutable(for filePath: String) -> URL? {
        if FileManager.default.fileExists(atPath: filePath) {
            return URL(fileURLWithPath: filePath)
        } else {
            print("Error: sourcekit-lsp does not seem to exist here:\n\(filePath)\n\(Self.self) will not be able to run without the executable")
            return nil
        }
    }
    
    private static func getSourceKitLSPPath() -> String {
        var path = defaultExecutablePath
        
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
    }
    
    private static let defaultExecutablePath = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp"
}
