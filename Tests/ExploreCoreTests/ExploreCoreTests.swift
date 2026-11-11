import XCTest
@testable import ExploreCore

final class ExploreQueryTests: XCTestCase {
    private func pick(_ id: String, _ title: String, _ category: CollectionCategory = .vinyl, price: Double? = nil) -> ShopPick {
        ShopPick(itemId: id, category: category, title: title, subtitle: "Artist · 1982", priceUSD: price, note: "Limited edition")
    }

    func testSearchRequiresEveryTermAndIgnoresCaseAccentsAndWhitespace() {
        let item = pick("1", "Café Blue")
        XCTAssertTrue(ExploreQuery.matches(item, query: "  CAFE\n1982  ", category: .vinyl))
        XCTAssertFalse(ExploreQuery.matches(item, query: "Cafe missing", category: nil))
        XCTAssertFalse(ExploreQuery.matches(item, query: "Cafe", category: .poster))
        XCTAssertTrue(ExploreQuery.matches(item, query: " \n", category: nil))
    }

    func testPriceSortingPutsUnknownPricesLastInBothDirections() {
        let items = [pick("1", "Unknown"), pick("2", "Cheap", price: 4), pick("3", "Costly", price: 15)]
        XCTAssertEqual(ExploreQuery.results(items, query: "", category: nil, sort: .priceLow).map(\.id), ["2", "3", "1"])
        XCTAssertEqual(ExploreQuery.results(items, query: "", category: nil, sort: .priceHigh).map(\.id), ["3", "2", "1"])
    }

    func testRankingPrefersInterestsAndKeepsSavedFindsDiscoverableAtEnd() {
        let a = pick("1", "Album"), b = pick("2", "Poster", .poster), c = pick("3", "Card", .photocard)
        let saved = [SavedPick(pick: b, savedAt: .now)]
        XCTAssertEqual(ExploreQuery.ranked([a, b, c], preferred: [.photocard], saved: saved, collected: [.vinyl]).map(\.id), ["3", "1", "2"])
    }

    func testDeduplicationAndStableEditorialTies() {
        let a = pick("1", "One"), b = pick("2", "Two")
        XCTAssertEqual(ExploreQuery.ranked([a, b, a], preferred: [], saved: [], collected: []).map(\.id), ["1", "2"])
        XCTAssertTrue(ExploreQuery.results([], query: "", category: nil, sort: .title).isEmpty)
    }

    func testShopPickSnapshotRoundTrips() throws {
        let original = SavedPick(pick: pick("127936526937", "Poster", .poster, price: 59.99), savedAt: Date(timeIntervalSince1970: 100))
        let decoded = try JSONDecoder().decode(SavedPick.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.pick.itemWebURL.host, "www.ebay.com")
    }
}

@MainActor
final class ExplorePersistenceTests: XCTestCase {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("wishlist.json")
    }

    func testMissingFileIsEmptyAndSavedStateSurvivesNewRepository() async throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repo = LocalExploreWishlist(url: url)
        let empty = try await repo.fetchSavedPicks()
        XCTAssertTrue(empty.isEmpty)
        let pick = ShopPicks.featured[0]
        try await repo.setSaved(pick, saved: true)
        let first = try await repo.fetchSavedPicks()
        try await repo.setSaved(pick, saved: true)
        let second = try await LocalExploreWishlist(url: url).fetchSavedPicks()
        XCTAssertEqual(first, second) // idempotency also preserves savedAt
        try await repo.setSaved(pick, saved: false)
        let removed = try await repo.fetchSavedPicks()
        XCTAssertTrue(removed.isEmpty)
    }

    func testCorruptWishlistIsNotOverwrittenBySave() async throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data("invalid JSON".utf8)
        try bytes.write(to: url)
        do {
            try await LocalExploreWishlist(url: url).setSaved(ShopPicks.featured[0], saved: true)
            XCTFail("Corrupt file must cause an error")
        } catch { XCTAssertEqual(try Data(contentsOf: url), bytes) }
    }

    func testUnsupportedVersionIsKept() async throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data("{\"version\":99,\"picks\":[]}".utf8)
        try bytes.write(to: url)
        do {
            _ = try await LocalExploreWishlist(url: url).fetchSavedPicks()
            XCTFail("Unknown version must cause an error")
        } catch { XCTAssertEqual(try Data(contentsOf: url), bytes) }
    }
}

@MainActor
private final class TestRepository: ExploreCatalogProviding, ExploreWishlistProviding {
    var fail = false
    var empty = false
    var items: [SavedPick] = []
    var writes = 0
    func fetchPicks() async throws -> [ShopPick] {
        if fail { throw CocoaError(.fileReadUnknown) }
        return empty ? [] : ShopPicks.featured
    }
    func fetchSavedPicks() async throws -> [SavedPick] {
        if fail { throw CocoaError(.fileReadUnknown) }
        return items
    }
    func setSaved(_ pick: ShopPick, saved: Bool) async throws {
        writes += 1
        if fail { throw CocoaError(.fileWriteUnknown) }
        if saved { items.append(SavedPick(pick: pick, savedAt: .now)) }
        else { items.removeAll { $0.id == pick.id } }
    }
}

@MainActor
final class ExploreStoreTests: XCTestCase {
    func testFailedWriteKeepsPreviousStateThenRetryAndUndoWork() async {
        let repo = TestRepository(), pick = ShopPicks.featured[0]
        let store = ExploreStore(catalog: repo, wishlist: repo)
        await store.loadIfNeeded()
        repo.fail = true
        await store.toggle(pick)
        XCTAssertFalse(store.isSaved(pick))
        XCTAssertNotNil(store.mutationIssue)
        XCTAssertTrue(store.pendingIDs.isEmpty)
        repo.fail = false
        await store.setSaved(pick, saved: true)
        XCTAssertTrue(store.isSaved(pick))
        await store.setSaved(pick, saved: false)
        XCTAssertEqual(store.feedback?.removedPick?.id, pick.id)
        await store.setSaved(pick, saved: true)
        XCTAssertTrue(store.isSaved(pick))
    }

    func testInitialLoadFailureBlocksWritesAndRetryRecovers() async {
        let repo = TestRepository(); repo.fail = true
        let store = ExploreStore(catalog: repo, wishlist: repo)
        await store.loadIfNeeded()
        if case .failed = store.catalogState {} else { XCTFail("Expected failure") }
        if case .failed = store.wishlistState {} else { XCTFail("Expected failure") }
        await store.toggle(ShopPicks.featured[0])
        XCTAssertEqual(repo.writes, 0)
        repo.fail = false
        await store.loadCatalog(); await store.loadWishlist()
        XCTAssertEqual(store.catalogState, .loaded)
        XCTAssertEqual(store.wishlistState, .loaded)
    }

    func testEmptyCatalogIsSuccessNotError() async {
        let repo = TestRepository(); repo.empty = true
        let store = ExploreStore(catalog: repo, wishlist: repo)
        await store.loadIfNeeded()
        XCTAssertEqual(store.catalogState, .loaded)
        XCTAssertTrue(store.picks.isEmpty)
    }
}
