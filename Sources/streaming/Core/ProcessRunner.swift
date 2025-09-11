import Foundation
import Logging
import Vapor

final class ProcessRunner: ProcessRunning {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    @discardableResult
    func run(
        _ exe: String,
        _ arguments: [String]
    ) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = arguments
        
        let out = Pipe()
        let err = Pipe()
        
        p.standardOutput = out
        p.standardError = err
        
        try p.run()
        
        p.waitUntilExit()
        
        logger.info("\(out)")
        logger.warning("\(err)")
        
        guard p.terminationStatus == 0 else {
            throw Abort(
                .internalServerError,
                reason: "Command failed: \(exe) \(arguments.joined(separator: " ")) (exit \(p.terminationStatus))"
            )
        }
        return p.terminationStatus
    }
    
    func runAndCapture(
        _ exe: String,
        _ arguments: [String]
    ) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = arguments
        
        let pipe = Pipe()
        
        p.standardOutput = pipe
        p.standardError = pipe
        
        try p.run()
        
        p.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        guard p.terminationStatus == 0 else {
            throw Abort(
                .internalServerError,
                reason: "Command failed: \(exe) \(arguments.joined(separator: " "))"
            )
        }
        return String(
            data: data,
            encoding: .utf8
        ) ?? ""
    }
}
