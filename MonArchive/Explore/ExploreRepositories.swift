import Foundation

/// Fei's Firebase adapters implement these two contracts. The views stay unchanged.
/// Use the authenticated user's UID to scope wishlist storage; see the handoff.
@MainActor
protocol ExploreCatalogProviding {
    func fetchPicks() async throws -> [ShopPick]
}

@MainActor
protocol ExploreWishlistProviding {
    func fetchSavedPicks() async throws -> [SavedPick]
    /// Must be idempotent by pick.id and preserve savedAt for an existing save.
    func setSaved(_ pick: ShopPick, saved: Bool) async throws
}

struct BundledExploreCatalog: ExploreCatalogProviding {
    func fetchPicks() async throws -> [ShopPick] { ShopPicks.featured }
}

enum ExploreStorageError: LocalizedError {
    case unsupportedVersion
    var errorDescription: String? { "This wishlist was saved by a newer version of MONO. Please update the app." }
}

/// A missing file is an empty wishlist. Invalid data is an error, never silently
/// replaced. Writes are atomic and only occur after a successful read.
@MainActor
final class LocalExploreWishlist: ExploreWishlistProviding {
    private struct File: Codable {
        let version: Int
        var picks: [SavedPick]
    }
    let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MONO", isDirectory: true)
            .appendingPathComponent("wishlist-v1.json")
    }

    func fetchSavedPicks() async throws -> [SavedPick] {
        try read().picks.sorted { $0.savedAt > $1.savedAt }
    }

    func setSaved(_ pick: ShopPick, saved: Bool) async throws {
        var file = try read()
        if saved {
            if !file.picks.contains(where: { $0.id == pick.id }) {
                file.picks.append(SavedPick(pick: pick, savedAt: .now))
            }
        } else {
            file.picks.removeAll { $0.id == pick.id }
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(file).write(to: url, options: .atomic)
    }

    private func read() throws -> File {
        guard FileManager.default.fileExists(atPath: url.path) else { return File(version: 1, picks: []) }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        guard file.version == 1 else { throw ExploreStorageError.unsupportedVersion }
        return file
    }
}
