import Foundation

struct SavedMascot: Identifiable, Codable {
    let id: UUID
    let name: String
    var config: MaskoAnimationConfig
    let addedAt: Date
    var templateSlug: String?
}

// MARK: - Preset Info

struct PresetInfo: Identifiable {
    let slug: String
    let filename: String // bundle resource name (no .json)

    var id: String { slug }
}

@Observable
final class MascotStore {
    private(set) var mascots: [SavedMascot] = []
    private static let filename = "mascots.json"

    private static let seedVersion = 7 // Bump to re-apply default config on next launch

    /// The base mascot presets. Replace placeholder entries with real configs when ready.
    static let presets: [PresetInfo] = [
        PresetInfo(slug: "madame-patate", filename: "madame-patate"),
        PresetInfo(slug: "otto", filename: "otto"),
        PresetInfo(slug: "cupidon", filename: "cupidon"),
        PresetInfo(slug: "masko", filename: "masko"),
        PresetInfo(slug: "rusty", filename: "rusty"),
        PresetInfo(slug: "nugget", filename: "nugget"),
        PresetInfo(slug: "clippy", filename: "clippy"),
    ]

    /// Presets not yet added by the user.
    var availablePresets: [PresetInfo] {
        let addedSlugs = Set(mascots.compactMap(\.templateSlug))
        return Self.presets.filter { !addedSlugs.contains($0.slug) }
    }

    init() {
        mascots = LocalStorage.load([SavedMascot].self, from: Self.filename) ?? []
        if mascots.isEmpty {
            seedDefaults()
        } else {
            migrateSeedIfNeeded()
        }
    }

    private func seedDefaults() {
        // Seed all presets for new users
        Task {
            for preset in Self.presets {
                if let config = await Self.fetchRemoteConfig(slug: preset.slug) {
                    await MainActor.run {
                        self.addFromPreset(config: config, slug: preset.slug)
                    }
                } else {
                    await MainActor.run {
                        guard let config = Self.loadBundledConfig(named: preset.filename) else { return }
                        self.addFromPreset(config: config, slug: preset.slug)
                    }
                }
            }
            await MainActor.run {
                UserDefaults.standard.set(Self.seedVersion, forKey: "defaultMascotSeedVersion")
            }
        }
    }

    static func fetchRemoteConfig(slug: String) async -> MaskoAnimationConfig? {
        guard let url = URL(string: "\(Constants.maskoBaseURL)/api/mascot-templates/\(slug)") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(MaskoAnimationConfig.self, from: data)
    }

    /// Re-apply bundled configs when the seed version is bumped (e.g. condition fixes).
    /// Also adds any missing presets for existing users.
    private func migrateSeedIfNeeded() {
        let current = UserDefaults.standard.integer(forKey: "defaultMascotSeedVersion")
        guard current < Self.seedVersion else { return }

        let addedSlugs = Set(mascots.compactMap(\.templateSlug))

        for preset in Self.presets {
            guard let config = Self.loadBundledConfig(named: preset.filename) else { continue }
            if let idx = mascots.firstIndex(where: { $0.templateSlug == preset.slug }) {
                // Update existing preset with fresh config
                mascots[idx].config = config
            } else if !addedSlugs.contains(preset.slug) {
                // Add missing preset
                addFromPreset(config: config, slug: preset.slug)
            }
        }
        persist()

        UserDefaults.standard.set(Self.seedVersion, forKey: "defaultMascotSeedVersion")
    }

    static func loadBundledConfig(named filename: String) -> MaskoAnimationConfig? {
        // Try main bundle first
        if let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Defaults"),
           let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(MaskoAnimationConfig.self, from: data) {
            return config
        }
        return nil
    }

    private func persist() {
        LocalStorage.save(mascots, to: Self.filename)
    }

    // MARK: - Preset Management

    /// Add a preset mascot by slug. Tries remote fetch first, falls back to bundled JSON.
    func addPreset(slug: String) async {
        // Already have this preset?
        guard !mascots.contains(where: { $0.templateSlug == slug }) else { return }

        // Try remote first
        if let config = await Self.fetchRemoteConfig(slug: slug) {
            await MainActor.run {
                addFromPreset(config: config, slug: slug)
            }
            return
        }

        // Fall back to bundled
        let filename = Self.presets.first(where: { $0.slug == slug })?.filename ?? slug
        await MainActor.run {
            guard let config = Self.loadBundledConfig(named: filename) else { return }
            addFromPreset(config: config, slug: slug)
        }
    }

    private func addFromPreset(config: MaskoAnimationConfig, slug: String) {
        let mascot = SavedMascot(
            id: UUID(),
            name: config.name,
            config: config,
            addedAt: Date(),
            templateSlug: slug
        )
        mascots.insert(mascot, at: 0)
        persist()
    }

    // MARK: - Community

    /// Add a mascot installed from the community marketplace.
    func addFromCommunity(config: MaskoAnimationConfig, slug: String) {
        guard !mascots.contains(where: { $0.templateSlug == slug }) else { return }
        let mascot = SavedMascot(
            id: UUID(),
            name: config.name,
            config: config,
            addedAt: Date(),
            templateSlug: slug
        )
        mascots.insert(mascot, at: 0)
        persist()
    }

    // MARK: - General Management

    func add(config: MaskoAnimationConfig) {
        let mascot = SavedMascot(
            id: UUID(),
            name: config.name,
            config: config,
            addedAt: Date(),
            templateSlug: nil
        )
        mascots.insert(mascot, at: 0)
        persist()
    }

    func remove(id: UUID) {
        mascots.removeAll { $0.id == id }
        persist()
    }

    func updateConfig(mascotId: UUID, config: MaskoAnimationConfig) {
        guard let idx = mascots.firstIndex(where: { $0.id == mascotId }) else { return }
        mascots[idx].config = config
        persist()
    }

    func updateEdgeConditions(mascotId: UUID, edgeId: String, conditions: [MaskoAnimationCondition]?) {
        guard let idx = mascots.firstIndex(where: { $0.id == mascotId }) else { return }
        guard let edgeIdx = mascots[idx].config.edges.firstIndex(where: { $0.id == edgeId }) else { return }
        mascots[idx].config.edges[edgeIdx].conditions = conditions
        persist()
    }
}
