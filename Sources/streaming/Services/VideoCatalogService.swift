import Foundation
import Vapor

final class VideoCatalogService: VideoCataloging {
    private let baseURL: URL
    private let fm = FileManager.default

    init(publicDirectory: String) {
        self.baseURL = URL(fileURLWithPath: publicDirectory).appendingPathComponent("videos", isDirectory: true)
    }

    func listAll() -> [VideoInfo] {
        guard fm.fileExists(
            atPath: baseURL.path
        ), let ids = try? fm.contentsOfDirectory(
            atPath: baseURL.path
        ) else { return [] }
        return ids.compactMap { id in
            let p = baseURL.appendingPathComponent(id).appendingPathComponent("master.m3u8").path
            guard fm.fileExists(atPath: p) else { return nil }
            return VideoInfo(
                id: id,
                videoURL: "/videos/\(id)/master.m3u8"
            )
        }
    }
}
