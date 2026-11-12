import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

@MainActor
final class CollectionStore: ObservableObject {
    @Published private(set) var items: [CollectibleItem]
    @Published private(set) var moments: [Moment]

    /// An eBay pick the user opened; asked about when they return to the app.
    @Published var pendingPurchase: ShopPick?

    /// The archive file; also what the Profile export shares.
    private(set) var archiveURL: URL
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

    @Published private(set) var cloudStatus = "Not connected"
    @Published private(set) var cloudError: String?
    @Published private(set) var cloudReady = false
    @Published private(set) var accountUID: String?
    @Published private(set) var hasLegacyArchive = false
    private var cloudStarted = false
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var itemListener: ListenerRegistration?
    private var momentListener: ListenerRegistration?
    private var syncTask: Task<Void, Never>?
    private var hydrationTask: Task<Void, Never>?
    private var syncing = false
    private var dirtyItems: [UUID: UUID] = [:]
    private var dirtyMoments: [UUID: UUID] = [:]
    private var deletedItems: Set<UUID> = []
    private var deletedMoments: Set<UUID> = []
    private var uploadedNames: Set<String> = []
    private var pendingPhotoDeletes: Set<String> = []
    private var savedItems: [UUID: CollectibleItem] = [:]
    private var savedMoments: [UUID: Moment] = [:]
    private var legacyItems: [CollectibleItem] = []
    private var legacyMoments: [Moment] = []
    private var receivedItems = false
    private var receivedMoments = false

    private struct AccountCache: Codable {
        var items: [CollectibleItem]
        var moments: [Moment]
        var dirtyItems: [UUID: UUID]
        var dirtyMoments: [UUID: UUID]
        var deletedItems: Set<UUID>
        var deletedMoments: Set<UUID>
        var uploadedNames: Set<String>
        var pendingPhotoDeletes: Set<String>
    }

    func startCloud() {
        guard !cloudStarted else { return }
        legacyItems = items
        legacyMoments = moments
        cloudStarted = true
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            Task { @MainActor in self?.switchAccount(to: uid) }
        }
    }

    private func switchAccount(to uid: String?) {
        guard accountUID != uid || savedItems.isEmpty else { return }
        if accountUID != nil { persistAccount() }
        syncTask?.cancel()
        hydrationTask?.cancel()
        hydrationTask = nil
        itemListener?.remove()
        momentListener?.remove()
        stopCatalog()
        syncing = false
        accountUID = uid
        ImageStore.switchAccount(to: uid)
        dirtyItems = [:]; dirtyMoments = [:]
        deletedItems = []; deletedMoments = []; uploadedNames = []; pendingPhotoDeletes = []
        pendingPurchase = nil
        cloudError = nil
        receivedItems = false; receivedMoments = false; cloudReady = false
        items = []; moments = []
        savedItems = [:]; savedMoments = [:]
        guard let uid else { cloudStatus = "Sign in to sync"; return }
        let digest = SHA256.hash(data: Data(uid.utf8)).map { String(format: "%02x", $0) }.joined()
        let directory = legacyURL.deletingLastPathComponent().appendingPathComponent("Accounts")
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { cloudError = error.localizedDescription }
        archiveURL = directory.appendingPathComponent(digest + ".json")
        if let data = try? Data(contentsOf: archiveURL),
           let cache = try? JSONDecoder().decode(AccountCache.self, from: data) {
            items = cache.items; moments = cache.moments
            dirtyItems = cache.dirtyItems; dirtyMoments = cache.dirtyMoments
            deletedItems = cache.deletedItems; deletedMoments = cache.deletedMoments
            uploadedNames = cache.uploadedNames
            pendingPhotoDeletes = cache.pendingPhotoDeletes
            cloudReady = true
        } else { items = seedItems }
        savedItems = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        savedMoments = Dictionary(uniqueKeysWithValues: moments.map { ($0.id, $0) })
        hasLegacyArchive = !UserDefaults.standard.bool(forKey: "mono.legacyImported") &&
            (legacyItems.contains(where: { $0.isUserCreated }) || !legacyMoments.isEmpty)
        cloudStatus = "Connecting…"
        startCatalog(uid: uid)
        let root = Firestore.firestore().collection("users").document(uid)
        itemListener = root.collection("items").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.accountUID == uid else { return }
                if let error { self.cloudError = error.localizedDescription; return }
                guard let snapshot else { return }
                self.receiveItems(snapshot.documents)
                self.receivedItems = true
                self.finishInitialLoad()
            }
        }
        momentListener = root.collection("moments").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.accountUID == uid else { return }
                if let error { self.cloudError = error.localizedDescription; return }
                guard let snapshot else { return }
                self.receiveMoments(snapshot.documents)
                self.receivedMoments = true
                self.finishInitialLoad()
            }
        }
    }

    private func finishInitialLoad() {
        if receivedItems && receivedMoments {
            cloudReady = true
            cloudStatus = dirtyItems.isEmpty && dirtyMoments.isEmpty ? "Up to date" : "Changes waiting to sync"
            persistAccount()
            retryCloudSync()
        }
    }

    private func receiveItems(_ documents: [QueryDocumentSnapshot]) {
        var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for doc in documents {
            guard let id = UUID(uuidString: doc.documentID), dirtyItems[id] == nil else { continue }
            if doc.data()["deleted"] as? Bool == true {
                byID.removeValue(forKey: id); deletedItems.insert(id)
            } else if let payload = doc.data()["payload"] as? String,
                      let data = payload.data(using: .utf8),
                      let value = try? JSONDecoder().decode(CollectibleItem.self, from: data), value.id == id,
                      value.imageFileName.map(Self.validPhotoName) ?? true {
                byID[id] = value; deletedItems.remove(id)
                if let name = value.imageFileName { uploadedNames.insert(name) }
            }
        }
        items = byID.values.sorted { ($0.addedOn ?? .distantPast) > ($1.addedOn ?? .distantPast) }
        savedItems = byID
        hydratePhotos()
    }

    private func receiveMoments(_ documents: [QueryDocumentSnapshot]) {
        var byID = Dictionary(uniqueKeysWithValues: moments.map { ($0.id, $0) })
        for doc in documents {
            guard let id = UUID(uuidString: doc.documentID), dirtyMoments[id] == nil else { continue }
            if doc.data()["deleted"] as? Bool == true {
                byID.removeValue(forKey: id); deletedMoments.insert(id)
            } else if let payload = doc.data()["payload"] as? String,
                      let data = payload.data(using: .utf8),
                      let value = try? JSONDecoder().decode(Moment.self, from: data), value.id == id,
                      value.photoFileNames.allSatisfy(Self.validPhotoName) {
                byID[id] = value; deletedMoments.remove(id)
                uploadedNames.formUnion(value.photoFileNames)
            }
        }
        moments = Array(byID.values)
        savedMoments = byID
        hydratePhotos()
    }

    private func recordLocalChanges() {
        guard accountUID != nil else { cloudError = "Sign in before saving."; return }
        let currentItems = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let currentMoments = Dictionary(uniqueKeysWithValues: moments.map { ($0.id, $0) })
        for id in Set(savedItems.keys).union(currentItems.keys) where savedItems[id] != currentItems[id] {
            dirtyItems[id] = UUID()
            if currentItems[id] == nil { deletedItems.insert(id) } else { deletedItems.remove(id) }
        }
        for id in Set(savedMoments.keys).union(currentMoments.keys) where savedMoments[id] != currentMoments[id] {
            dirtyMoments[id] = UUID()
            if currentMoments[id] == nil { deletedMoments.insert(id) } else { deletedMoments.remove(id) }
        }
        let oldPhotos = Set(savedItems.values.compactMap(\.imageFileName) + savedMoments.values.flatMap(\.photoFileNames))
        let newPhotos = Set(items.compactMap(\.imageFileName) + moments.flatMap(\.photoFileNames))
        pendingPhotoDeletes.formUnion(oldPhotos.subtracting(newPhotos))
        pendingPhotoDeletes.subtract(newPhotos)
        savedItems = currentItems; savedMoments = currentMoments
        persistAccount()
        retryCloudSync()
    }

    private func persistAccount() {
        guard accountUID != nil else { return }
        let cache = AccountCache(items: items, moments: moments, dirtyItems: dirtyItems,
            dirtyMoments: dirtyMoments, deletedItems: deletedItems,
            deletedMoments: deletedMoments, uploadedNames: uploadedNames, pendingPhotoDeletes: pendingPhotoDeletes)
        do { try JSONEncoder().encode(cache).write(to: archiveURL, options: .atomic) }
        catch { cloudError = "Could not save local changes: " + error.localizedDescription }
    }

    /// Explicitly imports the old, unowned archive into the current account.
    func importLegacyArchive() {
        guard cloudReady, hasLegacyArchive else { return }
        do {
            let photos = Set(legacyItems.filter(\.isUserCreated).compactMap(\.imageFileName)
                + legacyMoments.flatMap(\.photoFileNames))
            for name in photos {
                guard Self.validPhotoName(name) else { throw CloudFailure.message("Invalid legacy photo name") }
                try ImageStore.importLegacy(named: name)
            }
        } catch {
            cloudError = "Legacy import: " + error.localizedDescription
            return
        }
        let currentIDs = Set(items.map(\.id))
        let momentIDs = Set(moments.map(\.id))
        items.append(contentsOf: legacyItems.filter { $0.isUserCreated && !currentIDs.contains($0.id) })
        moments.append(contentsOf: legacyMoments.filter { !momentIDs.contains($0.id) })
        save()
        UserDefaults.standard.set(true, forKey: "mono.legacyImported")
        hasLegacyArchive = false
    }

    func retryCloudSync() {
        retryCatalogSync()
        guard let uid = accountUID, cloudReady, !syncing else { return }
        cloudError = nil
        hydratePhotos()
        guard !dirtyItems.isEmpty || !dirtyMoments.isEmpty || !pendingPhotoDeletes.isEmpty else { return }
        syncing = true
        cloudStatus = "Syncing…"
        cloudError = nil
        syncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let root = Firestore.firestore().collection("users").document(uid)
                while !self.dirtyItems.isEmpty || !self.dirtyMoments.isEmpty || !self.pendingPhotoDeletes.isEmpty {
                    try self.checkSession(uid)
                    if let (id, revision) = self.dirtyItems.first {
                        let item = self.items.first { $0.id == id }
                        var fields: [String: Any] = ["deleted": item == nil, "updatedAt": FieldValue.serverTimestamp()]
                        if var value = item {
                            if let data = value.imageData, value.imageFileName == nil {
                                guard let name = ImageStore.save(data) else { throw CloudFailure.message("Could not prepare image") }
                                value.imageFileName = name; value.imageData = nil
                                if let index = self.items.firstIndex(where: { $0.id == id }) { self.items[index] = value }
                            }
                            if let name = value.imageFileName { try await self.uploadPhoto(name, uid: uid) }
                            value.imageData = nil
                            let encoded = try JSONEncoder().encode(value)
                            guard encoded.count < 700_000 else { throw CloudFailure.message("Object or memory text exceeds the cloud record limit") }
                            fields["payload"] = String(decoding: encoded, as: UTF8.self)
                        }
                        try self.checkSession(uid)
                        try await root.collection("items").document(id.uuidString).setData(fields)
                        try self.checkSession(uid)
                        if self.dirtyItems[id] == revision { self.dirtyItems.removeValue(forKey: id) }
                    } else if let (id, revision) = self.dirtyMoments.first {
                        let value = self.moments.first { $0.id == id }
                        var fields: [String: Any] = ["deleted": value == nil, "updatedAt": FieldValue.serverTimestamp()]
                        if let value {
                            for name in value.photoFileNames { try await self.uploadPhoto(name, uid: uid) }
                            let encoded = try JSONEncoder().encode(value)
                            guard encoded.count < 700_000 else { throw CloudFailure.message("Object or memory text exceeds the cloud record limit") }
                            fields["payload"] = String(decoding: encoded, as: UTF8.self)
                        }
                        try self.checkSession(uid)
                        try await root.collection("moments").document(id.uuidString).setData(fields)
                        try self.checkSession(uid)
                        if self.dirtyMoments[id] == revision { self.dirtyMoments.removeValue(forKey: id) }
                    }
                    if self.dirtyItems.isEmpty && self.dirtyMoments.isEmpty,
                       let name = self.pendingPhotoDeletes.first {
                        let references = Set(self.items.compactMap(\.imageFileName) + self.moments.flatMap(\.photoFileNames))
                        if !references.contains(name) {
                            try self.checkSession(uid)
                            _ = try await CloudStorage.client.storage.from(CloudStorage.bucket).remove(paths: [uid + "/" + name])
                            try self.checkSession(uid)
                            self.uploadedNames.remove(name)
                        }
                        self.pendingPhotoDeletes.remove(name)
                    }
                    self.persistAccount()
                }
                self.savedItems = Dictionary(uniqueKeysWithValues: self.items.map { ($0.id, $0) })
                self.cloudStatus = "Up to date"
                self.syncing = false
            } catch {
                guard self.accountUID == uid else { return }
                self.syncing = false
                self.cloudStatus = "Changes saved on this device"
                self.cloudError = error.localizedDescription
                self.persistAccount()
            }
        }
    }

    private func checkSession(_ uid: String) throws {
        guard !Task.isCancelled, accountUID == uid, Auth.auth().currentUser?.uid == uid else {
            throw CancellationError()
        }
    }

    private static func validPhotoName(_ name: String) -> Bool {
        name.range(of: "^[A-Za-z0-9-]+\\.(jpg|jpeg|png|webp)$", options: .regularExpression) != nil
    }

    private func uploadPhoto(_ name: String, uid: String) async throws {
        try checkSession(uid)
        guard Self.validPhotoName(name) else { throw CloudFailure.message("Invalid image filename") }
        guard !uploadedNames.contains(name) else { return }
        let data = try Data(contentsOf: ImageStore.url(for: name))
        guard data.count <= 5 * 1024 * 1024 else { throw CloudFailure.message("Photo exceeds the 5 MB limit") }
        _ = try await CloudStorage.client.storage.from(CloudStorage.bucket).upload(
            uid + "/" + name, data: data,
            options: .init(contentType: "image/jpeg", upsert: true))
        try checkSession(uid)
        uploadedNames.insert(name)
    }

    private func hydratePhotos() {
        guard hydrationTask == nil, let uid = accountUID else { return }
        let names = Set(items.compactMap(\.imageFileName) + moments.flatMap(\.photoFileNames))
        hydrationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.accountUID == uid {
                    self.hydrationTask = nil
                    let current = Set(self.items.compactMap(\.imageFileName) + self.moments.flatMap(\.photoFileNames))
                    let newlyArrived = current.subtracting(names).filter {
                        !FileManager.default.fileExists(atPath: ImageStore.url(for: $0).path)
                    }
                    if !newlyArrived.isEmpty { self.hydratePhotos() }
                }
            }
            for name in names where !FileManager.default.fileExists(atPath: ImageStore.url(for: name).path) {
                do {
                    let data = try await CloudStorage.client.storage.from(CloudStorage.bucket).download(path: uid + "/" + name)
                    try self.checkSession(uid)
                    try data.write(to: ImageStore.url(for: name), options: .atomic)
                    self.objectWillChange.send()
                } catch {
                    guard self.accountUID == uid else { return }
                    self.cloudError = "Photo download: " + error.localizedDescription
                }
            }
        }
    }

    enum CloudFailure: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
    }

    @Published private(set) var collections = PersonalCollection.defaults
    @Published private(set) var catalogReady = false
    @Published private(set) var sampleChoiceMade = false
    @Published private(set) var sampleOfferEligible = false
    @Published var onboardingPreferredCollectionID: UUID?
    @Published private(set) var catalogError: String?
    @Published private(set) var catalogSyncing = false
    @Published private(set) var sampleUndo: [CollectibleItem] = []
    private var catalogListener: ListenerRegistration?
    private var setupListener: ListenerRegistration?
    private var catalogUID: String?
    private var collectionRevisions: [UUID: UUID] = [:]
    private var catalogTask: Task<Void, Never>?
    private var preparingSampleOfferUID: String?
    private var receivedCatalog = false
    private var receivedSetup = false

    private struct CatalogCache: Codable {
        var collections: [PersonalCollection]
        var pending: [UUID: UUID]
        var sampleChoiceMade: Bool
        var sampleOfferEligible: Bool?
    }

    var activeCollections: [PersonalCollection] { collections.filter { $0.deletedAt == nil } }
    var deletedCollections: [PersonalCollection] { collections.filter { $0.deletedAt != nil } }

    func personalCollection(id: UUID) -> PersonalCollection? { collections.first { $0.id == id } }

    func resolvedCollectionID(for item: CollectibleItem) -> UUID {
        item.collectionID ?? PersonalCollection.defaultID(for: item.category)
    }

    func items(in collectionID: UUID) -> [CollectibleItem] {
        activeItems.filter { resolvedCollectionID(for: $0) == collectionID }
    }

    var unfiledItems: [CollectibleItem] {
        let activeIDs = Set(activeCollections.map(\.id))
        return activeItems.filter { !activeIDs.contains(resolvedCollectionID(for: $0)) }
    }

    @discardableResult
    func createPersonalCollection(name: String, layout: CollectionCategory = .poster) throws -> PersonalCollection {
        guard catalogReady, catalogUID == accountUID, accountUID != nil else {
            throw CloudFailure.message("Wait for your collections to load before creating one.")
        }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80 else { throw CloudFailure.message("Use a collection name of 1 to 80 characters.") }
        let collection = PersonalCollection(id: UUID(), name: name, layout: layout)
        collections.append(collection)
        collectionRevisions[collection.id] = UUID()
        persistCatalog(); retryCatalogSync()
        return collection
    }

    func deletePersonalCollection(_ id: UUID) {
        guard catalogReady, let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].deletedAt = .now
        collectionRevisions[id] = UUID()
        persistCatalog(); retryCatalogSync()
    }

    func restorePersonalCollection(_ id: UUID) {
        guard catalogReady, let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].deletedAt = nil
        collectionRevisions[id] = UUID()
        persistCatalog(); retryCatalogSync()
    }

    func moveItem(_ itemID: UUID, to collectionID: UUID?) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if let collectionID, !activeCollections.contains(where: { $0.id == collectionID }) { return }
        // A reserved, non-visible shelf UUID represents intentionally unfiled objects.
        items[index].collectionID = collectionID ?? Self.unfiledCollectionID
        save()
    }

    static let unfiledCollectionID = UUID(uuidString: "CA110000-0000-4000-8000-FFFFFFFFFFFF")!

    private func catalogCacheKey(_ uid: String) -> String {
        "mono.catalog." + SHA256.hash(data: Data(uid.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func persistCatalog() {
        guard let uid = catalogUID else { return }
        let value = CatalogCache(collections: collections, pending: collectionRevisions,
            sampleChoiceMade: sampleChoiceMade, sampleOfferEligible: sampleOfferEligible)
        do { UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: catalogCacheKey(uid)) }
        catch { catalogError = error.localizedDescription }
    }

    private func stopCatalog() {
        catalogListener?.remove(); setupListener?.remove(); catalogTask?.cancel()
        catalogListener = nil; setupListener = nil; catalogTask = nil; catalogUID = nil
        collections = PersonalCollection.defaults; collectionRevisions = [:]
        catalogReady = false; sampleChoiceMade = false; sampleOfferEligible = false
        onboardingPreferredCollectionID = nil; catalogError = nil; catalogSyncing = false
        receivedCatalog = false; receivedSetup = false; sampleUndo = []
    }

    private func startCatalog(uid: String) {
        catalogUID = uid
        if let data = UserDefaults.standard.data(forKey: catalogCacheKey(uid)),
           let cache = try? JSONDecoder().decode(CatalogCache.self, from: data) {
            collections = cache.collections; collectionRevisions = cache.pending
            sampleChoiceMade = cache.sampleChoiceMade
            sampleOfferEligible = cache.sampleOfferEligible ?? false
            catalogReady = true
        }
        let root = Firestore.firestore().collection("users").document(uid)
        catalogListener = root.collection("collections").addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.catalogUID == uid else { return }
                if let error { self.catalogError = error.localizedDescription; return }
                guard let snapshot else { return }
                var values = Dictionary(uniqueKeysWithValues: self.collections.map { ($0.id, $0) })
                for doc in snapshot.documents {
                    guard let id = UUID(uuidString: doc.documentID), self.collectionRevisions[id] == nil,
                          let payload = doc.data()["payload"] as? String, let bytes = payload.data(using: .utf8),
                          let value = try? JSONDecoder().decode(PersonalCollection.self, from: bytes), value.id == id else { continue }
                    values[id] = value
                }
                self.collections = values.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                if !snapshot.metadata.isFromCache { self.receivedCatalog = true }
                self.finishCatalogLoad()
            }
        }
        setupListener = root.collection("settings").document("onboarding").addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.catalogUID == uid else { return }
                if let error { self.catalogError = error.localizedDescription; return }
                guard let snapshot else { return }
                if snapshot.data()?["sampleChoiceMade"] as? Bool == true { self.sampleChoiceMade = true }
                if let eligible = snapshot.data()?["sampleOfferEligible"] as? Bool {
                    self.sampleOfferEligible = eligible
                } else if !snapshot.metadata.isFromCache { self.sampleOfferEligible = false }
                if !snapshot.metadata.isFromCache { self.receivedSetup = true }
                self.finishCatalogLoad()
            }
        }
    }

    private func finishCatalogLoad() {
        if receivedCatalog && receivedSetup { catalogReady = true }
        persistCatalog()
        retryCatalogSync()
    }

    private func retryCatalogSync() {
        if let uid = catalogUID, UserDefaults.standard.bool(forKey: catalogCacheKey(uid) + ".newAccountOfferPending") {
            requestDefaultCleanupOfferForNewAccount()
        }
        guard let uid = catalogUID, catalogReady, !catalogSyncing, !collectionRevisions.isEmpty else { return }
        catalogSyncing = true; catalogError = nil
        catalogTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                while let (id, revision) = self.collectionRevisions.first {
                    try self.checkSession(uid)
                    guard let value = self.personalCollection(id: id) else { self.collectionRevisions.removeValue(forKey: id); continue }
                    let payload = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
                    try await Firestore.firestore().collection("users").document(uid).collection("collections").document(id.uuidString)
                        .setData(["payload": payload, "updatedAt": FieldValue.serverTimestamp()])
                    try self.checkSession(uid)
                    if self.collectionRevisions[id] == revision { self.collectionRevisions.removeValue(forKey: id) }
                    self.persistCatalog()
                }
                self.catalogSyncing = false
            } catch {
                guard self.catalogUID == uid else { return }
                self.catalogSyncing = false; self.catalogError = "Collection changes are saved here; cloud sync is pending. " + error.localizedDescription
            }
        }
    }

    var defaultCleanupOffered: Bool { catalogReady && sampleOfferEligible && !sampleChoiceMade }

    /// Called by the new-account registration flow only. Returning logins never re-enable this offer.
    func requestDefaultCleanupOfferForNewAccount() {
        guard let uid = Auth.auth().currentUser?.uid, preparingSampleOfferUID != uid else { return }
        let pendingKey = catalogCacheKey(uid) + ".newAccountOfferPending"
        UserDefaults.standard.set(true, forKey: pendingKey)
        preparingSampleOfferUID = uid
        Task { @MainActor in
            defer { if self.preparingSampleOfferUID == uid { self.preparingSampleOfferUID = nil } }
            do {
                try await Firestore.firestore().collection("users").document(uid).collection("settings").document("onboarding")
                    .setData(["sampleOfferEligible": true], merge: true)
                UserDefaults.standard.removeObject(forKey: pendingKey)
            } catch {
                if self.accountUID == uid { self.catalogError = "Could not prepare the first-time sample choice. " + error.localizedDescription }
            }
        }
    }

    var defaultExampleCount: Int {
        let ids = Set(seedItems.map(\.id))
        return items.filter { ids.contains($0.id) && !$0.isUserCreated }.count
    }

    /// One account-wide decision, committed atomically with any sample tombstones.
    /// Transactions fail offline rather than silently repeating a one-time decision on another device.
    func completeSampleChoice(remove: Bool) async throws {
        guard let uid = accountUID, defaultCleanupOffered else { throw CloudFailure.message("This first-time option is not available for this account.") }
        let seedIDs = Set(seedItems.map(\.id))
        let examples = items.filter { seedIDs.contains($0.id) && !$0.isUserCreated }
        guard Set(examples.map(\.id)).isDisjoint(with: Set(dirtyItems.keys)) else {
            throw CloudFailure.message("Wait for sample-object edits to finish syncing, then try again.")
        }
        let setup = Firestore.firestore().collection("users").document(uid).collection("settings").document("onboarding")
        let targets = remove ? examples : []
        let records = try targets.map { item in
            (item.id, String(decoding: try JSONEncoder().encode(item), as: UTF8.self))
        }
        let db = Firestore.firestore()
        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let existing = try transaction.getDocument(setup)
                if existing.data()?["sampleChoiceMade"] as? Bool == true {
                    return ["applied": false, "removed": [String]()] as [String: Any]
                }
                guard existing.data()?["sampleOfferEligible"] as? Bool == true else {
                    throw NSError(domain: "MONO.Onboarding", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "This option is only available after new-account registration."])
                }
                // Read every target before issuing any writes (Firestore transaction requirement).
                let refs = records.map { db.collection("users").document(uid).collection("items").document($0.0.uuidString) }
                let documents = try refs.map { try transaction.getDocument($0) }
                var removedPayloads: [String] = []
                for index in records.indices {
                    if documents[index].data()?["deleted"] as? Bool == true { continue }
                    var payload = records[index].1
                    if let old = documents[index].data()?["payload"] as? String {
                        guard let bytes = old.data(using: .utf8),
                              let current = try? JSONDecoder().decode(CollectibleItem.self, from: bytes),
                              current.id == records[index].0, !current.isUserCreated else { continue }
                        payload = old
                    }
                    removedPayloads.append(payload)
                    transaction.setData(["deleted": true, "payload": payload, "updatedAt": FieldValue.serverTimestamp()], forDocument: refs[index])
                }
                transaction.setData(["sampleChoiceMade": true, "removedExamples": remove,
                    "updatedAt": FieldValue.serverTimestamp()], forDocument: setup, merge: true)
                return ["applied": true, "removed": removedPayloads] as [String: Any]
            } catch { errorPointer?.pointee = error as NSError; return nil }
        }
        try checkSession(uid)
        sampleChoiceMade = true
        if let outcome = result as? [String: Any], outcome["applied"] as? Bool == true && remove {
            sampleUndo = (outcome["removed"] as? [String] ?? []).compactMap {
                guard let bytes = $0.data(using: .utf8) else { return nil }
                return try? JSONDecoder().decode(CollectibleItem.self, from: bytes)
            }
            let ids = Set(sampleUndo.map(\.id))
            items.removeAll { ids.contains($0.id) }
            deletedItems.formUnion(ids)
            savedItems = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            persistAccount()
        }
        persistCatalog()
    }

    func undoSampleRemoval() {
        guard !sampleUndo.isEmpty else { return }
        let current = Set(items.map(\.id))
        items.append(contentsOf: sampleUndo.filter { !current.contains($0.id) })
        sampleUndo = []
        save()
    }

    func dismissSampleUndo() { sampleUndo = [] }

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
        if cloudStarted {
            recordLocalChanges()
            return
        }
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
