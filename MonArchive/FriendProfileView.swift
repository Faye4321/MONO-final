import SwiftUI

struct FriendProfileView: View {
    @EnvironmentObject private var socialStore: SocialStore

    let user: SocialUser
    @State private var confirmingRemove = false

    private var isFriend: Bool { socialStore.isFriend(user.id) }

    /// The collections this collector made public (from their profile).
    private var publicCollections: [DirectoryProfile.PublicCollection] {
        socialStore.directoryProfile(for: user.id)?.publicCollections ?? []
    }

    private var relationshipText: String? {
        if isFriend {
            if let since = socialStore.friendSince[user.id] {
                return "FRIENDS SINCE " + since.formatted(.dateTime.month(.abbreviated).year()).uppercased()
            }
            return "FRIENDS"
        }
        if socialStore.incomingRequest(from: user.id) != nil { return "WANTS TO BE FRIENDS" }
        if socialStore.hasSentRequest(to: user.id) { return "REQUEST SENT" }
        return nil
    }

    private var sharedWithUser: [SharedCollection] {
        socialStore.sharedCollections.filter { collection in
            collection.memberIDs.contains(user.id)
        }
    }

    var body: some View {
        ZStack {
            ArchiveTheme.ivory
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    statistics
                    actionButtons
                    FriendActionErrorBanner()
                    publicCollectionsSection
                    sharedCollectionsSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            ArchiveTheme.ivory,
            for: .navigationBar
        )
        .toolbarBackground(
            .visible,
            for: .navigationBar
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("COLLECTOR")
                    .font(ArchiveTheme.heading(17))
                    .foregroundStyle(ArchiveTheme.ink)
                    .tracking(0.8)
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isFriend {
                    Menu {
                        Button(role: .destructive) {
                            confirmingRemove = true
                        } label: {
                            Label("Remove Friend", systemImage: "person.badge.minus")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(ArchiveTheme.ink)
                            .frame(width: 40, height: 40)
                    }
                    .accessibilityLabel("More options")
                }
            }
        }
        .confirmationDialog("Remove \(user.name) as a friend?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove Friend", role: .destructive) { socialStore.removeFriend(user) }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            SocialAvatarView(
                user: user,
                size: 92
            )

            VStack(spacing: 4) {
                Text(user.name.uppercased())
                    .font(ArchiveTheme.heading(25))
                    .foregroundStyle(ArchiveTheme.ink)
                    .multilineTextAlignment(.center)

                Text([user.handle, user.location].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(ArchiveTheme.body(13))
                    .foregroundStyle(ArchiveTheme.catalogGray)

                Text(relationshipText ?? "")
                    .font(ArchiveTheme.label(9))
                    .foregroundStyle(
                        ArchiveTheme.collectedRed
                    )
                    .tracking(0.8)
                    .padding(.top, 2)
            }

            Text(user.bio)
                .font(ArchiveTheme.body(14))
                .foregroundStyle(
                    ArchiveTheme.ink.opacity(0.82)
                )
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    // MARK: - Statistics

    private var statistics: some View {
        HStack(spacing: 0) {
            FriendProfileStat(
                value: user.objectCount,
                label: "OBJECTS"
            )

            statisticDivider

            FriendProfileStat(
                value: user.collectionCount,
                label: "COLLECTIONS"
            )

            statisticDivider

            FriendProfileStat(
                value: sharedWithUser.count,
                label: "SHARED"
            )
        }
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    ArchiveTheme.catalogGray.opacity(0.10),
                    lineWidth: 1
                )
        }
        .padding(.top, 20)
    }

    private var statisticDivider: some View {
        Rectangle()
            .fill(
                ArchiveTheme.catalogGray.opacity(0.15)
            )
            .frame(width: 1, height: 35)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        if isFriend {
            friendActions
        } else {
            requestActions
        }
    }

    /// Not friends yet: Add friend, Requested (tap to cancel) or Accept / Decline.
    @ViewBuilder
    private var requestActions: some View {
        let busy = socialStore.isBusy(user.id)
        HStack(spacing: 10) {
            if let request = socialStore.incomingRequest(from: user.id) {
                profileButton("DECLINE", systemImage: "xmark", filled: false) { socialStore.declineFriendRequest(request) }
                profileButton("ACCEPT", systemImage: "checkmark", filled: true) { socialStore.acceptFriendRequest(request) }
            } else if socialStore.hasSentRequest(to: user.id) {
                profileButton("REQUESTED · CANCEL", systemImage: "clock", filled: false) { socialStore.cancelFriendRequest(to: user) }
            } else {
                profileButton("ADD FRIEND", systemImage: "person.badge.plus", filled: true) {
                    Haptics.light()
                    socialStore.sendFriendRequest(to: user)
                }
            }
        }
        .disabled(busy)
        .opacity(busy ? 0.6 : 1)
        .padding(.top, 12)
    }

    private func profileButton(_ title: String, systemImage: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(ArchiveTheme.label(11))
                .foregroundStyle(filled ? Color.white : ArchiveTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(filled ? ArchiveTheme.collectedRed : Color.white.opacity(0.74))
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay {
                    if !filled {
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(ArchiveTheme.catalogGray.opacity(0.16), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var friendActions: some View {
        HStack(spacing: 10) {
            NavigationLink {
                ChatView(friend: user)
            } label: {
                Label(
                    "CHAT",
                    systemImage: "message"
                )
                .font(ArchiveTheme.label(11))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    ArchiveTheme.collectedRed
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 15)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                CreateSharedCollectionView(
                    preselectedFriend: user
                )
            } label: {
                Label(
                    "CREATE SHARED",
                    systemImage: "folder.badge.plus"
                )
                .font(ArchiveTheme.label(11))
                .foregroundStyle(ArchiveTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white.opacity(0.74))
                .clipShape(
                    RoundedRectangle(cornerRadius: 15)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            ArchiveTheme.catalogGray.opacity(0.16),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    // MARK: - Public Collections

    private var publicCollectionsSection: some View {
        VStack(spacing: 12) {
            SocialSectionHeader(
                title: "PUBLIC COLLECTIONS",
                trailingText: "\(publicCollections.count)"
            )

            if publicCollections.isEmpty {
                Text("\(user.name) hasn't made any collections public yet.")
                    .font(ArchiveTheme.body(12))
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 3)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(publicCollections, id: \.self) { collection in
                        FriendPublicCollectionCard(
                            category: CollectionCategory(rawValue: collection.layout) ?? .poster,
                            title: collection.name,
                            objectCount: collection.count
                        )
                    }
                }
            }
        }
        .padding(.top, 26)
    }

    // MARK: - Shared Collections

    private var sharedCollectionsSection: some View {
        VStack(spacing: 12) {
            SocialSectionHeader(
                title: "SHARED WITH YOU",
                trailingText:
                    "\(sharedWithUser.count)"
            )

            if sharedWithUser.isEmpty {
                emptySharedCollection
            } else {
                ForEach(sharedWithUser) { collection in
                    NavigationLink {
                        SharedCollectionDetailView(collectionID: collection.id)
                    } label: {
                        FriendSharedCollectionRow(
                            collection: collection
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 26)
    }

    private var emptySharedCollection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 25))
                .foregroundStyle(
                    ArchiveTheme.catalogGray.opacity(0.5)
                )

            Text("NO SHARED COLLECTIONS")
                .font(ArchiveTheme.label(10))
                .foregroundStyle(
                    ArchiveTheme.catalogGray
                )
                .tracking(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Statistics

private struct FriendProfileStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(ArchiveTheme.heading(20))
                .foregroundStyle(ArchiveTheme.ink)

            Text(label)
                .font(ArchiveTheme.label(9))
                .foregroundStyle(
                    ArchiveTheme.catalogGray
                )
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Public Collection Card

private struct FriendPublicCollectionCard: View {
    let category: CollectionCategory
    var title: String? = nil
    let objectCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: category.systemImage)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .frame(height: 118)

            VStack(alignment: .leading, spacing: 3) {
                Text((title ?? category.title).uppercased())
                    .font(ArchiveTheme.label(9))
                    .foregroundStyle(ArchiveTheme.ink)
                    .lineLimit(1)

                Text("\(objectCount) OBJECTS")
                    .font(ArchiveTheme.label(8))
                    .foregroundStyle(
                        ArchiveTheme.catalogGray
                    )
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    ArchiveTheme.catalogGray.opacity(0.10),
                    lineWidth: 1
                )
        }
    }

    private var gradientColors: [Color] {
        switch category {
        case .vinyl:
            return [
                ArchiveTheme.collectedRed,
                ArchiveTheme.cabinet
            ]

        case .bjd:
            return [
                ArchiveTheme.paperTan,
                ArchiveTheme.catalogGray
            ]

        case .poster:
            return [
                ArchiveTheme.cabinet,
                ArchiveTheme.collectedRed.opacity(0.8)
            ]

        case .photocard:
            return [
                ArchiveTheme.catalogGray,
                ArchiveTheme.paperTan
            ]
        }
    }
}

// MARK: - Shared Collection Row

private struct FriendSharedCollectionRow: View {
    let collection: SharedCollection

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                LinearGradient(
                    colors: [
                        ArchiveTheme.collectedRed,
                        ArchiveTheme.cabinet
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(ArchiveTheme.heading(15))
                    .foregroundStyle(ArchiveTheme.ink)

                Text(
                    """
                    \(collection.itemIDs.count) objects · \
                    \(collection.memberIDs.count) members
                    """
                )
                .font(ArchiveTheme.body(11))
                .foregroundStyle(
                    ArchiveTheme.catalogGray
                )
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    ArchiveTheme.catalogGray.opacity(0.6)
                )
        }
        .padding(14)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    ArchiveTheme.catalogGray.opacity(0.09),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Temporary Destinations



private struct SharedCollectionCreatePlaceholder: View {
    let preselectedFriend: SocialUser

    var body: some View {
        ZStack {
            ArchiveTheme.ivory
                .ignoresSafeArea()

            Text(
                "Create a shared collection with \(preselectedFriend.name)"
            )
            .font(ArchiveTheme.heading(18))
            .foregroundStyle(ArchiveTheme.ink)
            .multilineTextAlignment(.center)
            .padding()
        }
        .navigationTitle("CREATE SHARED")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SharedCollectionPlaceholder: View {
    let collection: SharedCollection

    var body: some View {
        ZStack {
            ArchiveTheme.ivory
                .ignoresSafeArea()

            Text(collection.name)
                .font(ArchiveTheme.heading(22))
                .foregroundStyle(ArchiveTheme.ink)
        }
        .navigationTitle("SHARED")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    let socialStore = SocialStore()

    NavigationStack {
        FriendProfileView(
            user: socialStore.friends[0]
        )
        .environmentObject(socialStore)
    }
}
