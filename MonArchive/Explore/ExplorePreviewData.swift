#if DEBUG
import SwiftUI

@MainActor
struct ExplorePreviewCatalog: ExploreCatalogProviding {
    enum Scenario { case loaded, empty, error, loading }
    var scenario = Scenario.loaded
    func fetchPicks() async throws -> [ShopPick] {
        if scenario == .loading { try await Task.sleep(nanoseconds: 60_000_000_000) }
        if scenario == .error { throw CocoaError(.fileReadUnknown) }
        return scenario == .empty ? [] : ShopPicks.featured
    }
}

@MainActor
final class ExplorePreviewWishlist: ExploreWishlistProviding {
    var picks: [SavedPick]
    init(picks: [SavedPick] = []) { self.picks = picks }
    func fetchSavedPicks() async throws -> [SavedPick] { picks }
    func setSaved(_ pick: ShopPick, saved: Bool) async throws {
        picks.removeAll { $0.id == pick.id }
        if saved { picks.append(SavedPick(pick: pick, savedAt: .now)) }
    }
}

#Preview("Explore · Empty") {
    HomeView(catalogProvider: ExplorePreviewCatalog(scenario: .empty), wishlistProvider: ExplorePreviewWishlist())
        .environmentObject(CollectionStore())
}
#Preview("Explore · Error & retry") {
    HomeView(catalogProvider: ExplorePreviewCatalog(scenario: .error), wishlistProvider: ExplorePreviewWishlist())
        .environmentObject(CollectionStore())
}
#Preview("Explore · Loading") {
    HomeView(catalogProvider: ExplorePreviewCatalog(scenario: .loading), wishlistProvider: ExplorePreviewWishlist())
        .environmentObject(CollectionStore())
}
#endif
