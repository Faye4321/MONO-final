import SwiftUI
import UIKit

struct CreateSharedCollectionView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var socialStore: SocialStore
    @EnvironmentObject private var collectionStore: CollectionStore

    let preselectedFriend: SocialUser?

    @State private var collectionName = ""
    @State private var selectedFriendIDs: Set<UUID>
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var permission: SharedPermission =
        .everyoneCanAdd

    init(preselectedFriend: SocialUser? = nil) {
        self.preselectedFriend = preselectedFriend

        let initialIDs: Set<UUID>

        if let preselectedFriend {
            initialIDs = [preselectedFriend.id]
        } else {
            initialIDs = []
        }

        _selectedFriendIDs = State(
            initialValue: initialIDs
        )
    }

    private var canCreate: Bool {
        let name = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 150 && !socialStore.cloudBusy
    }

    var body: some View {
        ZStack {
            ArchiveTheme.ivory
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    nameSection
                    Text("Create your collection, then use Share Invitation to invite friends. They join using their own account.")
                        .font(ArchiveTheme.body(13))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .padding(.vertical, 20)
                    permissionSection
                    objectsSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            createButton
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
                Text("CREATE SHARED")
                    .font(ArchiveTheme.heading(16))
                    .foregroundStyle(ArchiveTheme.ink)
                    .tracking(0.7)
            }
        }
    }

    // MARK: - Collection Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COLLECTION NAME")
                .font(ArchiveTheme.label(11))
                .foregroundStyle(
                    ArchiveTheme.catalogGray
                )
                .tracking(0.8)

            TextField(
                "Weekend Record Hunt",
                text: $collectionName
            )
            .font(ArchiveTheme.body(15))
            .foregroundStyle(ArchiveTheme.ink)
            .padding(.horizontal, 15)
            .frame(height: 52)
            .background(Color.white.opacity(0.78))
            .clipShape(
                RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        ArchiveTheme.catalogGray.opacity(0.12),
                        lineWidth: 1
                    )
            }
        }
        .padding(.top, 18)
    }

    // MARK: - Invite Friends

    private var friendsSection: some View {
        VStack(spacing: 12) {
            SocialSectionHeader(
                title: "INVITE FRIENDS",
                trailingText:
                    "\(selectedFriendIDs.count) SELECTED"
            )

            ForEach(socialStore.friends) { friend in
                Button {
                    toggleFriend(friend)
                } label: {
                    friendSelectionRow(friend)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 28)
    }

    private func friendSelectionRow(
        _ friend: SocialUser
    ) -> some View {
        let isSelected = selectedFriendIDs.contains(
            friend.id
        )

        return HStack(spacing: 12) {
            SocialAvatarView(
                user: friend,
                size: 48
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.name)
                    .font(ArchiveTheme.heading(15))
                    .foregroundStyle(ArchiveTheme.ink)

                Text(friend.handle)
                    .font(ArchiveTheme.body(11))
                    .foregroundStyle(
                        ArchiveTheme.catalogGray
                    )
            }

            Spacer()

            Image(
                systemName:
                    isSelected
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .font(.system(size: 21))
            .foregroundStyle(
                isSelected
                ? ArchiveTheme.collectedRed
                : ArchiveTheme.catalogGray.opacity(0.45)
            )
        }
        .padding(13)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isSelected
                    ? ArchiveTheme.collectedRed.opacity(0.35)
                    : ArchiveTheme.catalogGray.opacity(0.09),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Permissions

    private var permissionSection: some View {
        VStack(spacing: 12) {
            SocialSectionHeader(
                title: "MEMBER PERMISSIONS",
                trailingText: ""
            )

            ForEach(SharedPermission.allCases) { option in
                Button {
                    permission = option
                } label: {
                    permissionRow(option)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 28)
    }

    private func permissionRow(
        _ option: SharedPermission
    ) -> some View {
        let isSelected = permission == option

        return HStack(spacing: 12) {
            Image(
                systemName:
                    option == .everyoneCanAdd
                    ? "person.2.fill"
                    : "person.fill"
            )
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(
                isSelected
                ? ArchiveTheme.collectedRed
                : ArchiveTheme.catalogGray
            )
            .frame(width: 30)

            Text(option.title)
                .font(ArchiveTheme.body(14))
                .foregroundStyle(ArchiveTheme.ink)

            Spacer()

            Image(
                systemName:
                    isSelected
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .font(.system(size: 20))
            .foregroundStyle(
                isSelected
                ? ArchiveTheme.collectedRed
                : ArchiveTheme.catalogGray.opacity(0.45)
            )
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(
                    isSelected
                    ? ArchiveTheme.collectedRed.opacity(0.30)
                    : ArchiveTheme.catalogGray.opacity(0.09),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Objects

    private var objectsSection: some View {
        VStack(spacing: 12) {
            SocialSectionHeader(
                title: "OBJECTS",
                trailingText:
                    "\(selectedItemIDs.count) SELECTED"
            )

            if collectionStore.items.isEmpty {
                emptyObjects
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .flexible(),
                            spacing: 10
                        ),
                        GridItem(
                            .flexible(),
                            spacing: 10
                        ),
                        GridItem(
                            .flexible(),
                            spacing: 10
                        )
                    ],
                    spacing: 12
                ) {
                    ForEach(collectionStore.items) { item in
                        Button {
                            toggleItem(item)
                        } label: {
                            SharedObjectSelectionCard(
                                item: item,
                                isSelected:
                                    selectedItemIDs.contains(
                                        item.id
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 28)
    }

    private var emptyObjects: some View {
        VStack(spacing: 10) {
            Image(systemName: "archivebox")
                .font(.system(size: 28))
                .foregroundStyle(
                    ArchiveTheme.catalogGray.opacity(0.5)
                )

            Text("NO OBJECTS AVAILABLE")
                .font(ArchiveTheme.label(10))
                .foregroundStyle(
                    ArchiveTheme.catalogGray
                )
                .tracking(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color.white.opacity(0.60))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            createCollection()
        } label: {
            Text("CREATE & SEND INVITES")
                .font(ArchiveTheme.label(12))
                .foregroundStyle(Color.white)
                .tracking(0.5)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    canCreate
                    ? ArchiveTheme.collectedRed
                    : ArchiveTheme.catalogGray.opacity(0.35)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 17)
                )
        }
        .buttonStyle(.plain)
        .disabled(canCreate == false)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            ArchiveTheme.ivory.opacity(0.97)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    ArchiveTheme.catalogGray.opacity(0.12)
                )
                .frame(height: 1)
        }
    }

    // MARK: - Actions

    private func toggleFriend(
        _ friend: SocialUser
    ) {
        if selectedFriendIDs.contains(friend.id) {
            selectedFriendIDs.remove(friend.id)
        } else {
            selectedFriendIDs.insert(friend.id)
        }
    }

    private func toggleItem(
        _ item: CollectibleItem
    ) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    private func createCollection() {
        socialStore.createSharedCollection(
            name: collectionName,
            memberIDs: Array(selectedFriendIDs),
            itemIDs: Array(selectedItemIDs),
            permission: permission
        )

        dismiss()
    }
}

// MARK: - Object Selection Card

private struct SharedObjectSelectionCard: View {
    let item: CollectibleItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                artwork
                    .frame(maxWidth: .infinity)
                    .aspectRatio(
                        item.category.artworkAspectRatio,
                        contentMode: .fit
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 11)
                    )

                Image(
                    systemName:
                        isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.system(size: 20))
                .foregroundStyle(
                    isSelected
                    ? ArchiveTheme.collectedRed
                    : Color.white.opacity(0.92)
                )
                .background(
                    Circle()
                        .fill(
                            isSelected
                            ? Color.white
                            : ArchiveTheme.ink.opacity(0.25)
                        )
                )
                .padding(7)
            }

            Text(item.title)
                .font(ArchiveTheme.heading(11))
                .foregroundStyle(ArchiveTheme.ink)
                .lineLimit(1)

            Text(item.creator.uppercased())
                .font(ArchiveTheme.label(7))
                .foregroundStyle(
                    ArchiveTheme.catalogGray
                )
                .lineLimit(1)
        }
        .padding(8)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    isSelected
                    ? ArchiveTheme.collectedRed.opacity(0.45)
                    : ArchiveTheme.catalogGray.opacity(0.08),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let uiImage = item.uploadedImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let imageName = item.imageName,
                  let uiImage = UIImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: item.colorA),
                        Color(hex: item.colorB)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: item.category.systemImage)
                    .font(.system(size: 23))
                    .foregroundStyle(Color.white)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let socialStore = SocialStore()

    NavigationStack {
        CreateSharedCollectionView(
            preselectedFriend:
                socialStore.friends.first
        )
        .environmentObject(socialStore)
        .environmentObject(CollectionStore())
    }
}
