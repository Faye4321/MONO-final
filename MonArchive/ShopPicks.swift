import Foundation

// eBay listings shown in the home "Picked for You" carousel.
// Static for now; once eBay API access is approved, replace
// `ShopPicks.featured` with data fetched through a backend proxy.
struct ShopPick: Identifiable, Hashable, Codable {
    let itemId: String
    let category: CollectionCategory
    let title: String
    let subtitle: String
    let priceUSD: Double?
    let note: String
    // Asset catalog name, if the image was added to Assets.xcassets.
    let imageName: String?
    // Remote image (e.g. https://i.ebayimg.com/...), used when no asset is set.
    let imageURL: URL?

    var id: String { itemId }

    var itemWebURL: URL {
        URL(string: "https://www.ebay.com/itm/\(itemId)")!
    }

    var priceText: String {
        guard let priceUSD else { return "PRICE ON EBAY" }
        return priceUSD.formatted(.currency(code: "USD"))
    }

    init(
        itemId: String,
        category: CollectionCategory,
        title: String,
        subtitle: String,
        priceUSD: Double?,
        note: String,
        imageName: String? = nil,
        imageURL: String? = nil
    ) {
        self.itemId = itemId
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.priceUSD = priceUSD
        self.note = note
        // Listing photos in Assets.xcassets are named pick_<itemId> (see scripts/import_pick_images.sh).
        self.imageName = imageName ?? "pick_\(itemId)"
        self.imageURL = imageURL.flatMap(URL.init(string:))
    }
}

enum ShopPicks {
    // Round-robin across categories so swiping mixes object types.
    static let featured: [ShopPick] = {
        let groups = [posters, dolls, albums, photocards]
        let longest = groups.map(\.count).max() ?? 0
        return (0..<longest).flatMap { index in
            groups.compactMap { index < $0.count ? $0[index] : nil }
        }
    }()

    /// `featured`, with the collection types the user picked during setup first.
    static func featured(prioritizing preferred: [CollectionCategory]) -> [ShopPick] {
        guard !preferred.isEmpty else { return featured }
        let rank = { (pick: ShopPick) in preferred.firstIndex(of: pick.category) ?? preferred.count }
        return featured.enumerated()
            .sorted { lhs, rhs in
                let (left, right) = (rank(lhs.element), rank(rhs.element))
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }

    static let posters: [ShopPick] = [
        ShopPick(
            itemId: "127936526937",
            category: .poster,
            title: "Zootopia",
            subtitle: "THEATRICAL DS · POSTER · 2016",
            priceUSD: 59.99,
            note: "Original US double-sided theatrical, new."
        )
    ]

    static let dolls: [ShopPick] = [
        ShopPick(
            itemId: "147447199735",
            category: .bjd,
            title: "F-54",
            subtitle: "VOLKS · FCS SD GIRL · 2015",
            priceUSD: 645.00,
            note: "Full Choice System custom, Pureskin Normal."
        )
    ]

    static let albums: [ShopPick] = [
        ShopPick(
            itemId: "385591274648",
            category: .vinyl,
            title: "FOR YOU",
            subtitle: "TATSURO YAMASHITA · LP · 1982",
            priceUSD: 47.99,
            note: "180g limited reissue with OBI."
        )
    ]

    static let photocards: [ShopPick] = [
        ShopPick(
            itemId: "376556390459",
            category: .photocard,
            title: "EN-DAY 3rd Anniv.",
            subtitle: "&TEAM · CLEAR CARD",
            priceUSD: 15.99,
            note: "Random clear trading card, choose member."
        )
    ]
}
