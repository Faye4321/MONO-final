import Foundation

// Imports an existing collection from a spreadsheet exported as CSV.
//
// Columns (header row required, any order, all but `title` optional):
//   category     album | vinyl | bjd | poster | photocard
//   title, creator, year
//   price        price paid in USD
//   condition    mint | near mint | good | fair | worn
//   rarity       common | limited | rare | one of a kind
//   meaning      one line on why it matters
//   note         archive note about the object
//   date         yyyy-mm-dd, yyyy-mm or yyyy
//   place        where it was acquired
//   place_type   event | store | online | trade | gift | other
//   with         companions, separated by ";"
//   memory_note  note for the memory
//
// Rows sharing the same date, place and companions become one Moment.
enum CSVImporter {
    struct Result {
        var items: [CollectibleItem] = []
        var moments: [Moment] = []
        var skippedRows: [Int] = []
    }

    enum ImportError: LocalizedError {
        case unreadable
        case missingTitleColumn

        var errorDescription: String? {
            switch self {
            case .unreadable: "The file could not be read as UTF-8 text."
            case .missingTitleColumn: "The first row must be a header with a \"title\" column."
            }
        }
    }

    static func importFile(at url: URL) throws -> Result {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            throw ImportError.unreadable
        }
        return try makeResult(from: text)
    }

    static func makeResult(from text: String) throws -> Result {
        let rows = parse(text)
        guard let header = rows.first else { throw ImportError.missingTitleColumn }

        let columns = header.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard columns.contains("title") else { throw ImportError.missingTitleColumn }

        var result = Result()
        var momentIndexByKey: [String: Int] = [:]

        for (offset, row) in rows.dropFirst().enumerated() {
            let rowNumber = offset + 2
            var fields: [String: String] = [:]
            for (index, column) in columns.enumerated() where index < row.count {
                fields[column] = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let title = fields["title"] ?? ""
            guard !title.isEmpty else {
                if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    result.skippedRows.append(rowNumber)
                }
                continue
            }

            let category = category(from: fields["category"])
            let item = CollectibleItem(
                title: title,
                creator: fields["creator"] ?? "",
                year: fields["year"].flatMap { Int($0) },
                category: category,
                note: fields["note"] ?? "",
                colorA: "D5B99C",
                colorB: "706B63",
                isUserCreated: true,
                pricePaid: fields["price"].flatMap(PriceText.parse),
                condition: match(fields["condition"], in: ItemCondition.allCases),
                rarity: match(fields["rarity"], in: Rarity.allCases),
                meaning: fields["meaning"] ?? ""
            )
            result.items.append(item)

            let parsedDate = date(from: fields["date"])
            let place = fields["place"] ?? ""
            let placeKind = match(fields["place_type"], in: Moment.PlaceKind.allCases)
            let companions = (fields["with"] ?? "")
                .split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let memoryNote = fields["memory_note"] ?? ""

            let hasMemory = parsedDate != nil || !place.isEmpty || placeKind != nil
                || !companions.isEmpty || !memoryNote.isEmpty
            guard hasMemory else { continue }

            let key = [fields["date"] ?? "", place.lowercased(), companions.joined(separator: ";").lowercased()]
                .joined(separator: "|")

            if let index = momentIndexByKey[key] {
                result.moments[index].itemIDs.append(item.id)
                if !memoryNote.isEmpty, !result.moments[index].note.contains(memoryNote) {
                    let existing = result.moments[index].note
                    result.moments[index].note = existing.isEmpty ? memoryNote : existing + "\n" + memoryNote
                }
            } else {
                momentIndexByKey[key] = result.moments.count
                result.moments.append(
                    Moment(
                        kind: .acquired,
                        date: parsedDate?.date,
                        datePrecision: parsedDate?.precision ?? .day,
                        placeName: place,
                        placeKind: placeKind,
                        companions: companions,
                        note: memoryNote,
                        itemIDs: [item.id]
                    )
                )
            }
        }

        return result
    }

    // MARK: - Field Parsing

    private static func category(from raw: String?) -> CollectionCategory {
        switch raw?.lowercased() ?? "" {
        case "bjd", "doll", "dolls": .bjd
        case "poster", "posters", "movie poster": .poster
        case "photocard", "photocards", "pc", "card": .photocard
        default: .vinyl
        }
    }

    private static func match<Option: TitledOption & RawRepresentable>(
        _ raw: String?,
        in options: [Option]
    ) -> Option? where Option.RawValue == String {
        guard let raw, !raw.isEmpty else { return nil }
        let normalized = raw.lowercased().replacingOccurrences(of: " ", with: "")
        return options.first {
            $0.rawValue.lowercased() == normalized
                || $0.title.lowercased().replacingOccurrences(of: " ", with: "") == normalized
        }
    }

    private static func date(from raw: String?) -> (date: Date, precision: Moment.DatePrecision)? {
        guard let raw, !raw.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats: [(String, Moment.DatePrecision)] = [
            ("yyyy-MM-dd", .day),
            ("yyyy/MM/dd", .day),
            ("yyyy-MM", .month),
            ("yyyy/MM", .month),
            ("yyyy", .year)
        ]
        for (format, precision) in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return (date, precision)
            }
        }
        return nil
    }

    /// Splits CSV text into rows of fields, honouring quoted fields.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var characters = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        if characters.first == "\u{FEFF}" {
            characters.removeFirst()
        }

        var index = 0
        while index < characters.count {
            let character = characters[index]
            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n", "\r":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                default:
                    field.append(character)
                }
            }
            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
