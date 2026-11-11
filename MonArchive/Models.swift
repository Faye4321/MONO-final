import Foundation
import CoreGraphics

enum CollectionCategory: String, CaseIterable, Identifiable, Hashable, Codable {
    case vinyl
    case bjd
    case poster
    case photocard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vinyl: "Albums"
        case .bjd: "Ball-Jointed Dolls"
        case .poster: "Movie Posters"
        case .photocard: "Photocards"
        }
    }

    var shelfLabel: String {
        switch self {
        case .vinyl: "RECORD WALL"
        case .bjd: "DISPLAY CABINET"
        case .poster: "GALLERY WALL"
        case .photocard: "BINDER No. 01"
        }
    }

    var systemImage: String {
        switch self {
        case .vinyl: "record.circle"
        case .bjd: "figure.stand"
        case .poster: "rectangle.portrait"
        case .photocard: "rectangle.stack"
        }
    }

    var artworkAspectRatio: CGFloat {
        switch self {
        case .vinyl: 1
        case .bjd: 0.72
        case .poster: 0.67
        case .photocard: 0.68
        }
    }
}

struct CollectibleItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var creator: String
    var year: Int?
    var category: CollectionCategory
    var note: String
    var colorA: String
    var colorB: String
    var imageName: String?
    // Legacy inline image data; migrated to `imageFileName` on load.
    var imageData: Data?
    var imageFileName: String?
    var brightness: Double
    var contrast: Double
    var saturation: Double
    var isUserCreated: Bool

    // Standard data
    var pricePaid: Double?
    var condition: ItemCondition?
    var rarity: Rarity?

    // Personal data kept on the object itself; time, place, people and
    // photos live on `Moment`s so one moment can cover many objects.
    var meaning: String
    var meaningTag: MeaningTag?

    // Set when the object leaves the collection; it moves to Past Collection.
    var partedOn: Date?

    /// When the object was added to the archive. Places it on the collection
    /// calendar when it has no dated acquisition memory.
    var addedOn: Date?

    init(
        id: UUID = UUID(),
        title: String,
        creator: String,
        year: Int? = nil,
        category: CollectionCategory,
        note: String,
        colorA: String,
        colorB: String,
        imageName: String? = nil,
        imageData: Data? = nil,
        imageFileName: String? = nil,
        brightness: Double = 0,
        contrast: Double = 1,
        saturation: Double = 1,
        isUserCreated: Bool = false,
        pricePaid: Double? = nil,
        condition: ItemCondition? = nil,
        rarity: Rarity? = nil,
        meaning: String = "",
        meaningTag: MeaningTag? = nil,
        partedOn: Date? = nil,
        addedOn: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.creator = creator
        self.year = year
        self.category = category
        self.note = note
        self.colorA = colorA
        self.colorB = colorB
        self.imageName = imageName
        self.imageData = imageData
        self.imageFileName = imageFileName
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.isUserCreated = isUserCreated
        self.pricePaid = pricePaid
        self.condition = condition
        self.rarity = rarity
        self.meaning = meaning
        self.meaningTag = meaningTag
        self.partedOn = partedOn
        self.addedOn = addedOn
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, creator, year, category, note, colorA, colorB
        case imageName, imageData, imageFileName
        case brightness, contrast, saturation, isUserCreated
        case pricePaid, condition, rarity, meaning, meaningTag, partedOn, addedOn
    }

    // Tolerates files written before the memory fields existed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        creator = try container.decodeIfPresent(String.self, forKey: .creator) ?? ""
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        category = try container.decode(CollectionCategory.self, forKey: .category)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        colorA = try container.decodeIfPresent(String.self, forKey: .colorA) ?? "D5B99C"
        colorB = try container.decodeIfPresent(String.self, forKey: .colorB) ?? "706B63"
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        brightness = try container.decodeIfPresent(Double.self, forKey: .brightness) ?? 0
        contrast = try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
        saturation = try container.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
        isUserCreated = try container.decodeIfPresent(Bool.self, forKey: .isUserCreated) ?? false
        pricePaid = try container.decodeIfPresent(Double.self, forKey: .pricePaid)
        condition = try container.decodeIfPresent(ItemCondition.self, forKey: .condition)
        rarity = try container.decodeIfPresent(Rarity.self, forKey: .rarity)
        meaning = try container.decodeIfPresent(String.self, forKey: .meaning) ?? ""
        meaningTag = try container.decodeIfPresent(MeaningTag.self, forKey: .meaningTag)
        partedOn = try container.decodeIfPresent(Date.self, forKey: .partedOn)
        addedOn = try container.decodeIfPresent(Date.self, forKey: .addedOn)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(creator, forKey: .creator)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encode(category, forKey: .category)
        try container.encode(note, forKey: .note)
        try container.encode(colorA, forKey: .colorA)
        try container.encode(colorB, forKey: .colorB)
        try container.encodeIfPresent(imageName, forKey: .imageName)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(contrast, forKey: .contrast)
        try container.encode(saturation, forKey: .saturation)
        try container.encode(isUserCreated, forKey: .isUserCreated)
        try container.encodeIfPresent(pricePaid, forKey: .pricePaid)
        try container.encodeIfPresent(condition, forKey: .condition)
        try container.encodeIfPresent(rarity, forKey: .rarity)
        try container.encode(meaning, forKey: .meaning)
        try container.encodeIfPresent(meaningTag, forKey: .meaningTag)
        try container.encodeIfPresent(partedOn, forKey: .partedOn)
        try container.encodeIfPresent(addedOn, forKey: .addedOn)
    }
}

// MARK: - Standard Data

enum ItemCondition: String, CaseIterable, Identifiable, Codable {
    case mint
    case nearMint
    case good
    case fair
    case worn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mint: "Mint"
        case .nearMint: "Near Mint"
        case .good: "Good"
        case .fair: "Fair"
        case .worn: "Worn"
        }
    }
}

enum Rarity: String, CaseIterable, Identifiable, Codable {
    case common
    case limited
    case rare
    case oneOfAKind

    var id: String { rawValue }

    var title: String {
        switch self {
        case .common: "Common"
        case .limited: "Limited"
        case .rare: "Rare"
        case .oneOfAKind: "One of a Kind"
        }
    }
}

// MARK: - Meaning

enum MeaningTag: String, CaseIterable, Identifiable, Codable {
    case firstInSeries
    case gift
    case eventExclusive
    case favorite
    case milestone
    case grail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstInSeries: "First in Series"
        case .gift: "Gift"
        case .eventExclusive: "Event Exclusive"
        case .favorite: "Favorite"
        case .milestone: "Milestone"
        case .grail: "Grail"
        }
    }
}
