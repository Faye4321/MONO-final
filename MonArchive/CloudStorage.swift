import Foundation
import FirebaseAuth
import Supabase
import FirebaseFirestore
import CryptoKit

enum CloudStorage {
    static let bucket = "collectible-images"
    static let projectURL = URL(string: "https://etkucvnppsvgpqytlhwe.supabase.co")!

    /// The storage host, for error messages.
    static var hostDescription: String { projectURL.host ?? projectURL.absoluteString }

    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: "sb_publishable_gcvtomO0PrDmrIRWtfFxJg_UutZyfJp",
        options: SupabaseClientOptions(
            auth: .init(
                accessToken: {
                    guard let user = FirebaseAuth.Auth.auth().currentUser else {
                        return nil
                    }

                    return try await user.getIDToken()
                }
            )
        )
    )
}


import SwiftUI

/// Profile ▸ Cloud & shared collections. Sits at the bottom of Profile,
/// collapsed to a one-line status; details, retry and Join collection are
/// inside. Sign out lives in Settings. (Chloe's P05–P09.)
struct CloudAccountPanel: View {
    @EnvironmentObject private var store: CollectionStore
    @EnvironmentObject private var socialStore: SocialStore
    @EnvironmentObject private var profileStore: CloudProfileStore
    @State private var expanded = false
    @State private var invitation = ""
    @State private var joinMessage: String?
    @State private var joinFailed = false
    @State private var joining = false
    @State private var retrying = false
    @State private var confirmImport = false

    /// Overall state: profile and shared-collection errors count as failures.
    private var summary: CollectionStore.SyncSummary {
        if profileStore.isSaving || socialStore.cloudBusy { return .syncing }
        let base = store.syncSummary
        if base == .upToDate, profileStore.errorMessage != nil || socialStore.cloudError != nil { return .failed }
        return base
    }

    private var summaryColor: Color {
        switch summary {
        case .upToDate: Color.green
        case .syncing: ArchiveTheme.catalogGray
        default: ArchiveTheme.collectedRed
        }
    }

    /// Technical details, shown only when the panel is open.
    private var problems: [String] {
        var list: [String] = []
        if let error = store.cloudError { list.append(error) }
        if let error = store.catalogError { list.append(error) }
        if let error = profileStore.errorMessage { list.append(error) }
        if let error = socialStore.cloudError { list.append(error) }
        if let reason = store.photoFailures.values.first { list.append(reason) }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "icloud")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ArchiveTheme.ink)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CLOUD & SHARED COLLECTIONS")
                            .font(ArchiveTheme.label(10))
                            .tracking(0.6)
                            .foregroundStyle(ArchiveTheme.ink)
                        HStack(spacing: 6) {
                            if summary == .syncing {
                                ProgressView().controlSize(.mini)
                            } else {
                                Circle().fill(summaryColor).frame(width: 6, height: 6)
                            }
                            Text(summary.title)
                                .font(ArchiveTheme.body(12))
                                .foregroundStyle(summary.isProblem ? ArchiveTheme.collectedRed : ArchiveTheme.catalogGray)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cloud and shared collections, \(summary.title)")
            .accessibilityHint(expanded ? "Hides details" : "Shows sync details and Join collection")

            if expanded { details.padding(.top, 14) }
        }
        .padding(16)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        .padding(.top, 26)
        .confirmationDialog("Import this device's old collection into the signed-in account?",
                            isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Import into this account") { store.importLegacyArchive() }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(FirebaseAuth.Auth.auth().currentUser?.email ?? "Not signed in")
                .font(ArchiveTheme.body(12))
                .foregroundStyle(ArchiveTheme.catalogGray)

            if case .photosPending(let count) = summary {
                Text("Your objects and memories are synced. \(count == 1 ? "1 photo" : "\(count) photos") couldn't be downloaded to this phone yet; the ones already here are kept.")
                    .font(ArchiveTheme.body(12))
                    .foregroundStyle(ArchiveTheme.ink)
            }

            if !problems.isEmpty {
                DisclosureGroup("Details") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(problems, id: \.self) { line in
                            Text(line).font(.caption2).foregroundStyle(ArchiveTheme.catalogGray)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.top, 6)
                }
                .font(ArchiveTheme.body(12))
                .tint(ArchiveTheme.ink)
            }

            if summary.isProblem {
                Button {
                    retry()
                } label: {
                    Label(retrying ? "Retrying…" : "Retry sync", systemImage: "arrow.clockwise")
                        .font(ArchiveTheme.label(11))
                }
                .disabled(retrying || summary == .syncing)
            }

            if store.hasLegacyArchive {
                Button("Import collections from before this update") { confirmImport = true }
                    .font(ArchiveTheme.body(13))
            }

            Divider()

            Text("JOIN A SHARED COLLECTION")
                .font(ArchiveTheme.label(10))
                .tracking(0.6)
                .foregroundStyle(ArchiveTheme.catalogGray)
            TextField("Paste an invitation link or code", text: $invitation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(ArchiveTheme.body(13))
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: invitation) { _, _ in joinMessage = nil }
            Button {
                join()
            } label: {
                Text(joining ? "Joining…" : "Join collection")
                    .font(ArchiveTheme.label(11))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(ArchiveTheme.collectedRed.opacity(canJoin ? 1 : 0.4), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canJoin)
            if let joinMessage {
                Text(joinMessage)
                    .font(ArchiveTheme.body(12))
                    .foregroundStyle(joinFailed ? ArchiveTheme.collectedRed : Color.green)
            }
        }
    }

    private var canJoin: Bool {
        !joining && !invitation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func retry() {
        retrying = true
        store.retryCloudSync()
        profileStore.retry()
        socialStore.cloudError = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            retrying = false
        }
    }

    private func join() {
        joining = true
        joinMessage = nil
        Task { @MainActor in
            defer { joining = false }
            do {
                try await socialStore.joinCollection(invitation: invitation)
                invitation = ""
                joinFailed = false
                joinMessage = "Joined. It's in Shared Collections above."
            } catch {
                joinFailed = true
                joinMessage = error.localizedDescription
            }
        }
    }
}

/// Account-owned profile data shared by Profile and registration.
struct CloudUserProfile: Codable, Equatable {
    var name = "Collector"
    var handle = ""
    var location = ""
    var bio = ""

    func validated() throws -> CloudUserProfile {
        var value = self
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.handle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        value.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        value.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.name.isEmpty, value.name.count <= 80,
              value.handle.count <= 40, value.location.count <= 120, value.bio.count <= 2000 else {
            throw CollectionStore.CloudFailure.message("Enter a name (up to 80 characters), handle (40), location (120), and bio (2000).")
        }
        return value
    }
}

@MainActor
final class CloudProfileStore: ObservableObject {
    @Published private(set) var profile = CloudUserProfile()
    @Published private(set) var isReady = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    private var uid: String?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var listener: ListenerRegistration?
    private var pending: PendingProfile?
    private var started = false

    private struct PendingProfile: Codable {
        var profile: CloudUserProfile
        var revision: UUID
    }

    func startCloud() {
        guard !started else { return }
        started = true
        authHandle = FirebaseAuth.Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            Task { @MainActor in self?.activate(uid) }
        }
    }

    private func key(_ kind: String, uid: String) -> String {
        let hash = SHA256.hash(data: Data(uid.utf8)).map { String(format: "%02x", $0) }.joined()
        return "mono.cloudProfile." + kind + "." + hash
    }

    private func cache(_ value: CloudUserProfile, uid: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key("cache", uid: uid))
        }
    }

    private func activate(_ nextUID: String?) {
        guard uid != nextUID || !isReady else { return }
        listener?.remove()
        uid = nextUID
        pending = nil
        profile = CloudUserProfile()
        isReady = false; isSaving = false; errorMessage = nil
        guard let uid = nextUID else { return }
        // Never import the global profile.name key: it may belong to another account.
        if let data = UserDefaults.standard.data(forKey: key("cache", uid: uid)),
           let value = try? JSONDecoder().decode(CloudUserProfile.self, from: data) {
            profile = value; isReady = true
        } else {
            profile.name = FirebaseAuth.Auth.auth().currentUser?.displayName
                ?? FirebaseAuth.Auth.auth().currentUser?.email?.components(separatedBy: "@").first
                ?? "Collector"
        }
        if let data = UserDefaults.standard.data(forKey: key("pending", uid: uid)),
           let value = try? JSONDecoder().decode(PendingProfile.self, from: data) {
            pending = value; profile = value.profile; isReady = true
        }
        listener = Firestore.firestore().collection("users").document(uid)
            .collection("profile").document("main")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.uid == uid else { return }
                    if let error { self.errorMessage = "Profile sync: " + error.localizedDescription; return }
                    guard let snapshot else { return }
                    if self.pending != nil {
                        self.isReady = true
                        self.retry()
                        return
                    }
                    if let data = snapshot.data(),
                       let name = data["name"] as? String {
                        self.profile = CloudUserProfile(name: name, handle: data["handle"] as? String ?? "",
                            location: data["location"] as? String ?? "", bio: data["bio"] as? String ?? "")
                        self.cache(self.profile, uid: uid)
                        self.isReady = true
                        self.errorMessage = nil
                    } else if !snapshot.metadata.isFromCache {
                        // Existing pre-update accounts have no profile document yet.
                        // Show an account-specific fallback until the user explicitly saves.
                        self.isReady = true
                    }
                }
            }
    }

    /// Points the store at the signed-in account right away, without waiting
    /// for the auth listener (used straight after sign-up).
    func activateCurrentUserIfNeeded() {
        guard let current = FirebaseAuth.Auth.auth().currentUser?.uid, uid != current else { return }
        activate(current)
    }

    /// Called only for a newly registered account, not a returning login.
    func registerName(_ name: String) {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        activateCurrentUserIfNeeded()
        var value = profile
        value.name = name
        Task { @MainActor in
            do { try await save(value) }
            catch { if self.uid == uid { self.errorMessage = error.localizedDescription } }
        }
    }

    /// Saves account-owned data. Failures retain a durable per-account pending edit.
    func save(_ draft: CloudUserProfile) async throws {
        let value = try draft.validated()
        guard let uid, FirebaseAuth.Auth.auth().currentUser?.uid == uid else {
            throw CollectionStore.CloudFailure.message("Sign in before editing your profile.")
        }
        guard !isSaving else { throw CollectionStore.CloudFailure.message("Your profile is still saving. Please wait.") }
        let edit = PendingProfile(profile: value, revision: UUID())
        let encoded = try JSONEncoder().encode(edit)
        UserDefaults.standard.set(encoded, forKey: key("pending", uid: uid))
        pending = edit; profile = value; isReady = true
        cache(value, uid: uid)
        try await flush(edit, uid: uid)
    }

    private func flush(_ edit: PendingProfile, uid: String) async throws {
        guard self.uid == uid, FirebaseAuth.Auth.auth().currentUser?.uid == uid else { throw CancellationError() }
        guard pending?.revision == edit.revision, !isSaving else { return }
        isSaving = true; errorMessage = nil
        defer { if self.uid == uid { isSaving = false } }
        do {
            try await Firestore.firestore().collection("users").document(uid).collection("profile").document("main").setData([
                "name": edit.profile.name, "handle": edit.profile.handle,
                "location": edit.profile.location, "bio": edit.profile.bio,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            guard self.uid == uid else { throw CancellationError() }
            if pending?.revision == edit.revision {
                pending = nil
                UserDefaults.standard.removeObject(forKey: key("pending", uid: uid))
                cache(edit.profile, uid: uid)
            }
        } catch {
            if self.uid == uid { errorMessage = "Profile saved on this device; cloud sync is pending. " + error.localizedDescription }
            throw error
        }
    }

    func retry() {
        guard !isSaving, let uid, let edit = pending else { return }
        Task { @MainActor in
            do { try await flush(edit, uid: uid) }
            catch { /* errorMessage is exposed to the existing Cloud panel. */ }
        }
    }
}

// MARK: - Account data that used to live only on this device

/// Which account the device-only copy of a feature belongs to. Local copies
/// are uploaded only to the account that made them; a different account
/// signing in starts from its own cloud copy instead.
enum AccountLocalData {
    private static func key(_ feature: String) -> String { "mono.localOwner." + feature }

    /// True if the local copy is this account's, or predates accounts.
    static func belongs(to uid: String, _ feature: String) -> Bool {
        let owner = UserDefaults.standard.string(forKey: key(feature))
        return owner == nil || owner == uid
    }

    static func claim(_ uid: String, _ feature: String) {
        UserDefaults.standard.set(uid, forKey: key(feature))
    }
}

/// Collecting interests, default visibility and each collection's
/// visibility, kept in users/{uid}/settings/preferences. The app still reads
/// them from UserDefaults; this mirrors those keys both ways.
@MainActor
final class AccountPreferencesSync {
    static let shared = AccountPreferencesSync()

    struct Values: Equatable {
        var collects: String
        var defaultVisibility: String
        var visibility: [String: String]

        static let empty = Values(collects: "", defaultVisibility: CollectionVisibility.isPrivate.rawValue, visibility: [:])
    }

    private static let visibilityKey = "profile.collectionVisibility"
    private var uid: String?
    private var received = false
    private var applying = false
    private var lastSynced: Values?
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var defaultsObserver: NSObjectProtocol?

    func start() {
        guard authHandle == nil else { return }
        authHandle = FirebaseAuth.Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            Task { @MainActor in self?.activate(uid) }
        }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.pushIfChanged() }
        }
    }

    private func document(_ uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid).collection("settings").document("preferences")
    }

    static var local: Values {
        let defaults = UserDefaults.standard
        let visibility = defaults.data(forKey: visibilityKey)
            .flatMap { try? JSONDecoder().decode([String: CollectionVisibility].self, from: $0) } ?? [:]
        return Values(
            collects: defaults.string(forKey: CollectingPreferences.storageKey) ?? "",
            defaultVisibility: defaults.string(forKey: ProfileStore.defaultVisibilityKey) ?? CollectionVisibility.isPrivate.rawValue,
            visibility: visibility.mapValues(\.rawValue)
        )
    }

    private func writeLocal(_ values: Values) {
        applying = true
        defer { applying = false }
        let defaults = UserDefaults.standard
        let visibility = values.visibility.compactMapValues(CollectionVisibility.init(rawValue:))
        defaults.set(values.collects, forKey: CollectingPreferences.storageKey)
        defaults.set(values.defaultVisibility, forKey: ProfileStore.defaultVisibilityKey)
        defaults.set(try? JSONEncoder().encode(visibility), forKey: Self.visibilityKey)
        ProfileStore.shared.applySyncedVisibility(
            visibility, defaultVisibility: CollectionVisibility(rawValue: values.defaultVisibility) ?? .isPrivate)
    }

    private func activate(_ newUID: String?) {
        guard newUID != uid else { return }
        listener?.remove()
        listener = nil
        uid = newUID
        received = false
        lastSynced = nil
        guard let newUID else { return }
        Task { await ProfileStore.shared.reload() }  // the avatar belongs to the account too
        listener = document(newUID).addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.uid == newUID, error == nil, let snapshot else { return }
                if let data = snapshot.data() {
                    let values = Values(
                        collects: data["collects"] as? String ?? "",
                        defaultVisibility: data["defaultVisibility"] as? String ?? CollectionVisibility.isPrivate.rawValue,
                        visibility: data["collectionVisibility"] as? [String: String] ?? [:]
                    )
                    self.received = true
                    AccountLocalData.claim(newUID, "preferences")
                    self.lastSynced = values
                    if values != Self.local { self.writeLocal(values) }
                } else if !snapshot.metadata.isFromCache, !self.received {
                    // Nothing in the cloud yet: keep this device's settings if
                    // they're this account's (and upload them), otherwise start fresh.
                    self.received = true
                    if !AccountLocalData.belongs(to: newUID, "preferences") { self.writeLocal(.empty) }
                    AccountLocalData.claim(newUID, "preferences")
                    self.pushIfChanged()
                }
            }
        }
    }

    private func pushIfChanged() {
        guard !applying, received, let uid else { return }
        let values = Self.local
        guard values != lastSynced else { return }
        lastSynced = values
        // Firestore queues the write while offline and sends it later.
        document(uid).setData([
            "collects": values.collects,
            "defaultVisibility": values.defaultVisibility,
            "collectionVisibility": values.visibility,
            "updatedAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            guard error != nil else { return }
            Task { @MainActor in if self?.uid == uid { self?.lastSynced = nil } }
        }
    }
}

/// The profile photo: a small copy in users/{uid}/settings/avatar (private,
/// for the user's other devices) and in profiles/{uid}.avatar (friends).
enum AvatarCloud {
    enum Remote { case found(name: String, data: Data), none, unavailable }

    static let maxBytes = 150_000

    /// A square-ish 320 px JPEG small enough for a Firestore field.
    static func thumbnail(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let side: CGFloat = 320
        let scale = min(1, side / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        for quality in [0.75, 0.5, 0.3] {
            if let jpeg = resized.jpegData(compressionQuality: quality), jpeg.count <= maxBytes { return jpeg }
        }
        return nil
    }

    private static func privateDocument(_ uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid).collection("settings").document("avatar")
    }

    static func fetch(uid: String) async -> Remote {
        do {
            let snapshot = try await privateDocument(uid).getDocument(source: .server)
            guard let data = snapshot.data()?["data"] as? Data,
                  let name = snapshot.data()?["name"] as? String else { return .none }
            return .found(name: name, data: data)
        } catch {
            return .unavailable
        }
    }

    /// Uploads the photo stored locally as `name`, or removes it when nil.
    static func save(name: String?, uid: String) {
        guard let name else {
            privateDocument(uid).delete()
            publishPublic(nil, uid: uid)
            return
        }
        guard let original = try? Data(contentsOf: ImageStore.url(for: name)),
              let small = thumbnail(original) else { return }
        privateDocument(uid).setData(["name": name, "data": small, "updatedAt": FieldValue.serverTimestamp()])
        publishPublic(small, uid: uid)
    }

    /// Friends see this one. Skipped silently when the user has no public profile.
    static func publishPublic(_ data: Data?, uid: String) {
        Firestore.firestore().collection("profiles").document(uid)
            .updateData(["avatar": data ?? FieldValue.delete()]) { _ in }
    }
}

/// Explore wishlist in users/{uid}/wishlist/{pickID}. Falls back to the
/// on-device file when nobody is signed in.
@MainActor
final class CloudExploreWishlist: ExploreWishlistProviding {
    private let local = LocalExploreWishlist()

    private func collection(_ uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("wishlist")
    }

    func fetchSavedPicks() async throws -> [SavedPick] {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return try await local.fetchSavedPicks() }
        let snapshot = try await collection(uid).getDocuments()
        var picks = snapshot.documents.compactMap { doc -> SavedPick? in
            guard let payload = doc.data()["payload"] as? String else { return nil }
            return try? JSONDecoder().decode(SavedPick.self, from: Data(payload.utf8))
        }
        // First sign-in after this update: bring this device's saves along.
        if picks.isEmpty, !snapshot.metadata.isFromCache, AccountLocalData.belongs(to: uid, "wishlist") {
            let saved = (try? await local.fetchSavedPicks()) ?? []
            for pick in saved { write(pick, uid: uid) }
            picks = saved
        }
        AccountLocalData.claim(uid, "wishlist")
        return picks.sorted { $0.savedAt > $1.savedAt }
    }

    func setSaved(_ pick: ShopPick, saved: Bool) async throws {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else {
            return try await local.setSaved(pick, saved: saved)
        }
        let document = collection(uid).document(pick.id)
        if saved {
            if try await document.getDocument().exists { return }  // keep the original savedAt
            try await document.setData(Self.fields(SavedPick(pick: pick, savedAt: .now)))
        } else {
            try await document.delete()
        }
    }

    private func write(_ pick: SavedPick, uid: String) {
        collection(uid).document(pick.id).setData(Self.fields(pick))
    }

    private static func fields(_ pick: SavedPick) -> [String: Any] {
        let payload = (try? JSONEncoder().encode(pick)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        return ["payload": payload, "savedAt": Timestamp(date: pick.savedAt)]
    }
}

/// Lab collages: the project (without pictures) in users/{uid}/labProjects,
/// and each picture once, by content hash, in Supabase under {uid}/lab/.
@MainActor
final class LabCloudSync {
    static let shared = LabCloudSync()
    private var uploaded: Set<String> = []

    private func collection(_ uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("labProjects")
    }

    private static func path(for data: Data, uid: String) -> (path: String, type: String) {
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let isPNG = data.starts(with: [0x89, 0x50, 0x4E, 0x47])
        return (uid + "/lab/" + hash + (isPNG ? ".png" : ".jpg"), isPNG ? "image/png" : "image/jpeg")
    }

    private func upload(_ data: Data, uid: String) async throws -> String {
        let target = Self.path(for: data, uid: uid)
        guard !uploaded.contains(target.path) else { return target.path }
        guard data.count <= 5 * 1024 * 1024 else {
            throw CollectionStore.CloudFailure.message("A Lab picture is larger than 5 MB")
        }
        _ = try await CloudStorage.client.storage.from(CloudStorage.bucket).upload(
            target.path, data: data, options: .init(contentType: target.type, upsert: true))
        uploaded.insert(target.path)
        return target.path
    }

    /// Saves one project to the account. Runs in the background; a failure
    /// leaves the local copy, and the next save or pull tries again.
    func push(_ project: LabProject) {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        Task { @MainActor in try? await self.upload(project, uid: uid) }
    }

    private func upload(_ project: LabProject, uid: String) async throws {
        var stripped = project
        var images: [String: String] = [:]
        if let data = project.background.imageData {
            images["background"] = try await upload(data, uid: uid)
            stripped.background.imageData = nil
        }
        if let data = project.previewData {
            images["preview"] = try await upload(data, uid: uid)
            stripped.previewData = nil
        }
        for index in stripped.elements.indices {
            guard let data = stripped.elements[index].imageData else { continue }
            images["element." + stripped.elements[index].id.uuidString] = try await upload(data, uid: uid)
            stripped.elements[index].imageData = nil
        }
        let payload = try JSONEncoder().encode(stripped)
        guard payload.count < 700_000 else { throw CollectionStore.CloudFailure.message("Collage is too large to sync") }
        guard FirebaseAuth.Auth.auth().currentUser?.uid == uid else { return }
        try await collection(uid).document(project.id.uuidString).setData([
            "payload": String(decoding: payload, as: UTF8.self),
            "images": images,
            "updatedAt": Timestamp(date: project.updatedAt),
            "deleted": false
        ])
    }

    func delete(_ id: UUID) {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        collection(uid).document(id.uuidString).setData(["deleted": true, "updatedAt": Timestamp(date: .now)])
    }

    /// Merges the account's collages into this device's list. Returns true
    /// when the local list changed.
    func pull() async -> Bool {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return false }
        guard let snapshot = try? await collection(uid).getDocuments(source: .server) else { return false }
        let startedWith = LabDraftStore.load()
        var local = AccountLocalData.belongs(to: uid, "lab") ? startedWith : []
        var remoteIDs: Set<UUID> = []
        for doc in snapshot.documents {
            guard let id = UUID(uuidString: doc.documentID) else { continue }
            remoteIDs.insert(id)
            let data = doc.data()
            if data["deleted"] as? Bool == true {
                local.removeAll { $0.id == id }
                continue
            }
            guard let payload = data["payload"] as? String,
                  var project = try? JSONDecoder().decode(LabProject.self, from: Data(payload.utf8)) else { continue }
            if let existing = local.first(where: { $0.id == id }), existing.updatedAt >= project.updatedAt {
                if existing.updatedAt > project.updatedAt { push(existing) }
                continue
            }
            let images = data["images"] as? [String: String] ?? [:]
            func download(_ key: String) async -> Data? {
                guard let path = images[key] else { return nil }
                return try? await CloudStorage.client.storage.from(CloudStorage.bucket).download(path: path)
            }
            project.background.imageData = await download("background")
            project.previewData = await download("preview")
            for index in project.elements.indices {
                project.elements[index].imageData = await download("element." + project.elements[index].id.uuidString)
            }
            guard FirebaseAuth.Auth.auth().currentUser?.uid == uid else { return false }
            local.removeAll { $0.id == id }
            local.append(project)
        }
        // Collages made on this device before syncing existed.
        for project in local where !remoteIDs.contains(project.id) { push(project) }
        AccountLocalData.claim(uid, "lab")
        guard local != startedWith else { return false }
        LabDraftStore.replaceLocal(with: local)
        return true
    }
}

/// Public collections, readable by any signed-in collector:
/// profiles/{uid}/collections/{collectionID} { name, layout, count }
/// profiles/{uid}/collections/{collectionID}/items/{itemID} { payload, preview }
/// Only what changed is written; what's no longer public is deleted.
@MainActor
final class PublicCollectionPublisher {
    static let shared = PublicCollectionPublisher()

    private struct Published: Codable {
        var collections: [String: [String: String]] = [:]   // collectionID → itemID → signature
        var headers: [String: String] = [:]                  // collectionID → name|layout|count
    }

    private var running = false
    private var rerun = false
    private var latest: (uid: String, collections: [(PersonalCollection, [CollectibleItem])])?

    private func stateKey(_ uid: String) -> String { "mono.publicCollections." + uid }

    private func load(_ uid: String) -> Published {
        UserDefaults.standard.data(forKey: stateKey(uid))
            .flatMap { try? JSONDecoder().decode(Published.self, from: $0) } ?? Published()
    }

    private func save(_ state: Published, uid: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(state), forKey: stateKey(uid))
    }

    /// Call whenever objects, collections or visibility may have changed.
    func update(store: CollectionStore, profile: ProfileStore) {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid, store.accountUID == uid,
              store.cloudReady, store.catalogReady else { return }
        let collections = store.visibleCollections()
            .filter { profile.visibility(forCollection: $0) == .isPublic }
            .map { ($0, store.items(in: $0.id)) }
        latest = (uid, collections)
        guard !running else { rerun = true; return }
        running = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)  // let quick edits settle
            repeat {
                rerun = false
                if let latest { await self.publish(latest.collections, uid: latest.uid) }
            } while rerun
            running = false
        }
    }

    private static func payload(_ item: CollectibleItem) -> String? {
        var copy = item
        copy.imageData = nil
        copy.imageFileName = nil
        return (try? JSONEncoder().encode(copy)).map { String(decoding: $0, as: UTF8.self) }
    }

    static func preview(for item: CollectibleItem) -> Data? {
        guard let source = item.uploadedImage ?? item.imageName.flatMap({ UIImage(named: $0) }) else { return nil }
        let scale = min(1, 600 / max(source.size.width, source.size.height))
        let size = CGSize(width: max(1, source.size.width * scale), height: max(1, source.size.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        for quality in [0.6, 0.35, 0.15] {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= 180_000 { return data }
        }
        return nil
    }

    private func publish(_ collections: [(PersonalCollection, [CollectibleItem])], uid: String) async {
        var state = load(uid)
        let root = Firestore.firestore().collection("profiles").document(uid).collection("collections")
        let wanted = Set(collections.map { $0.0.id.uuidString })
        do {
            for (collection, items) in collections {
                let cid = collection.id.uuidString
                let header = "\(collection.name)|\(collection.layout.rawValue)|\(items.count)"
                if state.headers[cid] != header {
                    try await root.document(cid).setData([
                        "name": collection.name, "layout": collection.layout.rawValue,
                        "count": items.count, "updatedAt": FieldValue.serverTimestamp()
                    ])
                    state.headers[cid] = header
                    save(state, uid: uid)
                }
                var published = state.collections[cid] ?? [:]
                for item in items {
                    guard let payload = Self.payload(item) else { continue }
                    let signature = SHA256.hash(data: Data(payload.utf8)).map { String(format: "%02x", $0) }.joined()
                        + "|" + (item.imageFileName ?? item.imageName ?? "")
                    let iid = item.id.uuidString
                    guard published[iid] != signature else { continue }
                    var fields: [String: Any] = ["payload": payload, "updatedAt": FieldValue.serverTimestamp()]
                    if let preview = Self.preview(for: item) { fields["preview"] = preview }
                    try await root.document(cid).collection("items").document(iid).setData(fields)
                    published[iid] = signature
                    state.collections[cid] = published
                    save(state, uid: uid)
                }
                let current = Set(items.map(\.id.uuidString))
                for iid in published.keys where !current.contains(iid) {
                    try await root.document(cid).collection("items").document(iid).delete()
                    published.removeValue(forKey: iid)
                    state.collections[cid] = published
                    save(state, uid: uid)
                }
            }
            // No longer public (or deleted): remove it for everyone else.
            for cid in Set(state.headers.keys).union(state.collections.keys) where !wanted.contains(cid) {
                for iid in (state.collections[cid] ?? [:]).keys {
                    try await root.document(cid).collection("items").document(iid).delete()
                }
                try await root.document(cid).delete()
                state.collections.removeValue(forKey: cid)
                state.headers.removeValue(forKey: cid)
                save(state, uid: uid)
            }
        } catch {
            // Offline or rules not published yet: the next change tries again.
        }
    }

    /// A public collection someone else published.
    static func items(ownerUID: String, collectionID: String) async throws -> [CollectibleItem] {
        let snapshot = try await Firestore.firestore().collection("profiles").document(ownerUID)
            .collection("collections").document(collectionID).collection("items").getDocuments()
        return snapshot.documents.compactMap { doc -> CollectibleItem? in
            guard let payload = doc.data()["payload"] as? String,
                  var item = try? JSONDecoder().decode(CollectibleItem.self, from: Data(payload.utf8)) else { return nil }
            item.imageData = doc.data()["preview"] as? Data
            return item
        }
        .sorted { ($0.addedOn ?? .distantPast) > ($1.addedOn ?? .distantPast) }
    }
}
