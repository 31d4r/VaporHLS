import Foundation

struct OSDetector: OSDetecting {
    var isMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    var isLinux: Bool {
        #if os(Linux)
        return true
        #else
        return false
        #endif
    }

    let brewPathCandidates = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew"
    ]
}
