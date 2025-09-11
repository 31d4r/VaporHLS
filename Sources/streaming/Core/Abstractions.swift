import Foundation
import Vapor

public struct VideoInfo: Content {
    public let id: String
    public let videoURL: String
}

public protocol ProcessRunning {
    @discardableResult
    func run(_ exe: String, _ arguments: [String]) throws -> Int32
    func runAndCapture(_ exe: String, _ arguments: [String]) throws -> String
}

public protocol OSDetecting {
    var isMacOS: Bool { get }
    var isLinux: Bool { get }
    var brewPathCandidates: [String] { get }
}

public protocol FileStoring {
    func ensureDirectoryExists() throws
    func saveUpload(data: ByteBuffer, suggestedExt: String?) throws -> (id: String, inputURL: URL)
    func hlsOutputPaths(for id: String) -> (dir: URL, m3u8: URL, segmentPattern: String)
}

public protocol VideoCataloging {
    func listAll() -> [VideoInfo]
}

public protocol ToolProvisioning {
    func ensureFFmpeg() throws
}

public protocol HLSConverting {
    func convertToHLS(input: URL, outDir: URL, m3u8: URL, segmentPattern: String) throws
}
