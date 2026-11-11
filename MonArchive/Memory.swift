import Foundation

// A moment in the collection journey: when, where, with whom, photos and notes.
// One moment can cover many objects, e.g. every card from one fansign.
struct Moment: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: Kind
    var date: Date?
    var datePrecision: DatePrecision
    var placeName: String
    var placeKind: PlaceKind?
    var companions: [String]
    var photoFileNames: [String]
    var note: String
    var itemIDs: [UUID]

    init(
        id: UUID = UUID(),
        kind: Kind = .acquired,
        date: Date? = nil,
        datePrecision: DatePrecision = .day,
        placeName: String = "",
        placeKind: PlaceKind? = nil,
        companions: [String] = [],
        photoFileNames: [String] = [],
        note: String = "",
        itemIDs: [UUID] = []
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.datePrecision = datePrecision
        self.placeName = placeName
        self.placeKind = placeKind
        self.companions = companions
        self.photoFileNames = photoFileNames
        self.note = note
        self.itemIDs = itemIDs
    }

    var formattedDate: String {
        guard let date else { return "Date unknown" }
        switch datePrecision {
        case .day:
            return date.formatted(date: .abbreviated, time: .omitted)
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        case .year:
            return date.formatted(.dateTime.year())
        }
    }

    var summary: String {
        let place = placeName.isEmpty ? placeKind?.title : placeName
        return [formattedDate, place].compactMap { $0 }.joined(separator: " · ")
    }

    enum Kind: String, CaseIterable, Identifiable, Codable {
        case acquired
        case milestone
        case farewell

        var id: String { rawValue }

        var title: String {
            switch self {
            case .acquired: "Acquired"
            case .milestone: "Milestone"
            case .farewell: "Farewell"
            }
        }
    }

    enum DatePrecision: String, CaseIterable, Identifiable, Codable {
        case day
        case month
        case year

        var id: String { rawValue }

        var title: String {
            switch self {
            case .day: "Day"
            case .month: "Month"
            case .year: "Year"
            }
        }
    }

    enum PlaceKind: String, CaseIterable, Identifiable, Codable {
        case event
        case store
        case online
        case trade
        case gift
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .event: "Event"
            case .store: "Store"
            case .online: "Online"
            case .trade: "Trade"
            case .gift: "Gift"
            case .other: "Other"
            }
        }

        var systemImage: String {
            switch self {
            case .event: "ticket"
            case .store: "storefront"
            case .online: "globe"
            case .trade: "arrow.left.arrow.right"
            case .gift: "gift"
            case .other: "mappin"
            }
        }
    }
}

// Editable form state shared by the Create flow and the memory editor.
struct MomentDraft {
    var kind: Moment.Kind = .acquired
    var includesDate = false
    var date = Date.now
    var datePrecision: Moment.DatePrecision = .day
    var placeName = ""
    var placeKind: Moment.PlaceKind?
    var companionsText = ""
    var existingPhotoFileNames: [String] = []
    var newPhotos: [Data] = []
    var note = ""
    var itemIDs: [UUID] = []

    init(itemIDs: [UUID] = []) {
        self.itemIDs = itemIDs
    }

    init(moment: Moment) {
        kind = moment.kind
        includesDate = moment.date != nil
        date = moment.date ?? .now
        datePrecision = moment.datePrecision
        placeName = moment.placeName
        placeKind = moment.placeKind
        companionsText = moment.companions.joined(separator: ", ")
        existingPhotoFileNames = moment.photoFileNames
        note = moment.note
        itemIDs = moment.itemIDs
    }

    var companions: [String] {
        companionsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var photoCount: Int {
        existingPhotoFileNames.count + newPhotos.count
    }

    /// True when nothing personal has been entered, so no moment should be saved.
    var isEmpty: Bool {
        !includesDate
            && placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && placeKind == nil
            && companions.isEmpty
            && photoCount == 0
            && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Builds the moment, writing any newly picked photos to disk.
    func makeMoment(id: UUID = UUID()) -> Moment {
        let savedPhotos = newPhotos.compactMap(ImageStore.save)
        return Moment(
            id: id,
            kind: kind,
            date: includesDate ? date : nil,
            datePrecision: datePrecision,
            placeName: placeName.trimmingCharacters(in: .whitespacesAndNewlines),
            placeKind: placeKind,
            companions: companions,
            photoFileNames: existingPhotoFileNames + savedPhotos,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            itemIDs: itemIDs
        )
    }
}

// Parses and formats the price-paid field.
enum PriceText {
    static func parse(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    static func format(_ price: Double?) -> String {
        guard let price else { return "" }
        return price.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}
