import Foundation

// MARK: - Social User

struct SocialUser: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var handle: String
    var location: String
    var bio: String
    var interests: [CollectionCategory]

    var objectCount: Int
    var collectionCount: Int
    var sharedCollectionCount: Int

    var avatarColorA: String
    var avatarColorB: String

    init(
        id: UUID = UUID(),
        name: String,
        handle: String,
        location: String,
        bio: String,
        interests: [CollectionCategory],
        objectCount: Int,
        collectionCount: Int,
        sharedCollectionCount: Int,
        avatarColorA: String,
        avatarColorB: String
    ) {
        self.id = id
        self.name = name
        self.handle = handle
        self.location = location
        self.bio = bio
        self.interests = interests
        self.objectCount = objectCount
        self.collectionCount = collectionCount
        self.sharedCollectionCount = sharedCollectionCount
        self.avatarColorA = avatarColorA
        self.avatarColorB = avatarColorB
    }

    var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)

        let letters = parts.compactMap(\.first)

        return letters.isEmpty
            ? "M"
            : letters.map(String.init).joined().uppercased()
    }
}

// MARK: - Friend Request

enum FriendRequestStatus: String, Hashable, Codable {
    case pending
    case accepted
    case declined
}

struct FriendRequest: Identifiable, Hashable, Codable {
    let id: UUID
    var sender: SocialUser
    var mutualCollectionCount: Int
    var mutualInterestCount: Int
    var status: FriendRequestStatus

    init(
        id: UUID = UUID(),
        sender: SocialUser,
        mutualCollectionCount: Int,
        mutualInterestCount: Int,
        status: FriendRequestStatus = .pending
    ) {
        self.id = id
        self.sender = sender
        self.mutualCollectionCount = mutualCollectionCount
        self.mutualInterestCount = mutualInterestCount
        self.status = status
    }
}

// MARK: - Shared Collection

enum SharedPermission: String, CaseIterable, Identifiable, Hashable, Codable {
    case everyoneCanAdd
    case ownerOnly

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .everyoneCanAdd:
            return "Everyone can add objects"
        case .ownerOnly:
            return "Only I can add objects"
        }
    }
}

struct SharedCollection: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var ownerID: UUID
    var memberIDs: [UUID]
    var itemIDs: [UUID]
    var permission: SharedPermission
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        ownerID: UUID,
        memberIDs: [UUID],
        itemIDs: [UUID],
        permission: SharedPermission,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.memberIDs = memberIDs
        self.itemIDs = itemIDs
        self.permission = permission
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Conversations

enum ConversationKind: String, Hashable, Codable {
    case direct
    case sharedCollection
}

struct ChatConversation: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: ConversationKind
    var title: String
    var participantIDs: [UUID]
    var sharedCollectionID: UUID?

    init(
        id: UUID = UUID(),
        kind: ConversationKind,
        title: String,
        participantIDs: [UUID],
        sharedCollectionID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.participantIDs = participantIDs
        self.sharedCollectionID = sharedCollectionID
    }
}

// MARK: - Messages

struct ChatMessage: Identifiable, Hashable, Codable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    var body: String
    var sentAt: Date
    var attachedItemID: UUID?

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        senderID: UUID,
        body: String,
        sentAt: Date = Date(),
        attachedItemID: UUID? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.body = body
        self.sentAt = sentAt
        self.attachedItemID = attachedItemID
    }
}
