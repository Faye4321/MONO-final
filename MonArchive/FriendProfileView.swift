import SwiftUI

struct FriendProfileView: View {
    @EnvironmentObject private var socialStore: SocialStore

    let user: SocialUser

    private var publicCategories: [CollectionCategory] {
        var categories = user.interests

        for category in CollectionCategory.allCases {
            if categories.contains(category) == false {
                categories.append(category)
            }
        }

        return Array(categories.prefix(3))
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
                Menu {
                    Button {
                        // Prototype action
                    } label: {
                        Label(
                            "Mute",
                            systemImage: "bell.slash"
                        )
                    }

                    Button {
                        // Prototype action
                    } label: {
                        Label(
                            "Remove Friend",
                            systemImage: "person.badge.minus"
                        )
                    }

                    Button(role: .destructive) {
                        // Prototype action
                    } label: {
                        Label(
                            "Block or Report",
                            systemImage: "exclamationmark.triangle"
                        )
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

                Text("\(user.handle) · \(user.location)")
                    .font(ArchiveTheme.body(13))
                    .foregroundStyle(ArchiveTheme.catalogGray)

                Text("FRIENDS SINCE OCT 2026")
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
                value: user.sharedCollectionCount,
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

    private var actionButtons: some View {
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
                trailingText:
                    "\(user.collectionCount)"
            )

            HStack(spacing: 10) {
                ForEach(publicCategories) { category in
                    FriendPublicCollectionCard(
                        category: category,
                        objectCount: estimatedCount(
                            for: category
                        )
                    )
                }
            }
        }
        .padding(.top, 26)
    }

    private func estimatedCount(
        for category: CollectionCategory
    ) -> Int {
        let divisor = max(
            user.collectionCount,
            1
        )

        let baseCount = max(
            user.objectCount / divisor,
            1
        )

        guard let index = publicCategories.firstIndex(
            of: category
        ) else {
            return baseCount
        }

        return max(baseCount - index, 1)
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
                Text(category.title.uppercased())
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
