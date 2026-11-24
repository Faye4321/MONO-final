import SwiftUI
import UIKit

struct SharedCollectionDetailView: View {
    @EnvironmentObject private var socialStore: SocialStore
    @EnvironmentObject private var collectionStore: CollectionStore
    @Environment(\.dismiss) private var dismiss

    let collectionID: UUID

    @State private var showingItemPicker = false
    /// Owner only: the member waiting on the remove confirmation.
    @State private var memberPendingRemoval: SocialUser?
    /// Owner only: the member whose removal is in flight.
    @State private var removingMemberID: UUID?
    /// Member only: the leave confirmation and its in-flight state.
    @State private var confirmingLeave = false
    @State private var isLeaving = false
    @State private var membershipError: String?

    private var sharedCollection: SharedCollection? {
        socialStore.sharedCollections.first {
            $0.id == collectionID
        }
    }

    private var collectionItems: [CollectibleItem] {
        guard let sharedCollection else { return [] }

        if let remote = socialStore.cloudItems[collectionID] { return remote }
        return collectionStore.items.filter {
            sharedCollection.itemIDs.contains($0.id)
        }
    }

    private var canAddItems: Bool {
        guard let sharedCollection else { return false }
        return sharedCollection.permission == .everyoneCanAdd || sharedCollection.ownerID == socialStore.currentUserID
    }

    /// Only the owner can remove people, and never themselves or the owner.
    private func canRemove(_ member: SocialUser, from collection: SharedCollection) -> Bool {
        socialStore.isOwner(of: collection)
            && member.id != socialStore.currentUserID
            && member.id != collection.ownerID
    }

    var body: some View {
        ZStack {
            ArchiveTheme.ivory
                .ignoresSafeArea()

            if let sharedCollection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        collectionHeader(sharedCollection)
                        memberSection(sharedCollection)
                        objectSection(sharedCollection)

                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, MonoTabBar.contentBottomInset)
                }
            } else {
                unavailableView
            }
        }
        .navigationTitle("SHARED")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let sharedCollection {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Each link works once; after it's used a new one is made.
                        if let invitation = socialStore.invitation(for: sharedCollection.id) {
                            ShareLink(item: invitation) {
                                Label("Share Invitation", systemImage: "square.and.arrow.up")
                            }
                        } else {
                            Label("Creating a new invitation…", systemImage: "hourglass")
                                .foregroundStyle(ArchiveTheme.catalogGray)
                        }

                        Button {
                            showingItemPicker = true
                        } label: {
                            Label("Add Object", systemImage: "plus")
                        }
                        .disabled(!canAddItems)

                        // Owners delete instead; only members can leave.
                        if !socialStore.isOwner(of: sharedCollection) {
                            Divider()

                            Button(role: .destructive) {
                                membershipError = nil
                                confirmingLeave = true
                            } label: {
                                Label("Leave Collection", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                            .disabled(isLeaving)
                        }
                    } label: {
                        if isLeaving {
                            ProgressView()
                        } else {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(ArchiveTheme.ink)
                        }
                    }
                    .disabled(isLeaving)
                }
            }
        }
        .confirmationDialog(
            "Remove \(memberPendingRemoval?.name ?? "this member")?",
            isPresented: Binding(
                get: { memberPendingRemoval != nil },
                set: { if !$0 { memberPendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: memberPendingRemoval
        ) { member in
            Button("Remove from Collection", role: .destructive) { remove(member) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("They'll lose access to this collection. Objects they added stay.")
        }
        .confirmationDialog(
            "Leave \(sharedCollection?.name ?? "this collection")?",
            isPresented: $confirmingLeave,
            titleVisibility: .visible
        ) {
            Button("Leave Collection", role: .destructive) { leave() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll lose access until someone invites you again.")
        }
        .sheet(isPresented: $showingItemPicker) {
            SharedCollectionItemPicker(collectionID: collectionID)
                .environmentObject(socialStore)
                .environmentObject(collectionStore)
        }
    }

    private func collectionHeader(
        _ collection: SharedCollection
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SHARED COLLECTION")
                .font(ArchiveTheme.label(11))
                .tracking(1.4)
                .foregroundStyle(ArchiveTheme.collectedRed)

            Text(collection.name)
                .font(ArchiveTheme.display(34))
                .foregroundStyle(ArchiveTheme.ink)

            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")

                Text(
                    "\(collection.memberIDs.count) MEMBERS"
                )
            }
            .font(ArchiveTheme.label(11))
            .foregroundStyle(ArchiveTheme.catalogGray)

            HStack(spacing: 12) {
                if FeatureFlags.chatEnabled {
                NavigationLink {
                    ChatView(sharedCollection: collection)
                } label: {
                    Label("GROUP CHAT", systemImage: "bubble.left.and.bubble.right")
                        .font(ArchiveTheme.label(12))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ArchiveTheme.collectedRed)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                }

                Button {
                    showingItemPicker = true
                } label: {
                    Label("ADD OBJECT", systemImage: "plus")
                        .font(ArchiveTheme.label(12))
                        .foregroundStyle(ArchiveTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.65))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    ArchiveTheme.ink.opacity(0.18),
                                    lineWidth: 1
                                )
                        }
                }
                .disabled(!canAddItems)
            }
        }
        .padding(.top, 18)
    }

    private func memberSection(
        _ collection: SharedCollection
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SocialSectionHeader(
                title: "MEMBERS",
                trailingText: collection.permission.title.uppercased()
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    VStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(ArchiveTheme.ink)

                            Text("ME")
                                .font(ArchiveTheme.label(11))
                                .foregroundStyle(ArchiveTheme.ivory)
                        }
                        .frame(width: 54, height: 54)

                        Text("YOU")
                            .font(ArchiveTheme.label(10))
                            .foregroundStyle(ArchiveTheme.catalogGray)
                    }

                    ForEach(
                        socialStore.members(of: collection)
                    ) { member in
                        memberAvatar(member, in: collection)
                    }
                }
            }

            if let membershipError {
                Label(membershipError, systemImage: "exclamationmark.triangle")
                    .font(ArchiveTheme.body(12))
                    .foregroundStyle(ArchiveTheme.collectedRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func memberAvatar(
        _ member: SocialUser,
        in collection: SharedCollection
    ) -> some View {
        let avatar = VStack(spacing: 7) {
            ZStack {
                SocialAvatarView(
                    user: member,
                    size: 54
                )
                .opacity(removingMemberID == member.id ? 0.35 : 1)

                if removingMemberID == member.id {
                    ProgressView()
                }
            }

            Text(member.name.uppercased())
                .font(ArchiveTheme.label(10))
                .foregroundStyle(ArchiveTheme.catalogGray)
                .lineLimit(1)
        }
        .frame(width: 70)

        if canRemove(member, from: collection) {
            Button {
                membershipError = nil
                memberPendingRemoval = member
            } label: {
                avatar.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(removingMemberID != nil)
            .accessibilityLabel(member.name)
            .accessibilityHint("Double-tap to remove from collection")
        } else {
            avatar
        }
    }

    private func remove(_ member: SocialUser) {
        guard removingMemberID == nil else { return }
        removingMemberID = member.id
        membershipError = nil
        Task { @MainActor in
            do {
                try await socialStore.removeMember(member.id, from: collectionID)
                Haptics.success()
            } catch {
                membershipError = "Couldn't remove \(member.name). Check your connection and try again. (\(error.localizedDescription))"
            }
            removingMemberID = nil
        }
    }

    private func leave() {
        guard !isLeaving else { return }
        isLeaving = true
        membershipError = nil
        Task { @MainActor in
            do {
                try await socialStore.leaveCollection(collectionID)
                Haptics.success()
                isLeaving = false
                dismiss()
            } catch {
                isLeaving = false
                membershipError = "Couldn't leave this collection. Check your connection and try again. (\(error.localizedDescription))"
            }
        }
    }

    private func objectSection(
        _ collection: SharedCollection
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SocialSectionHeader(
                title: "OBJECTS",
                trailingText: "\(collectionItems.count)"
            )

            if collectionItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 30))
                        .foregroundStyle(ArchiveTheme.collectedRed)

                    Text("No objects yet")
                        .font(ArchiveTheme.heading(17))
                        .foregroundStyle(ArchiveTheme.ink)

                    Text("Add an object from your personal collection.")
                        .font(ArchiveTheme.body(13))
                        .foregroundStyle(ArchiveTheme.catalogGray)

                    Button("ADD FIRST OBJECT") {
                        showingItemPicker = true
                    }
                    .font(ArchiveTheme.label(11))
                    .foregroundStyle(ArchiveTheme.collectedRed)
                    .disabled(!canAddItems)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
                .background(Color.white.opacity(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            ArchiveTheme.ink.opacity(0.12),
                            style: StrokeStyle(
                                lineWidth: 1,
                                dash: [5]
                            )
                        )
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 18
                ) {
                    ForEach(collectionItems) { item in
                        SharedObjectCard(item: item)
                    }
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SocialSectionHeader(
                title: "RECENT ACTIVITY",
                trailingText: ""
            )

            activityRow(
                icon: "plus",
                text: "An object was added to the collection",
                time: "TODAY"
            )

            if FeatureFlags.chatEnabled {
                activityRow(
                    icon: "bubble.left",
                    text: "A new message was sent in group chat",
                    time: "RECENTLY"
                )
            }
        }
    }

    private func activityRow(
        icon: String,
        text: String,
        time: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ArchiveTheme.collectedRed)
                .frame(width: 34, height: 34)
                .background(ArchiveTheme.paperTan.opacity(0.35))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(ArchiveTheme.body(13))
                    .foregroundStyle(ArchiveTheme.ink)

                Text(time)
                    .font(ArchiveTheme.label(9))
                    .tracking(1)
                    .foregroundStyle(ArchiveTheme.catalogGray)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.45))
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 30))
                .foregroundStyle(ArchiveTheme.collectedRed)

            Text("Collection unavailable")
                .font(ArchiveTheme.heading(18))

            Text("This shared collection may have been removed.")
                .font(ArchiveTheme.body(13))
                .foregroundStyle(ArchiveTheme.catalogGray)
        }
        .multilineTextAlignment(.center)
        .padding(30)
    }
}

private struct SharedObjectCard: View {
    let item: CollectibleItem

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            artwork
                .aspectRatio(item.category.artworkAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(item.title.uppercased())
                .font(ArchiveTheme.label(11))
                .foregroundStyle(ArchiveTheme.ink)
                .lineLimit(1)

            Text(item.year.map { "\(item.creator) · \(String($0))" } ?? item.creator)
                .font(ArchiveTheme.body(11))
                .foregroundStyle(ArchiveTheme.catalogGray)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let uploadedImage = item.uploadedImage {
            Image(uiImage: uploadedImage)
                .resizable()
                .scaledToFill()

        } else if let imageName = item.imageName,
                  let assetImage = UIImage(named: imageName) {
            Image(uiImage: assetImage)
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
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.82))
            }
        }
    }}

private struct SharedCollectionItemPicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var socialStore: SocialStore
    @EnvironmentObject private var collectionStore: CollectionStore

    let collectionID: UUID

    /// Picked in this sheet, not yet saved.
    @State private var picked: [UUID] = []
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingCreate = false

    private var alreadyShared: Set<UUID> {
        Set(socialStore.sharedCollections.first { $0.id == collectionID }?.itemIDs ?? [])
    }

    /// Only this account's own objects (H09). Demo objects never appear.
    private var objects: [CollectibleItem] {
        collectionStore.activeItems.sorted { ($0.addedOn ?? .distantPast) > ($1.addedOn ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArchiveTheme.ivory
                    .ignoresSafeArea()

                if objects.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("ADD OBJECT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") { dismiss() }
                        .font(ArchiveTheme.label(12))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(picked.isEmpty ? "DONE" : "ADD \(picked.count)") { save() }
                            .font(ArchiveTheme.label(12))
                            .foregroundStyle(picked.isEmpty ? ArchiveTheme.catalogGray : ArchiveTheme.collectedRed)
                            .disabled(picked.isEmpty)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle")
                        .font(ArchiveTheme.body(12))
                        .foregroundStyle(ArchiveTheme.collectedRed)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.95))
                }
            }
            .fullScreenCover(isPresented: $showingCreate) {
                CreateFlowView(
                    onSaved: { showingCreate = false },
                    onCancel: { showingCreate = false }
                )
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var emptyState: some View {
        // H10: a real next step instead of an empty list.
        SocialStateCard(
            systemImage: "shippingbox",
            title: "NO OBJECTS YET",
            message: "Add an object to your collection first, then come back to share it here.",
            actionTitle: "ADD YOUR FIRST OBJECT"
        ) { showingCreate = true }
        .padding(20)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(objects) { item in
                    row(item)
                    Divider().overlay(ArchiveTheme.ink.opacity(0.08))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func row(_ item: CollectibleItem) -> some View {
        let shared = alreadyShared.contains(item.id)
        let selected = picked.contains(item.id)
        return Button {
            guard !shared, !isSaving else { return }
            Haptics.selection()
            if selected { picked.removeAll { $0 == item.id } } else { picked.append(item.id) }
            saveError = nil
        } label: {
            HStack(spacing: 14) {
                thumbnail(item)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(ArchiveTheme.heading(15))
                        .foregroundStyle(ArchiveTheme.ink)
                        .lineLimit(1)
                    Text(shared ? "Already in this collection" : item.creator)
                        .font(ArchiveTheme.body(12))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: shared || selected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(shared ? ArchiveTheme.catalogGray : selected ? ArchiveTheme.collectedRed : ArchiveTheme.ink)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(shared)
        .accessibilityLabel(item.title)
        .accessibilityValue(shared ? "Already added" : selected ? "Selected" : "Not selected")
    }

    /// H11: the real photo when it's on this device, otherwise a neutral
    /// placeholder; a missing cloud photo offers a retry.
    @ViewBuilder
    private func thumbnail(_ item: CollectibleItem) -> some View {
        let missingPhoto = item.imageFileName != nil && item.uploadedImage == nil
        ZStack {
            if missingPhoto {
                RoundedRectangle(cornerRadius: 8).fill(ArchiveTheme.paperTan.opacity(0.3))
                Button {
                    collectionStore.retryCloudSync()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retry loading photo")
            } else if item.hasArtwork {
                ArtworkView(item: item)
            } else {
                RoundedRectangle(cornerRadius: 8).fill(ArchiveTheme.paperTan.opacity(0.3))
                Image(systemName: item.category.systemImage)
                    .foregroundStyle(ArchiveTheme.collectedRed)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func save() {
        guard !picked.isEmpty, !isSaving else { return }
        isSaving = true
        saveError = nil
        let ids = picked
        Task { @MainActor in
            do {
                try await socialStore.addItems(ids, to: collectionID)
                Haptics.success()
                isSaving = false
                dismiss()
            } catch {
                // Keep the selection so DONE can simply be tapped again.
                isSaving = false
                saveError = "Couldn't add \(ids.count == 1 ? "this object" : "these objects"). Check your connection and tap ADD again. (\(error.localizedDescription))"
            }
        }
    }
}

#Preview {
    NavigationStack {
        SharedCollectionDetailPreview()
    }
    .environmentObject(SocialStore())
    .environmentObject(CollectionStore())
}

private struct SharedCollectionDetailPreview: View {
    @EnvironmentObject private var socialStore: SocialStore

    var body: some View {
        if let collection = socialStore.sharedCollections.first {
            SharedCollectionDetailView(
                collectionID: collection.id
            )
        }
    }
}
