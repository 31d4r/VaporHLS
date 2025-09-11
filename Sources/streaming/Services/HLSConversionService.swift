import Foundation
import Vapor

final class HLSConversionService: HLSConverting {
    private let runner: any ProcessRunning
    private let logger: Logger

    private struct Rendition {
        let name: String
        let height: Int
        let vKbps: Int
        let aKbps: Int
    }

    private let ladder: [Rendition] = [
        .init(name: "v_240p", height: 240, vKbps: 400, aKbps: 96),
        .init(name: "v_360p", height: 360, vKbps: 800, aKbps: 96),
        .init(name: "v_480p", height: 480, vKbps: 1200, aKbps: 128),
        .init(name: "v_720p", height: 720, vKbps: 2800, aKbps: 128),
        .init(name: "v_1080p", height: 1080, vKbps: 5000, aKbps: 160),
    ]

    init(runner: any ProcessRunning, logger: Logger) {
        self.runner = runner
        self.logger = logger
    }

    func convertToHLS(
        input: URL,
        outDir: URL,
        m3u8: URL,
        segmentPattern: String
    ) throws {
        _ = segmentPattern

        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        var variantsForMaster: [(path: String, bandwidthBps: Int, resolution: String)] = []

        for r in ladder {
            let variantDir = outDir.appendingPathComponent(r.name, isDirectory: true)
            try FileManager.default.createDirectory(at: variantDir, withIntermediateDirectories: true)

            let playlistPath = variantDir.appendingPathComponent("playlist.m3u8").path
            let segPattern = variantDir.appendingPathComponent("seg_%05d.m4s").path

            let width = evenWidth(forHeight: r.height)

            let args = makeArgs(
                input: input.path,
                targetHeight: r.height,
                vKbps: r.vKbps,
                aKbps: r.aKbps,
                segmentDuration: 6,
                playlistPath: playlistPath,
                segmentPattern: segPattern
            )

            try runner.run("/usr/bin/env", ["ffmpeg"] + args)
            logger.info("variant \(r.name) finished → \(playlistPath)")

            let bandwidth = (r.vKbps + r.aKbps) * 1000
            variantsForMaster.append((path: "\(r.name)/playlist.m3u8",
                                      bandwidthBps: bandwidth,
                                      resolution: "\(width)x\(r.height)"))
        }

        try writeMaster(at: m3u8, variants: variantsForMaster)
        logger.info("hey video converted (ABR m4s) → \(m3u8.path)")
    }

    private func makeArgs(
        input: String,
        targetHeight: Int,
        vKbps: Int,
        aKbps: Int,
        segmentDuration: Int,
        playlistPath: String,
        segmentPattern: String
    ) -> [String] {
        let maxrate = Int(Double(vKbps) * 1.07)
        let bufsize = vKbps * 2

        return [
            "-y",
            "-i", input,

            "-vf", "scale=-2:\(targetHeight)",
            "-c:v", "h264",
            "-profile:v", "main",
            "-preset", "veryfast",
            "-b:v", "\(vKbps)k",
            "-maxrate", "\(maxrate)k",
            "-bufsize", "\(bufsize)k",
            "-sc_threshold", "0",
            "-force_key_frames", "expr:gte(t,n_forced*\(segmentDuration))",

            "-c:a", "aac",
            "-b:a", "\(aKbps)k",
            "-ar", "48000",

            "-f", "hls",
            "-hls_time", "\(segmentDuration)",
            "-hls_playlist_type", "vod",
            "-hls_flags", "independent_segments",
            "-hls_segment_type", "fmp4",
            "-hls_fmp4_init_filename", "init.mp4",
            "-hls_segment_filename", segmentPattern,

            playlistPath,
        ]
    }

    private func evenWidth(forHeight h: Int) -> Int {
        let w = Int(round(Double(h) * 16.0 / 9.0))
        return (w % 2 == 0) ? w : w + 1
    }

    private func writeMaster(
        at url: URL,
        variants: [(
            path: String,
            bandwidthBps: Int,
            resolution: String
        )]
    ) throws {
        var lines = [
            "#EXTM3U",
            "#EXT-X-VERSION:7",
        ]
        for v in variants {
            lines.append(#"@STREAM@ BANDWIDTH=\#(v.bandwidthBps),AVERAGE-BANDWIDTH=\#(v.bandwidthBps),RESOLUTION=\#(v.resolution),CODECS="avc1.4d401f,mp4a.40.2""#.replacingOccurrences(of: "@STREAM@", with: "#EXT-X-STREAM-INF:"))
            lines.append(v.path)
        }
        try lines.joined(separator: "\n").appending("\n").write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
    }
}
