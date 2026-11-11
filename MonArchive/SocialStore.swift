import SwiftUI

@MainActor
final class SocialStore: ObservableObject {
    let currentUserID = DemoSocialIDs.currentUser

    @Published var friends: [SocialUser]
    @Published var friendRequests: [FriendRequest]
    @Published var sharedCollections: [SharedCollection]
    @Published var conversations: [ChatConversation]
    @Published var messages: [ChatMessage]

    /// Collectors the user has sent a friend request to (local only for now).
    @Published private(set) var sentRequestIDs: Set<UUID> = []

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
            ownerID: currentUserID,
            memberIDs: [
                currentUserID,
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
                currentUserID,
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
                senderID: currentUserID,
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

    // MARK: - Users

    func user(withID id: UUID) -> SocialUser? {
        friends.first { $0.id == id }
            ?? friendRequests
                .map(\.sender)
                .first { $0.id == id }
            ?? DemoCollectors.all.first { $0.id == id }
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

    // TODO(Fei): replace with the Firebase friend-request call.
    func sendFriendRequest(to user: SocialUser) {
        guard isFriend(user.id) == false else { return }
        sentRequestIDs.insert(user.id)
    }

    func cancelFriendRequest(to user: SocialUser) {
        sentRequestIDs.remove(user.id)
    }

    func acceptFriendRequest(_ request: FriendRequest) {
        if friends.contains(where: { $0.id == request.sender.id }) == false {
            friends.append(request.sender)
        }

        friendRequests.removeAll {
            $0.id == request.id
        }
    }

    func declineFriendRequest(_ request: FriendRequest) {
        friendRequests.removeAll {
            $0.id == request.id
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
