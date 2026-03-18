import Foundation

/// JSON file persistence for ~/Library/Application Support/masko-desktop/
enum LocalStorage {
    static let appSupportDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("masko-desktop", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func save<T: Encodable>(_ value: T, to filename: String) {
        let url = appSupportDir.appendingPathComponent(filename)
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[masko-desktop] Failed to save \(filename): \(error)")
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        let url = appSupportDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("[masko-desktop] Failed to load \(filename): \(error)")
            return nil
        }
    }
}
