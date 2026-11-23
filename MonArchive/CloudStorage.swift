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
