import Foundation
import FirebaseAuth
import FirebaseFirestore

// Gladys — friends and the public collector directory, backed by Firestore.
//
// profiles/{uid}           public profile: name, handle, bio, location,
//                          counts and public collections. Never the email.
// handles/{handle}         { uid } — one owner per handle.
// friendships/{a_b}        one document per pair of users (uids sorted), so
//                          two people can never create two relationships:
//                          { participants, fromUID, toUID, status, … }
//                          status is "pending" until the receiver accepts.
//
// The matching security rules are in cloud/firebase/firestore.rules and must
// be published to the mono-6d8ad project before these features work.

/// What other collectors can see about a user.
struct DirectoryProfile: Equatable, Identifiable {
    struct PublicCollection: Equatable, Hashable, Codable {
        var name: String
        var count: Int
        var layout: String
        /// Opens profiles/{uid}/collections/{id}; missing on older profiles.
        var id: String? = nil
    }

    var uid: String
    var name: String
    var handle: String
    var bio: String = ""
    var location: String = ""
    var objectCount = 0
    var collectionCount = 0
    var publicCollections: [PublicCollection] = []
    /// Small profile photo (AvatarCloud), if the user set one.
    var avatar: Data?

    var id: String { uid }

    init(uid: String, name: String, handle: String, bio: String = "", location: String = "",
         objectCount: Int = 0, collectionCount: Int = 0, publicCollections: [PublicCollection] = []) {
        self.uid = uid; self.name = name; self.handle = handle; self.bio = bio
        self.location = location; self.objectCount = objectCount
        self.collectionCount = collectionCount; self.publicCollections = publicCollections
    }

    init?(uid: String, data: [String: Any]) {
        guard let handle = data["handle"] as? String, !handle.isEmpty else { return nil }
        self.uid = uid
        self.handle = handle
        name = data["name"] as? String ?? "Collector"
        bio = data["bio"] as? String ?? ""
        location = data["location"] as? String ?? ""
        objectCount = data["objectCount"] as? Int ?? 0
        collectionCount = data["collectionCount"] as? Int ?? 0
        avatar = data["avatar"] as? Data
        publicCollections = (data["publicCollections"] as? [[String: Any]] ?? []).compactMap { entry in
            guard let name = entry["name"] as? String else { return nil }
            return PublicCollection(name: name, count: entry["count"] as? Int ?? 0,
                                    layout: entry["layout"] as? String ?? "", id: entry["id"] as? String)
        }
    }

    var fields: [String: Any] {
        [
            "name": name, "handle": handle, "bio": bio, "location": location,
            "objectCount": objectCount, "collectionCount": collectionCount,
            "publicCollections": publicCollections.map {
                ["name": $0.name, "count": $0.count, "layout": $0.layout, "id": $0.id ?? ""] as [String: Any]
            },
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

enum SocialDirectoryError: LocalizedError {
    case notSignedIn
    case notSetUp
    case cannotAddSelf

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "Sign in to use friends."
        case .notSetUp: "Friends aren't set up on the server yet. Ask the project owner to publish the latest Firestore rules."
        case .cannotAddSelf: "That's you."
        }
    }

    /// Firestore's "missing or insufficient permissions" means the rules for
    /// these collections haven't been published yet (or the action isn't allowed).
    static func isPermission(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == FirestoreErrorDomain && ns.code == FirestoreErrorCode.Code.permissionDenied.rawValue
    }
}

enum SocialDirectory {
    private static var db: Firestore { Firestore.firestore() }

    static var currentUID: String? { Auth.auth().currentUser?.uid }

    static func pairID(_ a: String, _ b: String) -> String {
        a < b ? a + "_" + b : b + "_" + a
    }

    // MARK: Handles

    /// True when nobody else owns `handle`.
    static func isHandleAvailable(_ handle: String) async throws -> Bool {
        guard let uid = currentUID else { throw SocialDirectoryError.notSignedIn }
        do {
            let doc = try await db.collection("handles").document(handle).getDocument()
            guard let owner = doc.data()?["uid"] as? String else { return true }
            return owner == uid
        } catch where SocialDirectoryError.isPermission(error) {
            throw SocialDirectoryError.notSetUp
        }
    }

    /// Claims the handle (releasing the old one) and publishes the public
    /// profile in one batch. Fails with `.handleTaken` if someone owns it.
    static func publish(_ profile: DirectoryProfile) async throws {
        guard let uid = currentUID, uid == profile.uid else { throw SocialDirectoryError.notSignedIn }
        let profileRef = db.collection("profiles").document(uid)
        do {
            let existing = try await profileRef.getDocument()
            let oldHandle = existing.data()?["handle"] as? String ?? ""
            if !profile.handle.isEmpty, try await isHandleAvailable(profile.handle) == false {
                throw ProfileServiceError.handleTaken
            }
            let batch = db.batch()
            if !profile.handle.isEmpty, profile.handle != oldHandle {
                batch.setData(["uid": uid], forDocument: db.collection("handles").document(profile.handle))
            }
            if !oldHandle.isEmpty, oldHandle != profile.handle {
                batch.deleteDocument(db.collection("handles").document(oldHandle))
            }
            if profile.handle.isEmpty {
                // No handle means not discoverable.
                batch.deleteDocument(profileRef)
            } else {
                // Merge, so the counts kept current by updateStats survive.
                batch.setData([
                    "name": profile.name, "handle": profile.handle,
                    "bio": profile.bio, "location": profile.location,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: profileRef, merge: true)
            }
            try await batch.commit()
        } catch where SocialDirectoryError.isPermission(error) {
            // Either the rules aren't published, or the handle was claimed
            // a moment ago by someone else.
            if !profile.handle.isEmpty, (try? await isHandleAvailable(profile.handle)) == false {
                throw ProfileServiceError.handleTaken
            }
            throw SocialDirectoryError.notSetUp
        }
    }

    /// Updates only the counts and public collections, if the profile exists.
    static func updateStats(objectCount: Int, collectionCount: Int,
                            publicCollections: [DirectoryProfile.PublicCollection]) async throws {
        guard let uid = currentUID else { return }
        try await db.collection("profiles").document(uid).updateData([
            "objectCount": objectCount, "collectionCount": collectionCount,
            "publicCollections": publicCollections.map {
                ["name": $0.name, "count": $0.count, "layout": $0.layout, "id": $0.id ?? ""] as [String: Any]
            },
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: Lookup

    /// Registered collectors whose handle starts with `prefix` (already
    /// normalized: no "@", lowercased). The current user is left out.
    static func search(prefix: String) async throws -> [DirectoryProfile] {
        guard let uid = currentUID else { throw SocialDirectoryError.notSignedIn }
        guard !prefix.isEmpty else { return [] }
        do {
            let snapshot = try await db.collection("profiles")
                .whereField("handle", isGreaterThanOrEqualTo: prefix)
                .whereField("handle", isLessThan: prefix + "\u{f8ff}")
                .order(by: "handle")
                .limit(to: 20)
                .getDocuments()
            return snapshot.documents
                .filter { $0.documentID != uid }
                .compactMap { DirectoryProfile(uid: $0.documentID, data: $0.data()) }
        } catch where SocialDirectoryError.isPermission(error) {
            throw SocialDirectoryError.notSetUp
        }
    }

    static func profile(uid: String) async throws -> DirectoryProfile? {
        let doc = try await db.collection("profiles").document(uid).getDocument()
        return doc.data().flatMap { DirectoryProfile(uid: uid, data: $0) }
    }

    static func profile(handle: String) async throws -> DirectoryProfile? {
        let doc = try await db.collection("handles").document(handle).getDocument()
        guard let uid = doc.data()?["uid"] as? String else { return nil }
        return try await profile(uid: uid)
    }

    // MARK: Friendships

    static func friendships(of uid: String) -> Query {
        db.collection("friendships").whereField("participants", arrayContains: uid)
    }

    static func sendRequest(to other: DirectoryProfile, from me: DirectoryProfile) async throws {
        guard me.uid != other.uid else { throw SocialDirectoryError.cannotAddSelf }
        let pair = [me.uid, other.uid].sorted()
        // Creating fails if the pair already has a document, so a repeated
        // tap or two people adding each other at once can't make two.
        try await db.collection("friendships").document(pairID(me.uid, other.uid)).setData([
            "participants": pair,
            "fromUID": me.uid, "toUID": other.uid,
            "fromName": me.name, "fromHandle": me.handle,
            "toName": other.name, "toHandle": other.handle,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    static func accept(pairID: String) async throws {
        try await db.collection("friendships").document(pairID).updateData([
            "status": "accepted",
            "acceptedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Decline, cancel and unfriend all remove the pair's document.
    static func remove(pairID: String) async throws {
        try await db.collection("friendships").document(pairID).delete()
    }
}
