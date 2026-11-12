import Combine
import SwiftUI
import UIKit

// The Profile module's data layer.
//
// Screens only talk to `ProfileStore`. `ProfileStore` talks to a
// `ProfileServicing`. Today that is `LocalProfileService`, which keeps
// everything on this phone. When Fei's Firebase interface is ready, add a
// `FirebaseProfileService` that conforms to `ProfileServicing` and pass it
// to `ProfileStore.shared` — no screen needs to change.

// MARK: - Models

struct UserProfile: Codable, Equatable {
    var name: String = ""
    /// Stored without the leading "@", lowercased. See `HandleRules`.
    var handle: String = ""
    var location: String = ""
    var bio: String = ""
    var avatarFileName: String?
}

enum CollectionVisibility: String, Codable, CaseIterable, Identifiable {
    case isPublic = "public"
    case isPrivate = "private"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .isPublic: "Public"
        case .isPrivate: "Private"
        }
    }

    var systemImage: String {
        switch self {
        case .isPublic: "globe"
        case .isPrivate: "lock.fill"
        }
    }
}

enum ProfileServiceError: LocalizedError {
    case handleTaken
    case avatarUnreadable
    case avatarSaveFailed
    case offline

    var errorDescription: String? {
        switch self {
        case .handleTaken: "That handle is already taken."
        case .avatarUnreadable: "That photo couldn't be read. Try another one."
        case .avatarSaveFailed: "Your photo couldn't be saved. Try again."
        case .offline: "MONO couldn't connect. Check your connection and try again."
        }
    }
}

// MARK: - Handles

enum HandleRules {
    static let minLength = 3
    static let maxLength = 20
    private static let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._")

    /// "  @Mina.Shelf " → "mina.shelf"
    static func normalized(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while value.hasPrefix("@") { value.removeFirst() }
        return value
    }

    static func display(_ handle: String) -> String {
        handle.isEmpty ? "" : "@" + handle
    }

    /// Nil when the handle is valid.
    static func problem(with handle: String) -> String? {
        if handle.isEmpty { return "Choose a handle so friends can find you." }
        if handle.count < minLength { return "Use at least \(minLength) characters." }
        if handle.count > maxLength { return "Use \(maxLength) characters or fewer." }
        if !handle.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return "Use only letters, numbers, periods and underscores."
        }
        if handle.hasPrefix(".") || handle.hasSuffix(".") {
            return "A handle can't start or end with a period."
        }
        return nil
    }

    /// "Mina Park" → "minapark"
    static func suggestion(from name: String) -> String {
        let letters = name.lowercased().unicodeScalars.filter { allowed.contains($0) }
        return String(String(letters).prefix(maxLength))
    }
}

// MARK: - Profile Links

enum ProfileLinks {
    // TODO(team): agree on the link format. A custom scheme only opens MONO
    // once it's registered in Xcode: Target ▸ Info ▸ URL Types ▸ "+",
    // URL Schemes = monoarchive. A real https link needs a hosted web page.
    static let scheme = "monoarchive"

    /// monoarchive://u/minashelf
    static func url(for handle: String) -> URL? {
        guard !handle.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = "u"
        components.path = "/" + handle
        return components.url
    }

    static func handle(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == "u" else { return nil }
        let handle = HandleRules.normalized(url.lastPathComponent)
        return handle.isEmpty ? nil : handle
    }
}

// MARK: - Service Interface

/// Everything the Profile module needs from the data layer.
/// Fei's Firebase version should implement this same protocol.
protocol ProfileServicing {
    func loadProfile() async throws -> UserProfile
    func saveProfile(_ profile: UserProfile) async throws

    /// Stores a prepared JPEG and returns its file name (or storage path).
    func uploadAvatar(_ jpegData: Data) async throws -> String
    func loadAvatar(named name: String) async throws -> UIImage?
    func deleteAvatar(named name: String) async throws

    /// `handle` is already normalized. The current user's own handle should
    /// not be passed in (ProfileStore checks that first).
    func isHandleAvailable(_ handle: String) async throws -> Bool
    func searchUsers(matching query: String) async throws -> [SocialUser]

    /// Keyed by collection ID. For now the IDs are category raw values
    /// ("vinyl", "bjd", …); custom collections can use their own IDs.
    func loadVisibility() async throws -> [String: CollectionVisibility]
    func setVisibility(_ visibility: CollectionVisibility, forCollectionID id: String) async throws
}

// MARK: - Local Service (works offline, used until Firebase is ready)

struct LocalProfileService: ProfileServicing {
    let defaults: UserDefaults = .standard
    /// Set to true to try the loading and error states in the simulator.
    var simulateSlowNetwork = false
    var simulateFailure = false

    // Same keys the app already used, so existing profiles carry over.
    private enum Key {
        static let name = "profile.name"
        static let handle = "profile.handle"
        static let location = "profile.location"
        static let bio = "profile.bio"
        static let avatar = "profile.avatarFileName"
        static let visibility = "profile.collectionVisibility"
    }

    private func simulateNetwork() async throws {
        if simulateSlowNetwork { try await Task.sleep(nanoseconds: 1_200_000_000) }
        if simulateFailure { throw ProfileServiceError.offline }
    }

    func loadProfile() async throws -> UserProfile {
        try await simulateNetwork()
        return UserProfile(
            name: defaults.string(forKey: Key.name) ?? "",
            handle: HandleRules.normalized(defaults.string(forKey: Key.handle) ?? ""),
            location: defaults.string(forKey: Key.location) ?? "",
            bio: defaults.string(forKey: Key.bio) ?? "",
            avatarFileName: defaults.string(forKey: Key.avatar)
        )
    }

    func saveProfile(_ profile: UserProfile) async throws {
        try await simulateNetwork()
        defaults.set(profile.name, forKey: Key.name)
        defaults.set(profile.handle, forKey: Key.handle)
        defaults.set(profile.location, forKey: Key.location)
        defaults.set(profile.bio, forKey: Key.bio)
        defaults.set(profile.avatarFileName, forKey: Key.avatar)
    }

    func uploadAvatar(_ jpegData: Data) async throws -> String {
        try await simulateNetwork()
        guard let name = ImageStore.save(jpegData) else {
            throw ProfileServiceError.avatarSaveFailed
        }
        return name
    }

    func loadAvatar(named name: String) async throws -> UIImage? {
        ImageStore.image(named: name)
    }

    func deleteAvatar(named name: String) async throws {
        ImageStore.delete(named: name)
    }

    func isHandleAvailable(_ handle: String) async throws -> Bool {
        try await simulateNetwork()
        return !DemoCollectors.all.contains { HandleRules.normalized($0.handle) == handle }
    }

    func searchUsers(matching query: String) async throws -> [SocialUser] {
        try await simulateNetwork()
        let query = HandleRules.normalized(query)
        guard !query.isEmpty else { return [] }
        return DemoCollectors.all
            .filter { user in
                HandleRules.normalized(user.handle).contains(query)
                    || user.name.lowercased().contains(query)
            }
            .sorted { lhs, rhs in
                // Handles that start with the query first.
                let left = HandleRules.normalized(lhs.handle).hasPrefix(query)
                let right = HandleRules.normalized(rhs.handle).hasPrefix(query)
                return left && !right
            }
    }

    func loadVisibility() async throws -> [String: CollectionVisibility] {
        try await simulateNetwork()
        guard let data = defaults.data(forKey: Key.visibility),
              let stored = try? JSONDecoder().decode([String: CollectionVisibility].self, from: data) else {
            return [:]
        }
        return stored
    }

    func setVisibility(_ visibility: CollectionVisibility, forCollectionID id: String) async throws {
        var all = try await loadVisibility()
        all[id] = visibility
        let data = try JSONEncoder().encode(all)
        defaults.set(data, forKey: Key.visibility)
    }
}

// MARK: - Cloud Service (Firebase profile + local photo/visibility)

/// Name, handle, location and bio live in Firestore through
/// `CloudProfileStore`. The photo, handle lookup, search and visibility still
/// use `LocalProfileService` until they have a cloud home.
@MainActor
struct CloudBackedProfileService: ProfileServicing {
    let cloud: CloudProfileStore
    var local = LocalProfileService()

    func loadProfile() async throws -> UserProfile {
        cloud.activateCurrentUserIfNeeded()
        let remote = cloud.profile
        let stored = try? await local.loadProfile()
        return UserProfile(
            name: remote.name,
            handle: HandleRules.normalized(remote.handle),
            location: remote.location,
            bio: remote.bio,
            avatarFileName: stored?.avatarFileName
        )
    }

    func saveProfile(_ profile: UserProfile) async throws {
        // Photo first: it is local, so it should not be lost if cloud sync fails.
        var stored = (try? await local.loadProfile()) ?? UserProfile()
        stored.avatarFileName = profile.avatarFileName
        try await local.saveProfile(stored)

        cloud.activateCurrentUserIfNeeded()
        try await cloud.save(CloudUserProfile(
            name: profile.name, handle: profile.handle,
            location: profile.location, bio: profile.bio
        ))
    }

    func uploadAvatar(_ jpegData: Data) async throws -> String { try await local.uploadAvatar(jpegData) }
    func loadAvatar(named name: String) async throws -> UIImage? { try await local.loadAvatar(named: name) }
    func deleteAvatar(named name: String) async throws { try await local.deleteAvatar(named: name) }
    func isHandleAvailable(_ handle: String) async throws -> Bool { try await local.isHandleAvailable(handle) }
    func searchUsers(matching query: String) async throws -> [SocialUser] { try await local.searchUsers(matching: query) }
    func loadVisibility() async throws -> [String: CollectionVisibility] { try await local.loadVisibility() }
    func setVisibility(_ visibility: CollectionVisibility, forCollectionID id: String) async throws {
        try await local.setVisibility(visibility, forCollectionID: id)
    }
}

// MARK: - Store (what the screens use)

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum AvatarChange {
        case keep
        case replace(Data)
        case remove
    }

    @Published private(set) var profile = UserProfile()
    @Published private(set) var avatar: UIImage?
    @Published private(set) var loadState: LoadState = .idle
    @Published private var visibilityByID: [String: CollectionVisibility] = [:]

    private var service: any ProfileServicing
    private var cloudSubscription: AnyCancellable?

    init(service: any ProfileServicing = LocalProfileService()) {
        self.service = service
    }

    /// Switches to the Firebase-backed profile (name, handle, location, bio)
    /// and keeps the screen in step with cloud updates and account changes.
    func connect(cloud: CloudProfileStore) {
        guard cloudSubscription == nil else { return }
        service = CloudBackedProfileService(cloud: cloud)
        cloudSubscription = cloud.$profile
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                var updated = self.profile
                updated.name = value.name
                updated.handle = HandleRules.normalized(value.handle)
                updated.location = value.location
                updated.bio = value.bio
                self.profile = updated
            }
        Task { await reload() }
    }

    // MARK: Display helpers

    var displayHandle: String { HandleRules.display(profile.handle) }

    var initials: String {
        let letters = profile.name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "M" : letters.map(String.init).joined().uppercased()
    }

    var shareURL: URL? { ProfileLinks.url(for: profile.handle) }

    // MARK: Loading

    func loadIfNeeded() async {
        guard loadState == .idle else { return }
        await reload()
    }

    func reload() async {
        loadState = .loading
        do {
            let loaded = try await service.loadProfile()
            let visibility = try await service.loadVisibility()
            var image: UIImage?
            if let name = loaded.avatarFileName {
                image = try? await service.loadAvatar(named: name)
            }
            profile = loaded
            visibilityByID = visibility
            avatar = image
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: Editing

    /// Called once at sign-up with the name the user typed.
    func applySignUp(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = (try? await service.loadProfile()) ?? UserProfile()
        updated.name = trimmed
        if updated.handle.isEmpty {
            let suggestion = HandleRules.suggestion(from: trimmed)
            if HandleRules.problem(with: suggestion) == nil,
               (try? await service.isHandleAvailable(suggestion)) == true {
                updated.handle = suggestion
            }
        }
        try? await service.saveProfile(updated)
        profile = updated
    }

    func isHandleAvailable(_ handle: String) async throws -> Bool {
        if handle == profile.handle { return true }
        return try await service.isHandleAvailable(handle)
    }

    func save(_ updated: UserProfile, avatarChange: AvatarChange) async throws {
        var updated = updated
        updated.handle = HandleRules.normalized(updated.handle)
        if updated.handle != profile.handle,
           try await service.isHandleAvailable(updated.handle) == false {
            throw ProfileServiceError.handleTaken
        }

        let oldAvatarName = profile.avatarFileName
        var newImage = avatar
        switch avatarChange {
        case .keep:
            updated.avatarFileName = oldAvatarName
        case .replace(let data):
            updated.avatarFileName = try await service.uploadAvatar(data)
            newImage = UIImage(data: data)
        case .remove:
            updated.avatarFileName = nil
            newImage = nil
        }

        try await service.saveProfile(updated)

        // Only clean up the old photo once the new profile is saved.
        if let oldAvatarName, oldAvatarName != updated.avatarFileName {
            try? await service.deleteAvatar(named: oldAvatarName)
        }
        profile = updated
        avatar = newImage
    }

    // MARK: Search

    func searchUsers(matching query: String) async throws -> [SocialUser] {
        try await service.searchUsers(matching: query)
            .filter { HandleRules.normalized($0.handle) != profile.handle }
    }

    // MARK: Visibility

    /// Settings ▸ Default visibility. Applies to every collection the user
    /// hasn't set on its own. Private unless they change it.
    // TODO(Fei): move to the user's cloud settings with the rest of the profile.
    static let defaultVisibilityKey = "profile.defaultVisibility"

    @Published var defaultVisibility: CollectionVisibility =
        CollectionVisibility(rawValue: UserDefaults.standard.string(forKey: ProfileStore.defaultVisibilityKey) ?? "")
            ?? .isPrivate {
        didSet {
            UserDefaults.standard.set(defaultVisibility.rawValue, forKey: Self.defaultVisibilityKey)
        }
    }

    func visibility(for category: CollectionCategory) -> CollectionVisibility {
        visibilityByID[category.rawValue] ?? defaultVisibility
    }

    func setVisibility(_ visibility: CollectionVisibility, for category: CollectionCategory) async throws {
        let id = category.rawValue
        let previous = visibilityByID[id]
        visibilityByID[id] = visibility  // Update right away; undo if saving fails.
        do {
            try await service.setVisibility(visibility, forCollectionID: id)
        } catch {
            visibilityByID[id] = previous
            throw error
        }
    }
}

// MARK: - Avatar

enum AvatarImage {
    /// Center-crops to a square and shrinks to 600 px. Nil if unreadable.
    static func prepare(_ data: Data, side: CGFloat = 600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let shortest = min(image.size.width, image.size.height)
        guard shortest > 0 else { return nil }
        let scale = side / shortest
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
            .image { _ in image.draw(in: CGRect(origin: origin, size: drawSize)) }
        return square.jpegData(compressionQuality: 0.85)
    }
}

struct ProfileAvatarView: View {
    let image: UIImage?
    let initials: String
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        ArchiveTheme.paperTan.opacity(0.65),
                        ArchiveTheme.collectedRed.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(initials)
                    .font(ArchiveTheme.heading(max(12, size * 0.3)))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.3))
        .accessibilityLabel(image == nil ? "Profile initials" : "Profile photo")
    }
}
