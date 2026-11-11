import XCTest
@testable import ExploreCore

@MainActor
private final class SuspendedWishlist: ExploreWishlistProviding {
    var calls = 0
    var continuation: CheckedContinuation<Void, Error>?
    func fetchSavedPicks() async throws -> [SavedPick] { [] }
    func setSaved(_ pick: ShopPick, saved: Bool) async throws {
        calls += 1
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
}

@MainActor
final class ExploreConcurrencyTests: XCTestCase {
    func testRepeatedTapIsIgnoredWhileSameItemIsSaving() async {
        let repo = SuspendedWishlist()
        let store = ExploreStore(wishlist: repo)
        await store.loadIfNeeded()
        let pick = ShopPicks.featured[0]
        let task = Task { await store.toggle(pick) }
        // Yield until the repository has reached the controllable suspension.
        while repo.continuation == nil { await Task.yield() }
        XCTAssertTrue(store.pendingIDs.contains(pick.id))
        await store.toggle(pick)
        XCTAssertEqual(repo.calls, 1)
        repo.continuation?.resume()
        await task.value
        XCTAssertTrue(store.isSaved(pick))
        XCTAssertTrue(store.pendingIDs.isEmpty)
    }
}
