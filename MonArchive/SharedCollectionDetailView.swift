import SwiftUI
import UIKit

struct SharedCollectionDetailView: View {
    @EnvironmentObject private var socialStore: SocialStore
    @EnvironmentObject private var collectionStore: CollectionStore

    let collectionID: UUID

    @State private var showingItemPicker = false

    private var sharedCollection: SharedCollection? {
        socialStore.sharedCollections.first {
            $0.id == collectionID
        }
    }

    private var collectionItems: [CollectibleItem] {
        guard let sharedCollection else { return [] }

        return collectionStore.items.filter {
            sharedCollection.itemIDs.contains($0.id)
        }
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
                        activitySection
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 40)
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
                        ShareLink(
                            item: "Join my shared collection: \(sharedCollection.name)"
                        ) {
                            Label("Share Invitation", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            showingItemPicker = true
                        } label: {
                            Label("Add Object", systemImage: "plus")
                        }

                        Button {
                            // Member management can be added later.
                        } label: {
                            Label("Manage Members", systemImage: "person.2")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(ArchiveTheme.ink)
                    }
                }
            }
        }
        .sheet(isPresented: $showingItemPicker) {
            SharedCollectionItemPicker(collectionID: collectionID)
                .environmentObject(socialStore)
                .environmentObject(collectionStore)
        }
        .onAppear {
            // Gives the demo shared collection some existing objects.
            socialStore.seedSharedCollectionItems(
                from: collectionStore.items
            )
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
                    "\(collection.memberIDs.count + 1) MEMBERS"
                )
            }
            .font(ArchiveTheme.label(11))
            .foregroundStyle(ArchiveTheme.catalogGray)

            HStack(spacing: 12) {
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
                        VStack(spacing: 7) {
                            SocialAvatarView(
                                user: member,
                                size: 54
                            )

                            Text(member.name.uppercased())
                                .font(ArchiveTheme.label(10))
                                .foregroundStyle(ArchiveTheme.catalogGray)
                                .lineLimit(1)
                        }
                        .frame(width: 70)
                    }
                }
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

            activityRow(
                icon: "bubble.left",
                text: "A new message was sent in group chat",
                time: "RECENTLY"
            )
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

    private var selectedItemIDs: [UUID] {
        socialStore.sharedCollections.first {
            $0.id == collectionID
        }?.itemIDs ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArchiveTheme.ivory
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(collectionStore.items) { item in
                            Button {
                                guard !selectedItemIDs.contains(item.id) else {
                                    return
                                }

                                socialStore.addItem(
                                    item.id,
                                    to: collectionID
                                )
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: item.category.systemImage)
                                        .foregroundStyle(ArchiveTheme.collectedRed)
                                        .frame(width: 42, height: 42)
                                        .background(ArchiveTheme.paperTan.opacity(0.3))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(ArchiveTheme.heading(15))
                                            .foregroundStyle(ArchiveTheme.ink)

                                        Text(item.creator)
                                            .font(ArchiveTheme.body(12))
                                            .foregroundStyle(ArchiveTheme.catalogGray)
                                    }

                                    Spacer()

                                    if selectedItemIDs.contains(item.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(ArchiveTheme.collectedRed)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(ArchiveTheme.ink)
                                    }
                                }
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedItemIDs.contains(item.id))

                            Divider()
                                .overlay(ArchiveTheme.ink.opacity(0.08))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("ADD OBJECT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") {
                        dismiss()
                    }
                    .font(ArchiveTheme.label(12))
                    .foregroundStyle(ArchiveTheme.collectedRed)
                }
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
