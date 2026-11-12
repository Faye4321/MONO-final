import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var socialStore: SocialStore
    @ObservedObject private var profileStore = ProfileStore.shared

    @State private var searchText = ""
    @State private var searchState: SearchState = .idle

    enum SearchState: Equatable {
        case idle
        case loading
        case loaded([SocialUser])
        case failed(String)
    }

    private var query: String {
        HandleRules.normalized(searchText)
    }

    private var isSearching: Bool { !query.isEmpty }

    private var filteredFriends: [SocialUser] {
        guard isSearching else { return socialStore.friends }

        return socialStore.friends.filter { friend in
            HandleRules.normalized(friend.handle).contains(query) ||
            friend.name.lowercased().contains(query) ||
            friend.interests.contains {
                $0.title.lowercased().contains(query)
            }
        }
    }

    /// Search results that aren't already friends (friends show above).
    private var otherCollectors: [SocialUser] {
        guard case .loaded(let users) = searchState else { return [] }
        return users.filter { socialStore.isFriend($0.id) == false }
    }

    private var inviteText: String {
        if let url = profileStore.shareURL {
            return "Join me on MONO and see my collection: \(url.absoluteString)"
        }
        return "Join me on MONO, a home for everything you collect."
    }

    var body: some View {
        ZStack {
            ArchiveTheme.ivory
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    searchBar

                    if isSearching {
                        searchResults
                    } else {
                        if socialStore.friendRequests.isEmpty == false {
                            requestsSection
                        }
                        friendsSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
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
                ShareLink(item: inviteText) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ArchiveTheme.collectedRed)
                }
                .accessibilityLabel("Invite a friend")
            }
        }
        .task(id: query) { await runSearch() }
        .task { await profileStore.loadIfNeeded() }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ArchiveTheme.catalogGray)

            TextField(
                "Search by @handle",
                text: $searchText
            )
            .font(ArchiveTheme.body(14))
            .foregroundStyle(ArchiveTheme.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)

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

    private func runSearch() async {
        let current = query
        guard !current.isEmpty else {
            searchState = .idle
            return
        }
        searchState = .loading
        // Wait until the user pauses typing.
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        do {
            let users = try await profileStore.searchUsers(matching: current)
            guard !Task.isCancelled else { return }
            searchState = .loaded(users)
        } catch {
            guard !Task.isCancelled else { return }
            searchState = .failed(error.localizedDescription)
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if filteredFriends.isEmpty == false {
            VStack(spacing: 12) {
                SocialSectionHeader(
                    title: "YOUR FRIENDS",
                    trailingText: "\(filteredFriends.count)"
                )
                ForEach(filteredFriends) { friend in
                    NavigationLink {
                        FriendProfileView(user: friend)
                    } label: {
                        FriendRow(user: friend)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 24)
        }

        VStack(spacing: 12) {
            SocialSectionHeader(
                title: "COLLECTORS ON MONO",
                trailingText: searchState == .loading ? "" : "\(otherCollectors.count)"
            )

            switch searchState {
            case .idle, .loading:
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(ArchiveTheme.collectedRed)
                    Text("Searching for \(HandleRules.display(query))…")
                        .font(ArchiveTheme.body(13))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color.white.opacity(0.60))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            case .failed(let message):
                SocialStateCard(
                    systemImage: "wifi.exclamationmark",
                    title: "SEARCH DIDN'T WORK",
                    message: message,
                    actionTitle: "TRY AGAIN"
                ) {
                    Task { await runSearch() }
                }

            case .loaded:
                if otherCollectors.isEmpty {
                    if filteredFriends.isEmpty {
                        SocialStateCard(
                            systemImage: "person.slash",
                            title: "NO COLLECTORS FOUND",
                            message: "Check the spelling of \(HandleRules.display(query)), or invite them to MONO."
                        )
                    } else {
                        Text("No one else matches \(HandleRules.display(query)).")
                            .font(ArchiveTheme.body(12))
                            .foregroundStyle(ArchiveTheme.catalogGray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 3)
                    }
                } else {
                    ForEach(otherCollectors) { user in
                        CollectorSearchRow(user: user)
                    }
                }
            }
        }
        .padding(.top, 24)
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
                    "\(socialStore.friends.count)"
            )

            if socialStore.friends.isEmpty {
                SocialStateCard(
                    systemImage: "person.2",
                    title: "NO FRIENDS YET",
                    message: "Search a handle above to find collectors you know."
                )
            } else {
                ForEach(socialStore.friends) { friend in
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
}

// MARK: - Search Result Row

private struct CollectorSearchRow: View {
    @EnvironmentObject private var socialStore: SocialStore

    let user: SocialUser

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink {
                FriendProfileView(user: user)
            } label: {
                HStack(spacing: 13) {
                    SocialAvatarView(user: user, size: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(ArchiveTheme.heading(16))
                            .foregroundStyle(ArchiveTheme.ink)
                            .lineLimit(1)
                        Text(user.handle)
                            .font(ArchiveTheme.body(12))
                            .foregroundStyle(ArchiveTheme.catalogGray)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            actionButton
        }
        .padding(15)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(ArchiveTheme.catalogGray.opacity(0.09), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let request = socialStore.incomingRequest(from: user.id) {
            pill("ACCEPT", filled: true) {
                withAnimation { socialStore.acceptFriendRequest(request) }
            }
            .accessibilityLabel("Accept friend request from \(user.name)")
        } else if socialStore.hasSentRequest(to: user.id) {
            pill("REQUESTED", filled: false) {
                withAnimation { socialStore.cancelFriendRequest(to: user) }
            }
            .accessibilityLabel("Cancel friend request to \(user.name)")
        } else {
            pill("ADD", filled: true) {
                Haptics.light()
                withAnimation { socialStore.sendFriendRequest(to: user) }
            }
            .accessibilityLabel("Send friend request to \(user.name)")
        }
    }

    private func pill(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ArchiveTheme.label(10))
                .tracking(0.6)
                .foregroundStyle(filled ? Color.white : ArchiveTheme.catalogGray)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    filled ? ArchiveTheme.collectedRed : ArchiveTheme.ivory,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty / Error Card

struct SocialStateCard: View {
    let systemImage: String
    let title: String
    var message: String = ""
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(
                    ArchiveTheme.catalogGray.opacity(0.55)
                )

            Text(title)
                .font(ArchiveTheme.label(11))
                .foregroundStyle(ArchiveTheme.catalogGray)
                .tracking(0.7)

            if !message.isEmpty {
                Text(message)
                    .font(ArchiveTheme.body(12))
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(ArchiveTheme.label(10))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(ArchiveTheme.collectedRed, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
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
