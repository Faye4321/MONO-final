import Foundation

struct SavedPick: Identifiable, Codable, Hashable {
    let pick: ShopPick
    let savedAt: Date
    var id: String { pick.id }
}

enum ExploreSort: String, CaseIterable, Identifiable {
    case recommended = "Recommended"
    case title = "Title A–Z"
    case priceLow = "Price: low to high"
    case priceHigh = "Price: high to low"
    var id: String { rawValue }
}

/// Pure functions shared by the UI and the executable Swift package tests.
/// Recommendations run on device; no claim of an AI or live marketplace feed.
enum ExploreQuery {
    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    static func matches(_ pick: ShopPick, query: String, category: CollectionCategory?) -> Bool {
        if let category, pick.category != category { return false }
        let terms = normalized(query).split(whereSeparator: { $0.isWhitespace })
        let haystack = normalized([pick.title, pick.subtitle, pick.note, pick.category.title].joined(separator: " "))
        return terms.allSatisfy { haystack.contains($0) }
    }

    static func unique(_ picks: [ShopPick]) -> [ShopPick] {
        var seen = Set<String>()
        return picks.filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
    }

    static func ranked(
        _ picks: [ShopPick],
        preferred: [CollectionCategory],
        saved: [SavedPick],
        collected: [CollectionCategory]
    ) -> [ShopPick] {
        let savedIDs = Set(saved.map(\.id))
        let savedCategories = Set(saved.map { $0.pick.category })
        let collectedCategories = Set(collected)
        func score(_ pick: ShopPick) -> Int {
            (preferred.contains(pick.category) ? 4 : 0)
                + (savedCategories.contains(pick.category) ? 2 : 0)
                + (collectedCategories.contains(pick.category) ? 1 : 0)
        }
        return unique(picks).enumerated().sorted { left, right in
            // New discoveries before already-saved objects; ties keep editorial order.
            let leftSaved = savedIDs.contains(left.element.id)
            let rightSaved = savedIDs.contains(right.element.id)
            if leftSaved != rightSaved { return !leftSaved }
            let lhs = score(left.element), rhs = score(right.element)
            return lhs == rhs ? left.offset < right.offset : lhs > rhs
        }.map(\.element)
    }

    static func results(
        _ picks: [ShopPick], query: String, category: CollectionCategory?, sort: ExploreSort
    ) -> [ShopPick] {
        let filtered = unique(picks).filter { matches($0, query: query, category: category) }
        return filtered.enumerated().sorted { left, right in
            switch sort {
            case .recommended:
                return left.offset < right.offset
            case .title:
                let comparison = normalized(left.element.title).compare(normalized(right.element.title))
                return comparison == .orderedSame ? left.offset < right.offset : comparison == .orderedAscending
            case .priceLow, .priceHigh:
                // Unknown prices stay at the end in both directions.
                switch (left.element.priceUSD, right.element.priceUSD) {
                case let (lhs?, rhs?) where lhs != rhs:
                    return sort == .priceLow ? lhs < rhs : lhs > rhs
                case (.some, .none): return true
                case (.none, .some): return false
                default: return left.offset < right.offset
                }
            }
        }.map(\.element)
    }

    static func reason(
        for pick: ShopPick, preferred: [CollectionCategory], saved: [SavedPick], collected: [CollectionCategory]
    ) -> String {
        if preferred.contains(pick.category) { return "Matches your collecting interests" }
        if saved.contains(where: { $0.pick.category == pick.category }) { return "Inspired by your wishlist" }
        if collected.contains(pick.category) { return "A new find for your collection" }
        return "An editor’s pick to explore"
    }
}
