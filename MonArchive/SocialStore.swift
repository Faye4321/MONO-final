import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CryptoKit
import UIKit

@MainActor
final class SocialStore: ObservableObject {
    var currentUserID: UUID {
        guard cloudStarted, let uid = Auth.auth().currentUser?.uid else { return DemoSocialIDs.currentUser }
        return Self.socialID(uid)
    }

    @Published var friends: [SocialUser]
    @Published var friendRequests: [FriendRequest]
    @Published var sharedCollections: [SharedCollection]
    @Published var conversations: [ChatConversation]
    @Published var messages: [ChatMessage]

    /// Collectors the user has sent a friend request to, still waiting.
    @Published private(set) var sentRequestIDs: Set<UUID> = []

    // MARK: Friends (Firestore: friendships/, profiles/)

    enum FriendsLoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var friendsState: FriendsLoadState = .ready
    /// Shown by the Friends screens when an add / accept / remove fails.
    @Published var friendActionError: String?
    /// Users with an add / accept / remove in flight (no double taps).
    @Published private(set) var busyUserIDs: Set<UUID> = []
    @Published private(set) var friendSince: [UUID: Date] = [:]
    private var friendshipListener: ListenerRegistration?
    private var uidBySocialID: [UUID: String] = [:]
    private var knownUsers: [UUID: SocialUser] = [:]
    private var collectionMembers: [UUID: SocialUser] = [:]
    private var directoryCache: [String: DirectoryProfile] = [:]
    private var lastPublishedStats: String?

    init() {
        let mina = DemoCollectors.mina
        let alex = DemoCollectors.alex
        let yuki = DemoCollectors.yuki
        let jamie = DemoCollectors.jamie

        friends = [mina, alex, yuki]

        friendRequests = [
            FriendRequest(
                id: DemoSocialIDs.jamieRequest,
                sender: jamie,
                mutualCollectionCount: 2,
                mutualInterestCount: 12
            )
        ]

        let weekendRecordHunt = SharedCollection(
            id: DemoSocialIDs.weekendCollection,
            name: "Weekend Record Hunt",
            ownerID: DemoSocialIDs.currentUser,
            memberIDs: [
                DemoSocialIDs.currentUser,
                mina.id,
                alex.id
            ],
            itemIDs: [],
            permission: .everyoneCanAdd,
            createdAt: Date().addingTimeInterval(-86_400 * 8),
            updatedAt: Date().addingTimeInterval(-1_080)
        )

        sharedCollections = [weekendRecordHunt]

        let directConversation = ChatConversation(
            id: DemoSocialIDs.minaConversation,
            kind: .direct,
            title: "Mina",
            participantIDs: [
                DemoSocialIDs.currentUser,
                mina.id
            ]
        )

        let groupConversation = ChatConversation(
            id: DemoSocialIDs.weekendConversation,
            kind: .sharedCollection,
            title: "Weekend Record Hunt",
            participantIDs: weekendRecordHunt.memberIDs,
            sharedCollectionID: weekendRecordHunt.id
        )

        conversations = [
            directConversation,
            groupConversation
        ]

        messages = [
            ChatMessage(
                id: DemoSocialIDs.messageOne,
                conversationID: directConversation.id,
                senderID: mina.id,
                body: "I found this pressing downtown. Should we add it?",
                sentAt: Date().addingTimeInterval(-3_600)
            ),
            ChatMessage(
                id: DemoSocialIDs.messageTwo,
                conversationID: directConversation.id,
                senderID: DemoSocialIDs.currentUser,
                body: "Yes! The cover fits the shelf perfectly.",
                sentAt: Date().addingTimeInterval(-3_300)
            ),
            ChatMessage(
                id: DemoSocialIDs.messageThree,
                conversationID: groupConversation.id,
                senderID: mina.id,
                body: "I added For You to our shared collection.",
                sentAt: Date().addingTimeInterval(-1_800)
            ),
            ChatMessage(
                id: DemoSocialIDs.messageFour,
                conversationID: groupConversation.id,
                senderID: alex.id,
                body: "I added the shop location in the note.",
                sentAt: Date().addingTimeInterval(-1_200)
            )
        ]
    }

    @Published var cloudError: String?
    @Published private(set) var cloudItems: [UUID: [CollectibleItem]] = [:]
    @Published private(set) var cloudBusy = false
    private var cloudStarted = false
    private var cloudUID: String?
    private weak var personalStore: CollectionStore?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var collectionsListener: ListenerRegistration?
    private var sharedItemListeners: [UUID: ListenerRegistration] = [:]
    private var metadata: [UUID: [String: Any]] = [:]

    private static func socialID(_ uid: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(uid.utf8)).prefix(16))
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],
                           bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }

    func startCloud(collectionStore: CollectionStore) {
        guard !cloudStarted else { return }
        cloudStarted = true
        personalStore = collectionStore
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            Task { @MainActor in self?.observeSharedCollections(uid: uid) }
        }
    }

    private func observeSharedCollections(uid: String?) {
        collectionsListener?.remove()
        sharedItemListeners.values.forEach { $0.remove() }
        sharedItemListeners = [:]; metadata = [:]; cloudItems = [:]
        cloudUID = uid
        observeFriendships(uid: uid)
        sharedCollections = []
        conversations = []; messages = []; cloudError = nil; cloudBusy = false
        guard let uid else { return }
        collectionsListener = Firestore.firestore().collection("sharedCollections")
            .whereField("memberUIDs", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.cloudUID == uid else { return }
                    if let error { self.cloudError = error.localizedDescription; return }
                    guard let snapshot else { return }
                    var result: [SharedCollection] = []
                    var members: [UUID: SocialUser] = [:]
                    for doc in snapshot.documents {
                        let data = doc.data()
                        guard let id = UUID(uuidString: doc.documentID),
                              let owner = data["ownerUID"] as? String,
                              let memberUIDs = data["memberUIDs"] as? [String] else { continue }
                        self.metadata[id] = data
                        let names = data["memberNames"] as? [String: String] ?? [:]
                        for memberUID in memberUIDs where memberUID != uid {
                            let socialID = Self.socialID(memberUID)
                            members[socialID] = SocialUser(id: socialID, name: names[memberUID] ?? "Collector",
                                handle: "", location: "", bio: "", interests: [], objectCount: 0,
                                collectionCount: 0, sharedCollectionCount: 0,
                                avatarColorA: "D5B99C", avatarColorB: "706B63")
                        }
                        result.append(SharedCollection(id: id, name: data["name"] as? String ?? "Shared collection",
                            ownerID: Self.socialID(owner), memberIDs: memberUIDs.map(Self.socialID),
                            itemIDs: (data["itemIDs"] as? [String] ?? []).compactMap(UUID.init(uuidString:)),
                            permission: SharedPermission(rawValue: data["permission"] as? String ?? "ownerOnly") ?? .ownerOnly,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
                            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? .now))
                        self.observeSharedItems(id, uid: uid)
                    }
                    let ids = Set(result.map(\.id))
                    for id in Array(self.sharedItemListeners.keys) where !ids.contains(id) {
                        self.sharedItemListeners.removeValue(forKey: id)?.remove()
                        self.cloudItems.removeValue(forKey: id)
                        self.metadata.removeValue(forKey: id)
                    }
                    self.sharedCollections = result.sorted { $0.updatedAt > $1.updatedAt }
                    // Collection members aren't automatically friends; they
                    // are kept only so avatars and names can be shown.
                    self.collectionMembers = members
                }
            }
    }

    private func observeSharedItems(_ id: UUID, uid: String) {
        guard sharedItemListeners[id] == nil else { return }
        sharedItemListeners[id] = Firestore.firestore().collection("sharedCollections")
            .document(id.uuidString).collection("items").addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.cloudUID == uid else { return }
                    if let error { self.cloudError = error.localizedDescription; return }
                    guard let snapshot else { return }
                    self.cloudItems[id] = snapshot.documents.compactMap { doc -> CollectibleItem? in
                        guard let payload = doc.data()["payload"] as? String,
                              let bytes = payload.data(using: .utf8),
                              var item = try? JSONDecoder().decode(CollectibleItem.self, from: bytes) else { return nil }
                        item.imageFileName = nil
                        item.imageData = doc.data()["preview"] as? Data
                        return item
                    }.sorted { $0.title < $1.title }
                }
            }
    }

    private func createCloudCollection(name: String, itemIDs: [UUID], permission: SharedPermission) -> SharedCollection {
        let collection = SharedCollection(name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Shared collection" : name,
            ownerID: currentUserID, memberIDs: [currentUserID], itemIDs: [], permission: permission)
        guard let uid = cloudUID else { cloudError = "Please sign in first."; return collection }
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "") + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let label = Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "Collector"
        let data: [String: Any] = ["name": collection.name, "ownerUID": uid, "memberUIDs": [uid],
            "memberNames": [uid: label], "itemIDs": [String](), "permission": permission.rawValue,
            "inviteToken": token, "createdAt": FieldValue.serverTimestamp(), "updatedAt": FieldValue.serverTimestamp()]
        cloudBusy = true
        Task { @MainActor in
            defer { if self.cloudUID == uid { self.cloudBusy = false } }
            do {
                let db = Firestore.firestore()
                let batch = db.batch()
                batch.setData(data, forDocument: db.collection("sharedCollections").document(collection.id.uuidString))
                batch.setData(["collectionID": collection.id.uuidString, "ownerUID": uid], forDocument: db.collection("invites").document(token))
                try await batch.commit()
                guard self.cloudUID == uid else { return }
                self.metadata[collection.id] = data
                for itemID in itemIDs { await self.publishSharedItem(itemID, collectionID: collection.id) }
            } catch { if self.cloudUID == uid { self.cloudError = error.localizedDescription } }
        }
        return collection
    }

    // MARK: Membership changes (API shared by the backend and UI work)

    /// Whether the signed-in user created this shared collection.
    func isOwner(of collection: SharedCollection) -> Bool {
        collection.ownerID == currentUserID
    }

    /// Owner only: removes another member. Throws a user-facing error.
    func removeMember(_ userID: UUID, from collectionID: UUID) async throws {
        guard let uid = cloudUID else { throw CollectionStore.CloudFailure.message("Sign in first.") }
        guard let data = metadata[collectionID] else { throw CollectionStore.CloudFailure.message("This collection isn't available right now.") }
        guard data["ownerUID"] as? String == uid else { throw CollectionStore.CloudFailure.message("Only the person who created this collection can remove members.") }
        let memberUIDs = data["memberUIDs"] as? [String] ?? []
        guard let target = memberUIDs.first(where: { Self.socialID($0) == userID }) ?? uidBySocialID[userID],
              memberUIDs.contains(target) else { throw CollectionStore.CloudFailure.message("This person isn't in the collection anymore.") }
        guard target != uid else { throw CollectionStore.CloudFailure.message("You can't remove yourself. Delete the collection instead.") }
        try await updateMembership(collectionID, removing: target)
        guard cloudUID == uid else { return }
        var updated = data
        updated["memberUIDs"] = memberUIDs.filter { $0 != target }
        if var names = data["memberNames"] as? [String: Any] { names.removeValue(forKey: target); updated["memberNames"] = names }
        metadata[collectionID] = updated
        if let index = sharedCollections.firstIndex(where: { $0.id == collectionID }) {
            sharedCollections[index].memberIDs.removeAll { $0 == userID }
        }
    }

    /// Non-owner member: leaves the collection. Throws a user-facing error.
    func leaveCollection(_ collectionID: UUID) async throws {
        guard let uid = cloudUID else { throw CollectionStore.CloudFailure.message("Sign in first.") }
        let owner = metadata[collectionID]?["ownerUID"] as? String
            ?? sharedCollections.first(where: { $0.id == collectionID }).map { $0.ownerID == currentUserID ? uid : "" }
        guard owner != uid else { throw CollectionStore.CloudFailure.message("You created this collection. Delete it instead of leaving.") }
        try await updateMembership(collectionID, removing: uid)
        guard cloudUID == uid else { return }
        sharedItemListeners.removeValue(forKey: collectionID)?.remove()
        cloudItems.removeValue(forKey: collectionID)
        metadata.removeValue(forKey: collectionID)
        sharedCollections.removeAll { $0.id == collectionID }
    }

    private func updateMembership(_ collectionID: UUID, removing memberUID: String) async throws {
        do {
            try await Firestore.firestore().collection("sharedCollections").document(collectionID.uuidString).updateData([
                "memberUIDs": FieldValue.arrayRemove([memberUID]),
                "memberNames." + memberUID: FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch where SocialDirectoryError.isPermission(error) {
            throw CollectionStore.CloudFailure.message("You don't have permission to change who's in this collection.")
        } catch {
            throw CollectionStore.CloudFailure.message("Couldn't update the collection. Check your connection and try again.")
        }
    }

    func invitation(for id: UUID) -> String? {
        guard let token = metadata[id]?["inviteToken"] as? String else { return nil }
        return "mono://collection?invite=" + token
    }

    func joinCollection(invitation: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw CollectionStore.CloudFailure.message("Sign in first, then paste the invitation again.") }
        let input = invitation.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = URLComponents(string: input)?.queryItems?.first(where: { $0.name == "invite" })?.value ?? input
        guard token.count == 64, token.allSatisfy({ $0.isHexDigit }) else {
            throw CollectionStore.CloudFailure.message("Paste a valid MONO invitation link or code.")
        }
        let db = Firestore.firestore()
        let invite: DocumentSnapshot
        do { invite = try await db.collection("invites").document(token).getDocument() }
        catch where SocialDirectoryError.isPermission(error) {
            throw CollectionStore.CloudFailure.message("You don't have permission to open this invitation.")
        }
        guard let collectionID = invite.data()?["collectionID"] as? String else {
            throw CollectionStore.CloudFailure.message("This invitation has expired or was cancelled. Ask for a new link.")
        }
        guard cloudUID == uid else { throw CancellationError() }
        if let id = UUID(uuidString: collectionID), sharedCollections.contains(where: { $0.id == id }) {
            throw CollectionStore.CloudFailure.message("You're already in this collection.")
        }
        let label = ProfileStore.shared.profile.name.isEmpty
            ? (Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "Collector")
            : ProfileStore.shared.profile.name
        do {
            try await db.collection("sharedCollections").document(collectionID).updateData([
                "memberUIDs": FieldValue.arrayUnion([uid]),
                "joinProof": token,
                "memberNames." + uid: label
            ])
        } catch where SocialDirectoryError.isPermission(error) {
            throw CollectionStore.CloudFailure.message("You can't join this collection. It may be full, or the invitation was replaced.")
        }
    }

    private func publishSharedItem(_ id: UUID, collectionID: UUID) async {
        do { try await publishSharedItemOrThrow(id, collectionID: collectionID) }
        catch { if cloudUID != nil { cloudError = error.localizedDescription } }
    }

    /// Adds several of the user's own objects to a shared collection and
    /// reports failure to the caller, so the picker can keep its selection.
    func addItems(_ ids: [UUID], to collectionID: UUID) async throws {
        guard cloudStarted else {
            ids.forEach { addItem($0, to: collectionID) }
            return
        }
        for id in ids { try await publishSharedItemOrThrow(id, collectionID: collectionID) }
    }

    private func publishSharedItemOrThrow(_ id: UUID, collectionID: UUID) async throws {
        guard let uid = cloudUID else { throw CollectionStore.CloudFailure.message("Please sign in first.") }
        guard var item = personalStore?.item(id: id) else {
            throw CollectionStore.CloudFailure.message("That object is no longer in your collection.")
        }
        do {
            // Shared copies have a bounded preview; never grant access to the owner's private bucket.
            let source = item.uploadedImage ?? item.imageName.flatMap { UIImage(named: $0) }
            var preview: Data?
            if let source {
                let scale = min(1, 600 / max(source.size.width, source.size.height))
                let size = CGSize(width: max(1, source.size.width * scale), height: max(1, source.size.height * scale))
                let resized = UIGraphicsImageRenderer(size: size).image { _ in source.draw(in: CGRect(origin: .zero, size: size)) }
                preview = resized.jpegData(compressionQuality: 0.5)
                if (preview?.count ?? 0) > 180_000 { preview = resized.jpegData(compressionQuality: 0.15) }
                guard (preview?.count ?? 0) <= 180_000 else { throw CollectionStore.CloudFailure.message("Shared image preview is too large.") }
            }
            item.imageFileName = nil; item.imageData = nil
            let payload = String(decoding: try JSONEncoder().encode(item), as: UTF8.self)
            guard payload.utf8.count < 400_000 else { throw CollectionStore.CloudFailure.message("Object text is too large to share.") }
            var data: [String: Any] = ["payload": payload, "uploaderUID": uid, "updatedAt": FieldValue.serverTimestamp()]
            if let preview { data["preview"] = preview }
            guard cloudUID == uid else { throw CancellationError() }
            let root = Firestore.firestore().collection("sharedCollections").document(collectionID.uuidString)
            let batch = Firestore.firestore().batch()
            batch.setData(data, forDocument: root.collection("items").document(id.uuidString))
            batch.updateData(["itemIDs": FieldValue.arrayUnion([id.uuidString]), "updatedAt": FieldValue.serverTimestamp()], forDocument: root)
            try await batch.commit()
        } catch {
            guard cloudUID == uid else { throw CancellationError() }
            throw error
        }
    }

    // MARK: - Users

    func user(withID id: UUID) -> SocialUser? {
        friends.first { $0.id == id }
            ?? friendRequests
                .map(\.sender)
                .first { $0.id == id }
            ?? knownUsers[id]
            ?? collectionMembers[id]
            ?? (cloudStarted ? nil : DemoCollectors.all.first { $0.id == id })
    }

    func members(
        of collection: SharedCollection
    ) -> [SocialUser] {
        collection.memberIDs.compactMap { id in
            user(withID: id)
        }
    }

    // MARK: - Friend Requests

    func isFriend(_ userID: UUID) -> Bool {
        friends.contains { $0.id == userID }
    }

    func incomingRequest(from userID: UUID) -> FriendRequest? {
        friendRequests.first { $0.sender.id == userID }
    }

    func hasSentRequest(to userID: UUID) -> Bool {
        sentRequestIDs.contains(userID)
    }

    func sendFriendRequest(to user: SocialUser) {
        guard !isFriend(user.id), !hasSentRequest(to: user.id) else { return }
        guard cloudStarted else { sentRequestIDs.insert(user.id); return }
        if let incoming = incomingRequest(from: user.id) {
            // They already asked: adding them back means accepting.
            acceptFriendRequest(incoming)
            return
        }
        guard let other = uidBySocialID[user.id] else {
            friendActionError = "Couldn't find this collector. Search for them again."
            return
        }
        runFriendAction(for: user.id, optimistic: { $0.sentRequestIDs.insert(user.id) },
                        undo: { $0.sentRequestIDs.remove(user.id) }) { store in
            guard let me = try await store.myDirectoryProfile() else {
                throw CollectionStore.CloudFailure.message("Add a handle to your profile first, so they can see who's asking.")
            }
            let target = store.directoryCache[other]
                ?? DirectoryProfile(uid: other, name: user.name, handle: HandleRules.normalized(user.handle))
            try await SocialDirectory.sendRequest(to: target, from: me)
        }
    }

    func cancelFriendRequest(to user: SocialUser) {
        guard cloudStarted else { sentRequestIDs.remove(user.id); return }
        guard let other = uidBySocialID[user.id], let me = SocialDirectory.currentUID else { return }
        runFriendAction(for: user.id, optimistic: { $0.sentRequestIDs.remove(user.id) },
                        undo: { $0.sentRequestIDs.insert(user.id) }) { _ in
            try await SocialDirectory.remove(pairID: SocialDirectory.pairID(me, other))
        }
    }

    func removeFriend(_ user: SocialUser) {
        guard cloudStarted else { friends.removeAll { $0.id == user.id }; return }
        guard let other = uidBySocialID[user.id], let me = SocialDirectory.currentUID else { return }
        let previous = friends
        runFriendAction(for: user.id, optimistic: { $0.friends.removeAll { $0.id == user.id } },
                        undo: { $0.friends = previous }) { _ in
            try await SocialDirectory.remove(pairID: SocialDirectory.pairID(me, other))
        }
    }

    func isBusy(_ userID: UUID) -> Bool { busyUserIDs.contains(userID) }

    func acceptFriendRequest(_ request: FriendRequest) {
        guard cloudStarted else {
            if friends.contains(where: { $0.id == request.sender.id }) == false {
                friends.append(request.sender)
            }
            friendRequests.removeAll { $0.id == request.id }
            return
        }
        guard let other = uidBySocialID[request.sender.id], let me = SocialDirectory.currentUID else { return }
        let previousFriends = friends, previousRequests = friendRequests
        runFriendAction(for: request.sender.id, optimistic: { store in
            store.friendRequests.removeAll { $0.id == request.id }
            if !store.friends.contains(where: { $0.id == request.sender.id }) { store.friends.append(request.sender) }
        }, undo: { store in
            store.friends = previousFriends; store.friendRequests = previousRequests
        }) { _ in
            try await SocialDirectory.accept(pairID: SocialDirectory.pairID(me, other))
        }
    }

    func declineFriendRequest(_ request: FriendRequest) {
        guard cloudStarted else {
            friendRequests.removeAll { $0.id == request.id }
            return
        }
        guard let other = uidBySocialID[request.sender.id], let me = SocialDirectory.currentUID else { return }
        let previous = friendRequests
        runFriendAction(for: request.sender.id, optimistic: { $0.friendRequests.removeAll { $0.id == request.id } },
                        undo: { $0.friendRequests = previous }) { _ in
            try await SocialDirectory.remove(pairID: SocialDirectory.pairID(me, other))
        }
    }

    /// Updates the screen right away, then writes to Firestore. The
    /// friendships listener has the final say; on failure the change is
    /// undone and the reason shown.
    private func runFriendAction(
        for userID: UUID,
        optimistic: (SocialStore) -> Void,
        undo: @escaping (SocialStore) -> Void,
        _ work: @escaping (SocialStore) async throws -> Void
    ) {
        guard !busyUserIDs.contains(userID) else { return }
        busyUserIDs.insert(userID)
        friendActionError = nil
        optimistic(self)
        let uid = cloudUID
        Task { @MainActor in
            defer { self.busyUserIDs.remove(userID) }
            do {
                try await work(self)
                Haptics.light()
            } catch {
                guard self.cloudUID == uid else { return }
                undo(self)
                self.friendActionError = SocialDirectoryError.isPermission(error)
                    ? "That didn't go through. They may have already sent you a request — check Requests. If this keeps happening, the server's friend rules may not be published yet."
                    : error.localizedDescription
            }
        }
    }

    // MARK: - Directory

    /// Search registered collectors by handle (P10). Results can be added.
    func searchDirectory(_ query: String) async throws -> [SocialUser] {
        guard cloudStarted else {
            return DemoCollectors.all.filter { HandleRules.normalized($0.handle).hasPrefix(query) }
        }
        return try await SocialDirectory.search(prefix: query).map(register)
    }

    /// A collector from a shared profile link (mono://u/handle).
    func collector(handle: String) async throws -> SocialUser? {
        guard let profile = try await SocialDirectory.profile(handle: handle) else { return nil }
        return register(profile)
    }

    func directoryProfile(for userID: UUID) -> DirectoryProfile? {
        uidBySocialID[userID].flatMap { directoryCache[$0] }
    }

    func isCurrentUser(_ userID: UUID) -> Bool { userID == currentUserID }

    @discardableResult
    private func register(_ profile: DirectoryProfile) -> SocialUser {
        directoryCache[profile.uid] = profile
        let user = Self.socialUser(profile)
        uidBySocialID[user.id] = profile.uid
        knownUsers[user.id] = user
        return user
    }

    private static func socialUser(_ profile: DirectoryProfile) -> SocialUser {
        let palette = ["D5B99C", "B84631", "727B70", "262624", "C8B7A8", "706B63", "536D78", "A68E9A"]
        let hash = profile.uid.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return SocialUser(
            id: socialID(profile.uid), name: profile.name,
            handle: HandleRules.display(profile.handle), location: profile.location, bio: profile.bio,
            interests: [], objectCount: profile.objectCount, collectionCount: profile.collectionCount,
            sharedCollectionCount: 0,
            avatarColorA: palette[hash % palette.count], avatarColorB: palette[(hash / 8 + 3) % palette.count])
    }

    private func myDirectoryProfile() async throws -> DirectoryProfile? {
        guard let uid = SocialDirectory.currentUID else { throw SocialDirectoryError.notSignedIn }
        if let cached = directoryCache[uid] { return cached }
        if let remote = try await SocialDirectory.profile(uid: uid) {
            directoryCache[uid] = remote
            return remote
        }
        return nil
    }

    /// Keeps the public counts on profiles/{uid} current. Quietly does
    /// nothing if the user has no public profile yet.
    func publishStats(objectCount: Int, collectionCount: Int,
                      publicCollections: [DirectoryProfile.PublicCollection]) {
        guard cloudStarted, cloudUID != nil else { return }
        let key = "\(objectCount)|\(collectionCount)|\(publicCollections.map { "\($0.name):\($0.count)" })"
        guard key != lastPublishedStats else { return }
        lastPublishedStats = key
        Task { @MainActor in
            do {
                try await SocialDirectory.updateStats(objectCount: objectCount, collectionCount: collectionCount,
                                                      publicCollections: publicCollections)
            } catch {
                // No public profile yet (no handle) or offline: try again next time.
                if self.lastPublishedStats == key { self.lastPublishedStats = nil }
            }
        }
    }

    // MARK: - Friendships listener

    private func observeFriendships(uid: String?) {
        friendshipListener?.remove()
        friendshipListener = nil
        friends = []; friendRequests = []; sentRequestIDs = []; friendSince = [:]
        busyUserIDs = []; friendActionError = nil; lastPublishedStats = nil
        directoryCache = [:]; knownUsers = [:]; uidBySocialID = [:]
        guard let uid else { friendsState = .ready; return }
        friendsState = .loading
        friendshipListener = SocialDirectory.friendships(of: uid).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.cloudUID == uid else { return }
                if let error {
                    self.friendsState = .failed(SocialDirectoryError.isPermission(error)
                        ? SocialDirectoryError.notSetUp.localizedDescription
                        : error.localizedDescription)
                    return
                }
                guard let snapshot else { return }
                self.applyFriendships(snapshot.documents.map { ($0.documentID, $0.data()) }, uid: uid)
                self.friendsState = .ready
            }
        }
    }

    private func applyFriendships(_ docs: [(String, [String: Any])], uid: String, fetchMissing: Bool = true) {
        var accepted: [SocialUser] = [], incoming: [FriendRequest] = []
        var sent: Set<UUID> = [], since: [UUID: Date] = [:]
        var missing: [String] = []
        for (pairID, data) in docs {
            guard let from = data["fromUID"] as? String, let to = data["toUID"] as? String else { continue }
            let other = from == uid ? to : from
            let fallback = DirectoryProfile(
                uid: other,
                name: (from == uid ? data["toName"] : data["fromName"]) as? String ?? "Collector",
                handle: (from == uid ? data["toHandle"] : data["fromHandle"]) as? String ?? "")
            if directoryCache[other] == nil { missing.append(other) }
            let user = register(directoryCache[other] ?? fallback)
            switch data["status"] as? String ?? "" {
            case "accepted":
                accepted.append(user)
                since[user.id] = (data["acceptedAt"] as? Timestamp)?.dateValue()
            case "pending" where to == uid:
                incoming.append(FriendRequest(id: Self.socialID(pairID),
                                              sender: user, mutualCollectionCount: 0, mutualInterestCount: 0))
            case "pending":
                sent.insert(user.id)
            default: break
            }
        }
        friends = accepted.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        friendRequests = incoming
        sentRequestIDs = sent
        friendSince = since
        // Fill in bios and counts for people we only know by name so far.
        guard fetchMissing, !missing.isEmpty else { return }
        Task { @MainActor in
            for other in missing {
                guard self.cloudUID == uid, let profile = try? await SocialDirectory.profile(uid: other) else { continue }
                self.directoryCache[other] = profile
            }
            guard self.cloudUID == uid else { return }
            self.applyFriendships(docs, uid: uid, fetchMissing: false)
        }
    }

    // MARK: - Shared Collections

    @discardableResult
    func createSharedCollection(
        name: String,
        memberIDs: [UUID],
        itemIDs: [UUID],
        permission: SharedPermission
    ) -> SharedCollection {
        if cloudStarted {
            return createCloudCollection(name: name, itemIDs: itemIDs, permission: permission)
        }
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let collection = SharedCollection(
            name: trimmedName.isEmpty
                ? "Untitled Shared Collection"
                : trimmedName,
            ownerID: currentUserID,
            memberIDs: Array(
                Set([currentUserID] + memberIDs)
            ),
            itemIDs: itemIDs,
            permission: permission
        )

        sharedCollections.insert(collection, at: 0)

        let conversation = ChatConversation(
            kind: .sharedCollection,
            title: collection.name,
            participantIDs: collection.memberIDs,
            sharedCollectionID: collection.id
        )

        conversations.append(conversation)

        return collection
    }

    func addItem(
        _ itemID: UUID,
        to collectionID: UUID
    ) {
        if cloudStarted {
            Task { await publishSharedItem(itemID, collectionID: collectionID) }
            return
        }
        guard let index = sharedCollections.firstIndex(
            where: { $0.id == collectionID }
        ) else {
            return
        }

        guard sharedCollections[index]
            .itemIDs
            .contains(itemID) == false else {
            return
        }

        sharedCollections[index].itemIDs.append(itemID)
        sharedCollections[index].updatedAt = Date()
    }

    func seedSharedCollectionItems(
        from items: [CollectibleItem]
    ) {
        guard !cloudStarted else { return }
        guard let index = sharedCollections.firstIndex(
            where: {
                $0.id == DemoSocialIDs.weekendCollection
            }
        ) else {
            return
        }

        guard sharedCollections[index].itemIDs.isEmpty else {
            return
        }

        sharedCollections[index].itemIDs = Array(
            items.prefix(14).map(\.id)
        )
    }

    // MARK: - Conversations

    func messages(
        for conversation: ChatConversation
    ) -> [ChatMessage] {
        messages
            .filter {
                $0.conversationID == conversation.id
            }
            .sorted {
                $0.sentAt < $1.sentAt
            }
    }

    func directConversation(
        with friend: SocialUser
    ) -> ChatConversation {
        if let existingConversation = conversations.first(
            where: {
                $0.kind == .direct &&
                $0.participantIDs.contains(friend.id)
            }
        ) {
            return existingConversation
        }

        let conversation = ChatConversation(
            kind: .direct,
            title: friend.name,
            participantIDs: [
                currentUserID,
                friend.id
            ]
        )

        conversations.append(conversation)
        return conversation
    }

    func conversation(
        for collection: SharedCollection
    ) -> ChatConversation {
        if let existingConversation = conversations.first(
            where: {
                $0.sharedCollectionID == collection.id
            }
        ) {
            return existingConversation
        }

        let conversation = ChatConversation(
            kind: .sharedCollection,
            title: collection.name,
            participantIDs: collection.memberIDs,
            sharedCollectionID: collection.id
        )

        conversations.append(conversation)
        return conversation
    }

    func sendMessage(
        text: String,
        conversationID: UUID,
        attachedItemID: UUID? = nil
    ) {
        let trimmedText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard trimmedText.isEmpty == false ||
                attachedItemID != nil else {
            return
        }

        let message = ChatMessage(
            conversationID: conversationID,
            senderID: currentUserID,
            body: trimmedText,
            attachedItemID: attachedItemID
        )

        messages.append(message)
    }
}

// MARK: - Demo Collectors

/// Demo users shared by `SocialStore` and the local handle search,
/// so search results and friends refer to the same people.
enum DemoCollectors {
    static let mina = SocialUser(
        id: DemoSocialIDs.mina,
        name: "Mina Park",
        handle: "@minashelf",
        location: "Los Angeles",
        bio: "Analog sound, tiny paper treasures, and the stories behind both.",
        interests: [.vinyl, .photocard],
        objectCount: 64,
        collectionCount: 5,
        sharedCollectionCount: 7,
        avatarColorA: "D5B99C",
        avatarColorB: "B84631"
    )

    static let alex = SocialUser(
        id: DemoSocialIDs.alex,
        name: "Alex Rivera",
        handle: "@posterarchive",
        location: "Los Angeles",
        bio: "Collecting movie posters and visual memories.",
        interests: [.poster],
        objectCount: 38,
        collectionCount: 3,
        sharedCollectionCount: 4,
        avatarColorA: "727B70",
        avatarColorB: "262624"
    )

    static let yuki = SocialUser(
        id: DemoSocialIDs.yuki,
        name: "Yuki Sato",
        handle: "@yukicollects",
        location: "Tokyo",
        bio: "BJD, vinyl, and carefully preserved objects.",
        interests: [.bjd, .vinyl],
        objectCount: 51,
        collectionCount: 4,
        sharedCollectionCount: 2,
        avatarColorA: "C8B7A8",
        avatarColorB: "706B63"
    )

    static let jamie = SocialUser(
        id: DemoSocialIDs.jamie,
        name: "Jamie Chen",
        handle: "@jamiearchive",
        location: "New York",
        bio: "Photocards and music ephemera.",
        interests: [.photocard, .vinyl],
        objectCount: 29,
        collectionCount: 2,
        sharedCollectionCount: 1,
        avatarColorA: "D9D1C3",
        avatarColorB: "727B70"
    )

    /// Collectors who are not connected to the user yet.
    static let others: [SocialUser] = [
        SocialUser(
            id: DemoSocialIDs.noor,
            name: "Noor Haddad",
            handle: "@noorkeeps",
            location: "Chicago",
            bio: "Film posters, ticket stubs, and the songs from those nights.",
            interests: [.poster, .vinyl],
            objectCount: 47,
            collectionCount: 4,
            sharedCollectionCount: 1,
            avatarColorA: "B84631",
            avatarColorB: "262624"
        ),
        SocialUser(
            id: DemoSocialIDs.leo,
            name: "Leo Tanaka",
            handle: "@leo.dolls",
            location: "Osaka",
            bio: "Dollfie Dream and SD girls, photographed in good light.",
            interests: [.bjd],
            objectCount: 22,
            collectionCount: 2,
            sharedCollectionCount: 0,
            avatarColorA: "A68E9A",
            avatarColorB: "706B63"
        ),
        SocialUser(
            id: DemoSocialIDs.sofia,
            name: "Sofia Marin",
            handle: "@sofia_spins",
            location: "Seattle",
            bio: "City pop on vinyl and a binder of photocards.",
            interests: [.vinyl, .photocard],
            objectCount: 73,
            collectionCount: 5,
            sharedCollectionCount: 3,
            avatarColorA: "536D78",
            avatarColorB: "D5B99C"
        )
    ]

    static var all: [SocialUser] {
        [mina, alex, yuki, jamie] + others
    }
}

// MARK: - Stable Demo IDs

private enum DemoSocialIDs {
    static let currentUser = UUID(
        uuidString: "10000000-0000-0000-0000-000000000001"
    )!

    static let mina = UUID(
        uuidString: "20000000-0000-0000-0000-000000000001"
    )!

    static let alex = UUID(
        uuidString: "20000000-0000-0000-0000-000000000002"
    )!

    static let yuki = UUID(
        uuidString: "20000000-0000-0000-0000-000000000003"
    )!

    static let jamie = UUID(
        uuidString: "20000000-0000-0000-0000-000000000004"
    )!

    static let noor = UUID(
        uuidString: "20000000-0000-0000-0000-000000000005"
    )!

    static let leo = UUID(
        uuidString: "20000000-0000-0000-0000-000000000006"
    )!

    static let sofia = UUID(
        uuidString: "20000000-0000-0000-0000-000000000007"
    )!

    static let jamieRequest = UUID(
        uuidString: "30000000-0000-0000-0000-000000000001"
    )!

    static let weekendCollection = UUID(
        uuidString: "40000000-0000-0000-0000-000000000001"
    )!

    static let minaConversation = UUID(
        uuidString: "50000000-0000-0000-0000-000000000001"
    )!

    static let weekendConversation = UUID(
        uuidString: "50000000-0000-0000-0000-000000000002"
    )!

    static let messageOne = UUID(
        uuidString: "60000000-0000-0000-0000-000000000001"
    )!

    static let messageTwo = UUID(
        uuidString: "60000000-0000-0000-0000-000000000002"
    )!

    static let messageThree = UUID(
        uuidString: "60000000-0000-0000-0000-000000000003"
    )!

    static let messageFour = UUID(
        uuidString: "60000000-0000-0000-0000-000000000004"
    )!
}
