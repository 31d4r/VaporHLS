import Foundation
import Vapor

final class FileStorageService: FileStoring {
    private let fm = FileManager.default
    private let publicDir: String
    private let uploadsDir: URL
    private let videosDir: URL

    init(publicDirectory: String) {
        self.publicDir = publicDirectory
        self.uploadsDir = URL(fileURLWithPath: publicDirectory).appendingPathComponent("uploads", isDirectory: true)
        self.videosDir = URL(fileURLWithPath: publicDirectory).appendingPathComponent("videos", isDirectory: true)
    }

    func ensureDirectoryExists() throws {
        try createDirIfNeeded(uploadsDir)
        try createDirIfNeeded(videosDir)
    }

    func saveUpload(
        data: ByteBuffer,
        suggestedExt: String?
    ) throws -> (id: String, inputURL: URL) {
        try ensureDirectoryExists()
        let id = UUID().uuidString.lowercased()
        let ext = (suggestedExt?.isEmpty == false) ? suggestedExt! : "mp4"
        let inputURL = uploadsDir.appendingPathComponent("\(id).\(ext)")
        try Data(buffer: data).write(to: inputURL, options: .atomic)
        return (id, inputURL)
    }

    func hlsOutputPaths(
        for id: String
    ) -> (
        dir: URL,
        m3u8: URL,
        segmentPattern: String
    ) {
        let outDir = videosDir.appendingPathComponent(
            id,
            isDirectory: true
        )
        try? createDirIfNeeded(outDir)
        let m3u8 = outDir.appendingPathComponent("master.m3u8")
        let segPattern = outDir.appendingPathComponent("seg_%05d.m4s").path
        return (outDir, m3u8, segPattern)
    }

    private func createDirIfNeeded(_ url: URL) throws {
        if !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }
    }
}
