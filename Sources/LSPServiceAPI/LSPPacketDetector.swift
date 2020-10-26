import FoundationToolz
import Foundation
import SwiftyToolz

class LSPPacketDetector {
    
    // MARK: - Interface
    
    func write(_ data: Data) {
        queue += data
        
        while let lspPacket = removeLSPPacketFromQueue() {
            didDetectLSPPacket(lspPacket)
        }
    }
    
    var didDetectLSPPacket: (Data) -> Void = { _ in }

    // MARK: - Data Buffer Queue (Instance State)
    
    private func removeLSPPacketFromQueue() -> Data? {
        guard let packet = Self.getPacket(fromBeginningOf: queue) else { return nil }
        queue.removeFirst(packet.count)
        return packet
    }
    
    private var queue = Data()
    
    // MARK: - Functional Logic
    
    private static func getPacket(fromBeginningOf data: Data) -> Data? {
        guard let header = getHeader(fromBeginningOf: data) else {
            log(error: "Data doesn't start with header")
            return nil
        }
        
        guard let contentLength = getContentLength(fromHeader: header) else {
            log(error: "Header declares no content length")
            return nil
        }
        
        let packetLength = header.count + contentLength
        
        guard packetLength <= data.count else { return nil }
        
        return data[0 ..< packetLength]
    }
    
    private static func getHeader(fromBeginningOf data: Data) -> Data? {
        guard let indexOfFirstContentByte = indexOfPacketContent(in: data) else {
            log(warning: "Data contains no header/content separator")
            return nil
        }
        
        let indexOfLastHeaderByte = indexOfFirstContentByte - 5
        
        guard indexOfLastHeaderByte >= 0 else {
            log(error: "Empty header")
            return nil
        }
        
        return data[0 ... indexOfLastHeaderByte]
    }
    
    private static func getContentLength(fromHeader header: Data) -> Int? {
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
    
    private static func indexOfPacketContent(in data: Data) -> Int? {
        let separatorLength = 4
        
        guard data.count > separatorLength else { return nil }
        
        let lastIndex = data.count - 1
        let lastSearchIndex = lastIndex - separatorLength
        
        for index in 0 ... lastSearchIndex {
            if data[index] == 13,
               data[index + 1] == 10,
               data[index + 2] == 13,
               data[index + 3] == 10 {
                return index + separatorLength
            }
        }
        
        return nil
    }
}
