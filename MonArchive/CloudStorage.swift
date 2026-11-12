import Foundation
import FirebaseAuth
import Supabase
import FirebaseFirestore
import CryptoKit

enum CloudStorage {
    static let bucket = "collectible-images"

    static let client = SupabaseClient(
        supabaseURL: URL(
            string: "https://etkucvnppsvgpqytlhwe.supabase.co"
        )!,
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

struct CloudAccountPanel: View {
    @EnvironmentObject private var store: CollectionStore
    @EnvironmentObject private var socialStore: SocialStore
    @EnvironmentObject private var profileStore: CloudProfileStore
    @State private var invitation = ""
    @State private var message: String?
    @State private var joining = false
    @State private var confirmImport = false

    var body: some View {
        DisclosureGroup("Cloud & shared collections") {
            VStack(alignment: .leading, spacing: 12) {
                Text(FirebaseAuth.Auth.auth().currentUser?.email ?? "Not signed in")
                    .font(.caption)
                    .foregroundStyle(ArchiveTheme.catalogGray)
                Text(store.cloudStatus)
                    .font(.caption)
                    .foregroundStyle(ArchiveTheme.ink)
                if profileStore.isSaving {
                    ProgressView("Saving profile…")
                        .foregroundStyle(ArchiveTheme.ink)
                }
                if let error = profileStore.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                if let error = store.cloudError { Text(error).font(.caption).foregroundStyle(.red) }
                if let error = socialStore.cloudError { Text(error).font(.caption).foregroundStyle(.red) }
                if socialStore.cloudBusy { ProgressView("Creating collection…") }
                Button("Retry sync") {
                    store.retryCloudSync()
                    profileStore.retry()
                }
                if store.hasLegacyArchive {
                    Button("Import collections from before this update") { confirmImport = true }
                }
                Divider()
                TextField("Paste a collection invitation link or code", text: $invitation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button(joining ? "Joining…" : "Join collection") {
                    joining = true
                    Task { @MainActor in
                        defer { joining = false }
                        do {
                            try await socialStore.joinCollection(invitation: invitation)
                            invitation = ""
                            message = "Joined. Your shared collection appears below."
                        } catch { message = error.localizedDescription }
                    }
                }
                .disabled(joining || invitation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Sign out", role: .destructive) {
                    do { try FirebaseAuth.Auth.auth().signOut() }
                    catch { message = error.localizedDescription }
                }
            }
            .padding(.top, 12)
            .font(.subheadline)
        }
        .environment(\.colorScheme, .light)
        .padding(16)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        .padding(.top, 16)
        .alert("Cloud", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
        .confirmationDialog("Import this device's old collection into the signed-in account?",
                            isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Import into this account") { store.importLegacyArchive() }
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

    /// Called only for a newly registered account, not a returning login.
    func registerName(_ name: String) {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        if self.uid != uid { activate(uid) }
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
