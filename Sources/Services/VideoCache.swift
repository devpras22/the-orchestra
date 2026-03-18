import Foundation

/// Pre-downloads and caches HEVC video files for instant local playback.
/// Uses deterministic filenames (URL's last path component) — no mapping needed.
final class VideoCache: Sendable {
    static let shared = VideoCache()

    let cacheDir: URL

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = base.appendingPathComponent("masko-desktop/videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    /// Total size of cached files in bytes.
    var cacheSize: Int64 {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }

    /// Delete all cached videos.
    func clearCache() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    /// Delete cached files older than the given interval (default 30 days).
    func evictStaleFiles(olderThan interval: TimeInterval = 30 * 24 * 60 * 60) {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-interval)
        guard let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        var evicted = 0
        for file in files {
            if let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               modified < cutoff {
                try? fm.removeItem(at: file)
                evicted += 1
            }
        }
        if evicted > 0 {
            print("[masko-desktop] VideoCache: evicted \(evicted) stale file(s)")
        }
    }

    /// Returns local file URL if cached, otherwise the original remote URL.
    func resolve(_ remoteURL: URL) -> URL {
        let local = cacheDir.appendingPathComponent(remoteURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: local.path) {
            return local
        }
        return remoteURL
    }

    /// Download all HEVC videos from config in parallel. Non-blocking — fire and forget.
    func preload(config: MaskoAnimationConfig) async {
        let urls = Set(config.edges.compactMap { $0.videos.hevc }.compactMap { URL(string: $0) })
        let uncached = urls.filter { !FileManager.default.fileExists(atPath: cacheDir.appendingPathComponent($0.lastPathComponent).path) }

        guard !uncached.isEmpty else {
            print("[masko-desktop] VideoCache: all \(urls.count) videos already cached")
            return
        }

        print("[masko-desktop] VideoCache: downloading \(uncached.count)/\(urls.count) videos...")

        await withTaskGroup(of: Void.self) { group in
            for url in uncached {
                group.addTask { [cacheDir] in
                    do {
                        let (tempFile, _) = try await URLSession.shared.download(from: url)
                        let dest = cacheDir.appendingPathComponent(url.lastPathComponent)
                        try? FileManager.default.removeItem(at: dest)
                        try FileManager.default.moveItem(at: tempFile, to: dest)
                        print("[masko-desktop] VideoCache: cached \(url.lastPathComponent)")
                    } catch {
                        print("[masko-desktop] VideoCache: failed \(url.lastPathComponent) — \(error.localizedDescription)")
                    }
                }
            }
        }

        print("[masko-desktop] VideoCache: preload complete")
    }
}
