import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var socialStore: SocialStore

    @State private var searchText = ""

    private var filteredFriends: [SocialUser] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard query.isEmpty == false else {
            return socialStore.friends
        }

        return socialStore.friends.filter { friend in
            friend.name.lowercased().contains(query) ||
            friend.handle.lowercased().contains(query) ||
            friend.interests.contains {
                $0.title.lowercased().contains(query)
            }
        }
    }

    var body: some View {
        ZStack {
            ArchiveTheme.ivory
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    searchBar

                    if socialStore.friendRequests.isEmpty == false {
                        requestsSection
                    }

                    friendsSection
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
                Text("FRIENDS")
                    .font(ArchiveTheme.heading(17))
                    .foregroundStyle(ArchiveTheme.ink)
                    .tracking(0.8)
            }

            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item:
                        """
                        Join me on MonArchive.
                        My invite code is SHUNING24.
                        """
                ) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ArchiveTheme.collectedRed)
                }
                .accessibilityLabel("Invite a friend")
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ArchiveTheme.catalogGray)

            TextField(
                "Search username or invite code",
                text: $searchText
            )
            .font(ArchiveTheme.body(14))
            .foregroundStyle(ArchiveTheme.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if searchText.isEmpty == false {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(
                            ArchiveTheme.catalogGray.opacity(0.65)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.white.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    ArchiveTheme.catalogGray.opacity(0.12),
                    lineWidth: 1
                )
        }
        .padding(.top, 12)
    }

    // MARK: - Requests

    private var requestsSection: some View {
        VStack(spacing: 12) {
            SocialSectionHeader(
                title: "REQUESTS",
                trailingText:
                    "\(socialStore.friendRequests.count)"
            )

            ForEach(socialStore.friendRequests) { request in
                FriendRequestCard(request: request)
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Friends

    private var friendsSection: some View {
        VStack(spacing: 12) {
            SocialSectionHeader(
                title: "YOUR FRIENDS",
                trailingText:
                    "\(filteredFriends.count)"
            )

            if filteredFriends.isEmpty {
                emptySearchResult
            } else {
                ForEach(filteredFriends) { friend in
                    NavigationLink {
                        FriendProfileView(user: friend)
                    } label: {
                        FriendRow(user: friend)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 24)
    }

    private var emptySearchResult: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.slash")
                .font(.system(size: 28))
                .foregroundStyle(
                    ArchiveTheme.catalogGray.opacity(0.55)
                )

            Text("NO COLLECTORS FOUND")
                .font(ArchiveTheme.label(11))
                .foregroundStyle(ArchiveTheme.catalogGray)
                .tracking(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.white.opacity(0.60))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Friend Request Card

private struct FriendRequestCard: View {
    @EnvironmentObject private var socialStore: SocialStore

    let request: FriendRequest

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                SocialAvatarView(
                    user: request.sender,
                    size: 52
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.sender.name)
                        .font(ArchiveTheme.heading(16))
                        .foregroundStyle(ArchiveTheme.ink)

                    Text(request.sender.handle)
                        .font(ArchiveTheme.body(12))
                        .foregroundStyle(
                            ArchiveTheme.catalogGray
                        )

                    Text(
                        """
                        \(request.mutualCollectionCount) shared collections · \
                        \(request.mutualInterestCount) shared interests
                        """
                    )
                    .font(ArchiveTheme.body(11))
                    .foregroundStyle(
                        ArchiveTheme.catalogGray
                    )
                    .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation {
                        socialStore.declineFriendRequest(request)
                    }
                } label: {
                    Text("DECLINE")
                        .font(ArchiveTheme.label(11))
                        .foregroundStyle(
                            ArchiveTheme.catalogGray
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            ArchiveTheme.ivory.opacity(0.8)
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 13)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation {
                        socialStore.acceptFriendRequest(request)
                    }
                } label: {
                    Text("ACCEPT")
                        .font(ArchiveTheme.label(11))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            ArchiveTheme.collectedRed
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 13)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 21))
        .overlay {
            RoundedRectangle(cornerRadius: 21)
                .stroke(
                    ArchiveTheme.catalogGray.opacity(0.10),
                    lineWidth: 1
                )
        }
        .shadow(
            color: ArchiveTheme.ink.opacity(0.04),
            radius: 10,
            y: 4
        )
    }
}

// MARK: - Friend Row

private struct FriendRow: View {
    let user: SocialUser

    private var interestText: String {
        user.interests
            .map(\.title)
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 13) {
            SocialAvatarView(
                user: user,
                size: 52
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(ArchiveTheme.heading(16))
                    .foregroundStyle(ArchiveTheme.ink)

                Text(user.handle)
                    .font(ArchiveTheme.body(12))
                    .foregroundStyle(
                        ArchiveTheme.catalogGray
                    )

                Text(interestText.uppercased())
                    .font(ArchiveTheme.label(9))
                    .foregroundStyle(
                        ArchiveTheme.collectedRed
                    )
                    .tracking(0.6)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    ArchiveTheme.catalogGray.opacity(0.65)
                )
        }
        .padding(15)
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

// MARK: - Reusable Social Avatar

struct SocialAvatarView: View {
    let user: SocialUser
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: user.avatarColorA),
                    Color(hex: user.avatarColorB)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(user.initials)
                .font(
                    ArchiveTheme.heading(
                        max(12, size * 0.29)
                    )
                )
                .foregroundStyle(Color.white)
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(
                cornerRadius: size * 0.30
            )
        )
    }
}

// MARK: - Reusable Section Header

struct SocialSectionHeader: View {
    let title: String
    let trailingText: String

    var body: some View {
        HStack {
            Text(title)
                .font(ArchiveTheme.heading(16))
                .foregroundStyle(ArchiveTheme.ink)
                .tracking(0.4)

            Spacer()

            Text(trailingText)
                .font(ArchiveTheme.label(10))
                .foregroundStyle(
                    ArchiveTheme.catalogGray
                )
                .tracking(0.7)
        }
        .padding(.horizontal, 3)
    }
}

// MARK: - Temporary Friend Page

private struct FriendPagePlaceholder: View {
    let user: SocialUser

    var body: some View {
        ZStack {
            ArchiveTheme.ivory
                .ignoresSafeArea()

            VStack(spacing: 14) {
                SocialAvatarView(
                    user: user,
                    size: 82
                )

                Text(user.name)
                    .font(ArchiveTheme.heading(24))
                    .foregroundStyle(ArchiveTheme.ink)

                Text("Friend profile will connect here next.")
                    .font(ArchiveTheme.body(13))
                    .foregroundStyle(
                        ArchiveTheme.catalogGray
                    )
            }
        }
        .navigationTitle(user.name.uppercased())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FriendsView()
            .environmentObject(SocialStore())
    }
}
