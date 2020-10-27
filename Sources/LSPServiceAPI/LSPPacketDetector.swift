import FoundationToolz
import Foundation
import SwiftyToolz

class LSPPacketDetector {
    
    // MARK: - Interface
    
    func read(_ data: Data) {
        queue += data
        
        while !queue.isEmpty, let lspPacket = removeLSPPacketFromQueue() {
            didDetectLSPPacket(lspPacket)
        }
    }
    
    var didDetectLSPPacket: (Data) -> Void = { _ in }

    // MARK: - Data Buffer Queue (Instance State)
    
    private func removeLSPPacketFromQueue() -> Data? {
        guard !queue.isEmpty else { return nil }
        guard let packet = Self.packet(fromBeginningOf: queue) else { return nil }
        queue.removeFirst(packet.count)
        queue.resetIndices()
        return packet
    }
    
    private var queue = Data()
    
    // MARK: - Functional Logic
    
    private static func packet(fromBeginningOf data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        
        guard let header = header(fromBeginningOf: data) else {
            log(error: "Data doesn't start with header:\n\(data.utf8String!)")
            return nil
        }
        
        guard let contentLength = contentLength(fromHeader: header) else {
            log(error: "Header declares no content length")
            return nil
        }
        
        let packetLength = header.count + headerContentSeparator.count + contentLength
        
        guard packetLength <= data.count else { return nil }
        
        return data[0 ..< packetLength]
    }
    
    private static func header(fromBeginningOf data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        
        guard let separatorIndex = indexOfSeparator(in: data) else {
            log(warning: "Data contains no header/content separator:\n\(data.utf8String!)")
            return nil
        }
        
        guard separatorIndex > 0 else {
            log(error: "Empty header")
            return nil
        }
        
        return data[0 ..< separatorIndex]
    }
    
    private static func indexOfSeparator(in data: Data) -> Int? {
        guard !data.isEmpty else { return nil }
        let lastDataIndex = data.count - 1
        let lastPossibleSeparatorIndex = lastDataIndex - (headerContentSeparator.count - 1)
        guard lastPossibleSeparatorIndex >= 0 else { return nil }
        
        for index in 0 ... lastPossibleSeparatorIndex {
            let potentialSeparator = data[index ..< index + headerContentSeparator.count]
            if potentialSeparator == headerContentSeparator { return index }
        }

        return nil
    }
    
    private static func contentLength(fromHeader header: Data) -> Int? {
        let headerString = header.utf8String!
        let headerLines = headerString.components(separatedBy: "\r\n")
        
        for headerLine in headerLines {
            if headerLine.hasPrefix("Content-Length") {
                guard let lengthString = headerLine.components(separatedBy: ": ").last else {
                    return nil
                }
                return Int(lengthString)
            }
        }
        
        return nil
    }
    
    private static let headerContentSeparator = Data([13, 10, 13, 10]) // ascii: "\r\n\r\n"
}

extension Data {
    mutating func resetIndices() {
        self = Data(self)
    }
}
