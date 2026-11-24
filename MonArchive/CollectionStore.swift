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
    /// The 40 demo objects earlier builds shipped with. Kept only so old
    /// caches and cloud records that still hold them get cleaned out.
    private static let retiredDemoIDs: Set<UUID> = Set([
        "C7EB487F-EBDE-57EB-A5FC-A8CBFAD4C45B",
        "182F990F-6AB5-5FF8-BBA5-A260187F35EF",
        "5F04EAC7-BE60-5DA4-B7AB-52B4EBC5B446",
        "0A26BC6E-9F87-53E7-83F5-F444A09D0569",
        "1BFE5112-7C8D-55AF-A723-70B47A2F6155",
        "5F08E9C1-C9E3-52D7-9129-50E2DB136D6B",
        "CA858FB2-B30F-5D80-9A53-DF9133358412",
        "05633097-0353-597B-92E5-28CB74364566",
        "593D360B-0C59-5DC1-9560-98C4F8F9EB11",
        "610EB668-621A-572E-8E62-BD9901FE7C54",
        "5EDF3870-9517-55F9-8E22-F201C34C9267",
        "CE611705-4AD9-5B54-9389-D3DDCA094334",
        "D8FAF207-0B43-5A23-BFCA-EBD538FCB14E",
        "56452ECA-E5DD-547E-B010-F62E7FBB1E8B",
        "547846F9-4E81-5389-88FA-FCDB5127289F",
        "58F3CDE6-9E1D-5F11-911C-C87B1F59C261",
        "0CB0643A-68BF-5459-8889-7B48ECAB25FD",
        "3AA49C75-EBF8-503C-A6EB-8E51AA4417CD",
        "43692834-8CCC-55E5-96CC-03C0DBEA77E8",
        "A1570EAC-9EF2-5102-BE29-E391B13911A3",
        "7B89E12D-E43B-5518-B8EC-87429A6CDB84",
        "500AF233-5716-51C6-8FD7-BBD58FAFE354",
        "AFA6E2FD-B7E7-56A4-BF07-489B20A91DDC",
        "03A2B7F2-9764-5F3C-AF92-72EF00BA2871",
        "2E4F7381-2051-58CF-9749-F8170357E169",
        "709CD219-7AB6-557C-9BFF-4A4CB2912C49",
        "E13A3C10-0248-5D59-822E-E8A8EC38CF31",
        "ECB3C612-08F7-5E25-A965-76858CBE173F",
        "881E2E3E-4CE9-536B-8021-7B931AA9786F",
        "8B6158D2-FA60-5381-B676-6E70AAA75785",
        "F8A52676-7CB5-5ADD-8185-57E9FE7D78E2",
        "2469CD03-F725-5BB3-8314-D6617CAE1770",
        "ED277C60-87FD-513D-BA0C-9B3B19207766",
        "87892366-6A73-5A99-A44F-E17A0CAEE501",
        "E9367DCD-44B3-58D2-9033-5F846D0EC126",
        "D3693804-417C-55D4-B6AA-426A775DC1D8",
        "19D1A576-657F-5703-BEA6-8E5194CC30A9",
        "E34E7F0D-DCE3-5EAE-9501-C62A8F5EAEE3",
        "19B4F10F-78C5-5D33-BAA4-29F58A1FB311",
        "8CD237ED-038B-5C6C-90D4-B7DA89251671",
    ].compactMap(UUID.init(uuidString:)))

    private struct ArchiveFile: Codable {
        var version = 1
        var userItems: [CollectibleItem]
        // Seed objects the user has edited, stored in full.
        var seedOverrides: [CollectibleItem]
        var moments: [Moment]
        // Seed objects the user has deleted. Optional so older files decode.
        var deletedSeedIDs: [UUID]? = nil
    }

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        archiveURL = documents.appendingPathComponent("archive.json")
        legacyURL = documents.appendingPathComponent("uploaded-objects.json")

        // A new install starts empty: no demo objects.
        let archive = Self.loadArchive(from: archiveURL, legacyURL: legacyURL)
        items = archive.userItems.filter { !Self.retiredDemoIDs.contains($0.id) }
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
        photoFailures = [:]
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
        }
        // Older caches may still hold the retired demo objects.
        items.removeAll(where: isRetiredDemo)
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
                guard !isRetiredDemo(value) else { continue }
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
        guard !dirtyItems.isEmpty || !dirtyMoments.isEmpty || !pendingPhotoDeletes.isEmpty else {
            if cloudStatus != "Up to date" && !syncing { cloudStatus = "Up to date" }
            return
        }
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
                self.cloudError = Self.describePhotoError(error)
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

    /// Photos that couldn't be downloaded on this device. The local copy
    /// (if any) is never overwritten; they are retried by Retry sync.
    @Published private(set) var photoFailures: [String: String] = [:]
    @Published private(set) var photosSyncing = false

    /// One line for Profile ▸ Cloud: Syncing, Up to date, Some photos need
    /// syncing, or Sync failed. Never "Up to date" while something failed.
    var syncSummary: SyncSummary {
        if !cloudReady || syncing || photosSyncing { return .syncing }
        if cloudError != nil || catalogError != nil { return .failed }
        if !dirtyItems.isEmpty || !dirtyMoments.isEmpty || !collectionRevisions.isEmpty { return .waiting }
        if !photoFailures.isEmpty { return .photosPending(photoFailures.count) }
        return .upToDate
    }

    enum SyncSummary: Equatable {
        case syncing, upToDate, waiting, failed
        case photosPending(Int)

        var title: String {
            switch self {
            case .syncing: "Syncing…"
            case .upToDate: "Up to date"
            case .waiting: "Changes waiting to sync"
            case .failed: "Sync failed"
            case .photosPending(let count): count == 1 ? "1 photo needs syncing" : "\(count) photos need syncing"
            }
        }

        var isProblem: Bool {
            switch self {
            case .failed, .photosPending, .waiting: true
            default: false
            }
        }
    }

    private func hydratePhotos() {
        guard hydrationTask == nil, let uid = accountUID else { return }
        let names = Set(items.compactMap(\.imageFileName) + moments.flatMap(\.photoFileNames))
        // Forget failures for photos that are no longer referenced.
        photoFailures = photoFailures.filter { names.contains($0.key) }
        hydrationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.photosSyncing = true
            defer {
                if self.accountUID == uid {
                    self.photosSyncing = false
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
                    self.photoFailures.removeValue(forKey: name)
                    self.objectWillChange.send()
                } catch {
                    guard self.accountUID == uid else { return }
                    // Recorded per photo instead of as a general cloud error,
                    // so the rest of the account can still read "Up to date".
                    self.photoFailures[name] = Self.describePhotoError(error)
                }
            }
        }
    }

    /// Short, technical reason kept for the Cloud details view.
    private static func describePhotoError(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return "Photo server not found (\(CloudStorage.hostDescription)). Your changes are saved on this phone. The Supabase storage project may be paused or deleted — check it in the Supabase dashboard."
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut:
                return "No connection to the photo server."
            default: break
            }
        }
        return error.localizedDescription
    }

    enum CloudFailure: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
    }

    @Published private(set) var collections = PersonalCollection.defaults
    @Published private(set) var catalogReady = false
    @Published var onboardingPreferredCollectionID: UUID?
    @Published private(set) var catalogError: String?
    @Published private(set) var catalogSyncing = false
    private var catalogListener: ListenerRegistration?
    private var catalogUID: String?
    private var collectionRevisions: [UUID: UUID] = [:]
    private var catalogTask: Task<Void, Never>?
    private var receivedCatalog = false

    private struct CatalogCache: Codable {
        var collections: [PersonalCollection]
        var pending: [UUID: UUID]
    }

    var activeCollections: [PersonalCollection] { collections.filter { $0.deletedAt == nil } }

    /// What the user sees: their own collections, plus a built-in category
    /// shelf (Vinyl, BJD, Poster, Photocard) only once it holds something or
    /// they renamed it, so a new account starts with no pre-made collections.
    /// `including` keeps a picker's current choice listed.
    func visibleCollections(including extra: UUID? = nil) -> [PersonalCollection] {
        activeCollections.filter { collection in
            guard collection.id == PersonalCollection.defaultID(for: collection.layout) else { return true }
            return collection.id == extra || collection.name != collection.layout.title || !items(in: collection.id).isEmpty
        }
    }
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
        let value = CatalogCache(collections: collections, pending: collectionRevisions)
        do { UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: catalogCacheKey(uid)) }
        catch { catalogError = error.localizedDescription }
    }

    private func stopCatalog() {
        catalogListener?.remove(); catalogTask?.cancel()
        catalogListener = nil; catalogTask = nil; catalogUID = nil
        collections = PersonalCollection.defaults; collectionRevisions = [:]
        catalogReady = false
        onboardingPreferredCollectionID = nil; catalogError = nil; catalogSyncing = false
        receivedCatalog = false
    }

    private func startCatalog(uid: String) {
        catalogUID = uid
        if let data = UserDefaults.standard.data(forKey: catalogCacheKey(uid)),
           let cache = try? JSONDecoder().decode(CatalogCache.self, from: data) {
            collections = cache.collections; collectionRevisions = cache.pending
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
    }

    private func finishCatalogLoad() {
        if receivedCatalog { catalogReady = true }
        persistCatalog()
        retryCatalogSync()
    }

    private func retryCatalogSync() {
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

    /// One of the retired demo objects (never something the user made).
    private func isRetiredDemo(_ item: CollectibleItem) -> Bool {
        !item.isUserCreated && Self.retiredDemoIDs.contains(item.id)
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
        let existing = Set(items.map(\.id))
        let kept = moments.filter { moment in
            moment.itemIDs.contains(where: existing.contains)
                || !moment.photoFileNames.isEmpty || !moment.note.isEmpty
        }
        return CalendarSource(moments: kept + added, addedEntryIDs: Set(added.map(\.id)))
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
        let archive = ArchiveFile(userItems: items, seedOverrides: [], moments: moments)

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
