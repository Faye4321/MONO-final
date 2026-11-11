import SwiftUI

@MainActor
final class CollectionStore: ObservableObject {
    @Published private(set) var items: [CollectibleItem]
    @Published private(set) var moments: [Moment]

    /// An eBay pick the user opened; asked about when they return to the app.
    @Published var pendingPurchase: ShopPick?

    /// The archive file; also what the Profile export shares.
    let archiveURL: URL
    private let legacyURL: URL
    private let seedItems: [CollectibleItem]

    private struct ArchiveFile: Codable {
        var version = 1
        var userItems: [CollectibleItem]
        // Seed objects the user has edited, stored in full.
        var seedOverrides: [CollectibleItem]
        var moments: [Moment]
        // Seed objects the user has deleted. Optional so older files decode.
        var deletedSeedIDs: [UUID]? = nil
    }

    init(seedItems: [CollectibleItem] = SeedData.itemsWithDemoDates) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        archiveURL = documents.appendingPathComponent("archive.json")
        legacyURL = documents.appendingPathComponent("uploaded-objects.json")
        self.seedItems = seedItems

        let archive = Self.loadArchive(from: archiveURL, legacyURL: legacyURL)
        let overrides = Dictionary(
            archive.seedOverrides.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        let deletedSeedIDs = Set(archive.deletedSeedIDs ?? [])
        items = seedItems.filter { !deletedSeedIDs.contains($0.id) }.map { seed in
            guard var edited = overrides[seed.id] else { return seed }
            // Edits saved before `addedOn` existed keep the seed's date.
            if edited.addedOn == nil { edited.addedOn = seed.addedOn }
            return edited
        } + archive.userItems
        moments = archive.moments

        if !FileManager.default.fileExists(atPath: archiveURL.path) {
            save()
        }
    }

    // MARK: - Objects

    func item(id: UUID) -> CollectibleItem? {
        items.first { $0.id == id }
    }

    /// Objects still in the collection.
    var activeItems: [CollectibleItem] {
        items.filter { $0.partedOn == nil }
    }

    /// Objects the user has sold, traded or given away.
    var pastItems: [CollectibleItem] {
        items
            .filter { $0.partedOn != nil }
            .sorted { ($0.partedOn ?? .distantPast) > ($1.partedOn ?? .distantPast) }
    }

    func items(for category: CollectionCategory) -> [CollectibleItem] {
        activeItems.filter { $0.category == category }
    }

    func count(for category: CollectionCategory) -> Int {
        items(for: category).count
    }

    func addItem(_ item: CollectibleItem) {
        var item = item
        if item.addedOn == nil { item.addedOn = .now }
        items.append(item)
        save()
    }

    func updateItem(_ item: CollectibleItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func deleteItem(_ item: CollectibleItem) {
        items.removeAll { $0.id == item.id }
        if let imageFileName = item.imageFileName {
            ImageStore.delete(named: imageFileName)
        }

        // Keep moments that still describe other objects.
        for index in moments.indices {
            moments[index].itemIDs.removeAll { $0 == item.id }
        }
        let orphaned = moments.filter(\.itemIDs.isEmpty)
        orphaned.flatMap(\.photoFileNames).forEach(ImageStore.delete(named:))
        moments.removeAll { $0.itemIDs.isEmpty }

        save()
    }

    func importItems(_ newItems: [CollectibleItem], moments newMoments: [Moment]) {
        items.append(contentsOf: newItems.map { item in
            var item = item
            if item.addedOn == nil { item.addedOn = .now }
            return item
        })
        moments.append(contentsOf: newMoments)
        save()
    }

    /// Moves an object to Past Collection and records the farewell.
    /// Its memories are kept.
    func partWith(_ itemID: UUID, farewell: Moment) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].partedOn = farewell.date ?? .now
        moments.append(farewell)
        save()
    }

    func restore(_ itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].partedOn = nil
        save()
    }

    /// Adds an object bought from a Picked for You listing, with an
    /// acquisition memory prefilled from the listing. Returns that memory.
    @discardableResult
    func addPurchase(of pick: ShopPick) -> Moment {
        let creator = pick.subtitle
            .components(separatedBy: " · ")
            .first?
            .capitalized ?? ""

        let item = CollectibleItem(
            title: pick.title,
            creator: creator,
            category: pick.category,
            note: "Bought on eBay · listing \(pick.itemId)",
            colorA: "D5B99C",
            colorB: "706B63",
            isUserCreated: true,
            pricePaid: pick.priceUSD,
            addedOn: .now
        )
        let moment = Moment(
            kind: .acquired,
            date: .now,
            placeName: "eBay",
            placeKind: .online,
            itemIDs: [item.id]
        )

        items.append(item)
        moments.append(moment)
        save()
        return moment
    }

    // MARK: - Moments

    func moments(for itemID: UUID) -> [Moment] {
        moments
            .filter { $0.itemIDs.contains(itemID) }
            .sorted(by: Self.chronological)
    }

    func hasMemories(_ itemID: UUID) -> Bool {
        moments.contains { $0.itemIDs.contains(itemID) }
    }

    /// Acquisition moments created recently, offered when adding more objects
    /// so a batch (e.g. one fansign) can share a single moment.
    func recentAcquisitions(withinDays days: Int = 3) -> [Moment] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let recent = moments
            .filter { $0.kind == .acquired && ($0.date ?? .distantPast) >= cutoff }
            .sorted(by: Self.chronological)
        return Array(recent.reversed())
    }

    func addMoment(_ moment: Moment) {
        moments.append(moment)
        save()
    }

    func updateMoment(_ moment: Moment) {
        guard let index = moments.firstIndex(where: { $0.id == moment.id }) else { return }

        let removedPhotos = Set(moments[index].photoFileNames).subtracting(moment.photoFileNames)
        removedPhotos.forEach(ImageStore.delete(named:))

        moments[index] = moment
        save()
    }

    func deleteMoment(_ moment: Moment) {
        moment.photoFileNames.forEach(ImageStore.delete(named:))
        moments.removeAll { $0.id == moment.id }
        save()
    }

    func attach(itemID: UUID, toMoment momentID: UUID) {
        guard let index = moments.firstIndex(where: { $0.id == momentID }),
              !moments[index].itemIDs.contains(itemID) else { return }
        moments[index].itemIDs.append(itemID)
        save()
    }

    /// Everything the collection calendar shows: every memory, plus an
    /// "added" entry on `addedOn` for each object that has no dated
    /// acquisition memory. Computed on read, so the calendar always
    /// reflects the current objects and memories.
    var calendarSource: CalendarSource {
        let acquired = Set(
            moments
                .filter { $0.kind == .acquired && $0.date != nil }
                .flatMap(\.itemIDs)
        )
        let added = items
            .filter { !acquired.contains($0.id) }
            .map { item in
                // The entry reuses the object's id, so it is stable across reads.
                Moment(id: item.id, kind: .acquired, date: item.addedOn, itemIDs: [item.id])
            }
        return CalendarSource(moments: moments + added, addedEntryIDs: Set(added.map(\.id)))
    }

    /// Undated moments sort after dated ones.
    nonisolated static func chronological(_ lhs: Moment, _ rhs: Moment) -> Bool {
        switch (lhs.date, rhs.date) {
        case let (left?, right?):
            return left < right
        case (.some, .none):
            return true
        default:
            return false
        }
    }

    // MARK: - Persistence

    private func save() {
        let seedByID = Dictionary(uniqueKeysWithValues: seedItems.map { ($0.id, $0) })
        let archive = ArchiveFile(
            userItems: items.filter { seedByID[$0.id] == nil },
            seedOverrides: items.filter { item in
                guard let seed = seedByID[item.id] else { return false }
                return seed != item
            },
            moments: moments,
            deletedSeedIDs: seedItems.map(\.id).filter { id in !items.contains { $0.id == id } }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(archive) else { return }
        try? data.write(to: archiveURL, options: .atomic)
    }

    private static func loadArchive(from url: URL, legacyURL: URL) -> ArchiveFile {
        let empty = ArchiveFile(userItems: [], seedOverrides: [], moments: [])

        if let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let archive = try? decoder.decode(ArchiveFile.self, from: data) {
                return archive
            }

            // Never overwrite a file we could not read; set it aside instead.
            let stamp = Int(Date.now.timeIntervalSince1970)
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("archive.corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return empty
        }

        // First launch after the update: migrate uploads saved by the old store.
        // The legacy file is left in place as a backup.
        guard let data = try? Data(contentsOf: legacyURL),
              let legacyItems = try? JSONDecoder().decode([CollectibleItem].self, from: data) else {
            return empty
        }

        let migrated = legacyItems.map { item -> CollectibleItem in
            var item = item
            if let imageData = item.imageData, let fileName = ImageStore.save(imageData) {
                item.imageFileName = fileName
                item.imageData = nil
            }
            return item
        }
        return ArchiveFile(userItems: migrated, seedOverrides: [], moments: [])
    }
}

struct CalendarSource {
    let moments: [Moment]
    /// Entries that stand for "object added" rather than a user memory.
    let addedEntryIDs: Set<UUID>
}
