import Foundation
import Vapor

final class FFmpegProvisioner: ToolProvisioning {
    private let runner: any ProcessRunning
    private let os: any OSDetecting
    private let logger: Logger

    init(
        runner: any ProcessRunning,
        os: any OSDetecting,
        logger: Logger
    ) {
        self.runner = runner
        self.os = os
        self.logger = logger
    }

    private let ffmpegCandidates = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg",
        "/usr/local/opt/ffmpeg/bin/ffmpeg"
    ]

    func ensureFFmpeg() throws {
        if let found = locateFFmpeg() {
            ensurePathContains(filePath: found)
            logger.info("ffmpeg found at: \(found)")
            return
        }

        if os.isMacOS {
            try ensureBrew()
            try runner.run(
                "/bin/bash",
                [
                    "-lc",
                    "brew install ffmpeg"
                ]
            )
            logger.info("hey ffmpeg installed via brew")
        } else if os.isLinux {
            if (
                try? runner.run(
                    "/usr/bin/env",
                    [
                        "bash",
                        "-lc",
                        "command -v apt >/dev/null 2>&1"
                    ]
                )
            ) != nil {
                try runner.run(
                    "/usr/bin/sudo",
                    [
                        "apt",
                        "update"
                    ]
                )
                try runner.run(
                    "/usr/bin/sudo",
                    [
                        "apt",
                        "install",
                        "-y",
                        "ffmpeg"
                    ]
                )
            } else if (
                try? runner.run(
                    "/usr/bin/env",
                    [
                        "bash",
                        "-lc",
                        "command -v yum >/dev/null 2>&1"
                    ]
                )
            ) != nil {
                try runner.run(
                    "/usr/bin/sudo",
                    [
                        "yum",
                        "install",
                        "-y",
                        "epel-release"
                    ]
                )
                try runner.run(
                    "/usr/bin/sudo",
                    [
                        "yum",
                        "install",
                        "-y",
                        "ffmpeg"
                    ]
                )
            } else {
                throw Abort(.internalServerError, reason: "Supported package manager not found (apt/yum).")
            }
            logger.info("hey ffmpeg installed")
        } else {
            throw Abort(.internalServerError, reason: "Unknown platform for ffmpeg installation.")
        }

        guard let foundAfter = locateFFmpeg() else {
            throw Abort(.internalServerError, reason: "ffmpeg is not available even after installation.")
        }
        ensurePathContains(filePath: foundAfter)
    }

    private func locateFFmpeg() -> String? {
        if let out = try? runner.runAndCapture(
            "/usr/bin/env",
            [
                "bash",
                "-lc",
                "command -v ffmpeg || true"
            ]
        ) {
            let p = out.trimmingCharacters(in: .whitespacesAndNewlines)
            if !p.isEmpty, FileManager.default.fileExists(atPath: p) { return p }
        }

        for c in ffmpegCandidates where FileManager.default.fileExists(atPath: c) {
            return c
        }

        return nil
    }

    private func ensurePathContains(filePath: String) {
        let dir = (filePath as NSString).deletingLastPathComponent
        let old = ProcessInfo.processInfo.environment["PATH"] ?? ""
        setenv("PATH", "\(old):\(dir)", 1)
        let parts = Set(old.split(separator: ":").map(String.init))
        if !parts.contains(dir) {
            setenv("PATH", "\(old):\(dir)", 1)
        }
    }

    private func ensureBrew() throws {
        if let out = try? runner.runAndCapture(
            "/usr/bin/env",
            [
                "bash",
                "-lc",
                "command -v brew || true"
            ]
        ),
            !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            logger.info("brew already exists")
            return
        }

        try runner.run(
            "/bin/bash",
            [
                "-lc",
                "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash"
            ]
        )
        logger.info("hey brew installed")

        for path in os.brewPathCandidates where FileManager.default.fileExists(atPath: path) {
            ensurePathContains(filePath: path)
        }
    }
}
