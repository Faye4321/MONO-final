import Foundation
import Combine

enum ExploreLoadState: Equatable {
    case idle, loading, loaded
    case failed(String)
    var isLoaded: Bool { self == .loaded }
}

struct ExploreFeedback {
    let id = UUID()
    let message: String
    let removedPick: ShopPick?
}

struct ExploreMutationIssue: Identifiable {
    let id = UUID()
    let pick: ShopPick
    let desiredSaved: Bool
}

@MainActor
final class ExploreStore: ObservableObject {
    @Published private(set) var picks: [ShopPick] = []
    @Published private(set) var saved: [SavedPick] = []
    @Published private(set) var catalogState: ExploreLoadState = .idle
    @Published private(set) var wishlistState: ExploreLoadState = .idle
    @Published private(set) var pendingIDs = Set<String>()
    @Published var feedback: ExploreFeedback?
    @Published var mutationIssue: ExploreMutationIssue?

    private let catalog: any ExploreCatalogProviding
    private let wishlist: any ExploreWishlistProviding

    init(catalog: (any ExploreCatalogProviding)? = nil, wishlist: (any ExploreWishlistProviding)? = nil) {
        self.catalog = catalog ?? BundledExploreCatalog()
        self.wishlist = wishlist ?? LocalExploreWishlist()
    }

    func loadIfNeeded() async {
        if catalogState == .idle { await loadCatalog() }
        if wishlistState == .idle { await loadWishlist() }
    }

    func loadCatalog() async {
        guard catalogState != .loading else { return }
        catalogState = .loading
        do {
            let response = try await catalog.fetchPicks()
            try Task.checkCancellation()
            picks = ExploreQuery.unique(response)
            catalogState = .loaded
        } catch is CancellationError {
            catalogState = .idle
        } catch {
            catalogState = .failed("We couldn’t load new finds. Pull to refresh or try again.")
        }
    }

    func loadWishlist() async {
        guard wishlistState != .loading, pendingIDs.isEmpty else { return }
        wishlistState = .loading
        do {
            let response = try await wishlist.fetchSavedPicks()
            try Task.checkCancellation()
            var seen = Set<String>()
            saved = response.sorted { $0.savedAt > $1.savedAt }.filter { seen.insert($0.id).inserted }
            wishlistState = .loaded
        } catch is CancellationError {
            wishlistState = .idle
        } catch {
            wishlistState = .failed("Your wishlist couldn’t be loaded. Your saved finds haven’t been changed. Please try again.")
        }
    }

    func isSaved(_ pick: ShopPick) -> Bool { saved.contains { $0.id == pick.id } }

    func toggle(_ pick: ShopPick) async {
        await setSaved(pick, saved: !isSaved(pick))
    }

    /// Show a spinner while saving; publish success only after the repository
    /// commits. Failed operations leave both the list and heart state unchanged.
    func setSaved(_ pick: ShopPick, saved shouldSave: Bool) async {
        guard wishlistState.isLoaded, pendingIDs.insert(pick.id).inserted else { return }
        defer { pendingIDs.remove(pick.id) }
        do {
            try await wishlist.setSaved(pick, saved: shouldSave)
            if shouldSave {
                if !isSaved(pick) { saved.insert(SavedPick(pick: pick, savedAt: .now), at: 0) }
                feedback = ExploreFeedback(message: "Saved to wishlist", removedPick: nil)
            } else {
                saved.removeAll { $0.id == pick.id }
                feedback = ExploreFeedback(message: "Removed from wishlist", removedPick: pick)
            }
        } catch {
            mutationIssue = ExploreMutationIssue(pick: pick, desiredSaved: shouldSave)
        }
    }
}
