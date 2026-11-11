import SwiftUI
import UIKit

struct ShelfDetailView: View {
    @EnvironmentObject private var store: CollectionStore
    let category: CollectionCategory
    @State private var itemPendingDeletion: CollectibleItem?

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    shelfHeader
                    shelfContent
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 36)
            }
        }
        .foregroundStyle(ArchiveTheme.ink)
        .environment(\.colorScheme, .light)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(background, for: .navigationBar)
        .confirmationDialog(
            "Delete this item?",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { if !$0 { itemPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Item", role: .destructive) {
                guard let itemPendingDeletion else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.deleteItem(itemPendingDeletion)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.itemPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                itemPendingDeletion = nil
            }
        } message: {
            Text("This item will be removed from your collection.")
        }
    }

    private var background: Color { ArchiveTheme.ivory }

    private var foreground: Color { ArchiveTheme.ink }

    private var shelfHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(category.title)
                .font(ArchiveTheme.display(30))
                .foregroundStyle(foreground)
            HStack {
                Text(category.shelfLabel)
                Spacer()
                Text("\(store.count(for: category)) OBJECTS")
                    .foregroundStyle(ArchiveTheme.collectedRed)
            }
            .font(ArchiveTheme.label(10))
            .tracking(1)
            .foregroundStyle(ArchiveTheme.catalogGray)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var shelfContent: some View {
        let items = store.items(for: category)
        if items.isEmpty {
            EmptyShelfView(category: category)
        } else {
            switch category {
            case .vinyl:
                VinylShelfView(items: items, onDelete: requestDelete)
            case .bjd:
                BJDCabinetView(items: items, onDelete: requestDelete)
            case .poster:
                PosterWallView(items: items, onDelete: requestDelete)
            case .photocard:
                PhotocardBinderView(items: items, onDelete: requestDelete)
            }
        }
    }

    private func requestDelete(_ item: CollectibleItem) {
        itemPendingDeletion = item
    }
}

private struct VinylShelfView: View {
    let items: [CollectibleItem]
    let onDelete: (CollectibleItem) -> Void

    var body: some View {
        VStack(spacing: 28) {
            ForEach(Array(items.chunked(into: 3).enumerated()), id: \.offset) { _, row in
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(0..<3, id: \.self) { column in
                            Group {
                                if column < row.count {
                                    NavigationLink {
                                        ItemDetailView(item: row[column])
                                    } label: {
                                        VStack(spacing: 7) {
                                            VinylObjectView(item: row[column])
                                            ShelfObjectName(title: row[column].title)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .overlay(alignment: .topTrailing) {
                                        MemoryBadge(itemID: row[column].id)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            onDelete(row[column])
                                        } label: {
                                            Label("Delete Item", systemImage: "trash")
                                        }
                                    }
                                } else {
                                    Color.clear
                                        .frame(height: 78)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    ZStack(alignment: .top) {
                        Rectangle().fill(Color(hex: "676967")).frame(height: 11)
                        Rectangle().fill(.black.opacity(0.2)).frame(height: 3).offset(y: 11)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

struct VinylObjectView: View {
    let item: CollectibleItem
    var compact = false

    var body: some View {
        let coverSize: CGFloat = compact ? 64 : 78
        let reveal: CGFloat = compact ? 19 : 26

        ZStack(alignment: .leading) {
            Circle()
                .fill(Color(hex: "191918"))
                .overlay {
                    Circle().stroke(.white.opacity(0.1), lineWidth: 1).padding(8)
                    Circle().fill(Color(hex: item.colorB)).frame(width: compact ? 14 : 20)
                }
                .frame(width: coverSize * 0.94, height: coverSize * 0.94)
                .offset(x: reveal)

            ArtworkView(item: item)
                .frame(width: coverSize, height: coverSize)
                .clipped()
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        }
        .frame(width: coverSize + reveal, height: coverSize, alignment: .leading)
    }
}

private struct BJDCabinetView: View {
    let items: [CollectibleItem]
    let onDelete: (CollectibleItem) -> Void

    var body: some View {
        VStack(spacing: 34) {
            ForEach(Array(items.chunked(into: 3).enumerated()), id: \.offset) { _, row in
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 14) {
                        ForEach(0..<3, id: \.self) { column in
                            Group {
                                if column < row.count {
                                    NavigationLink {
                                        ItemDetailView(item: row[column])
                                    } label: {
                                        DollObjectView(item: row[column])
                                    }
                                    .buttonStyle(.plain)
                                    .overlay(alignment: .topTrailing) {
                                        MemoryBadge(itemID: row[column].id)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            onDelete(row[column])
                                        } label: {
                                            Label("Delete Item", systemImage: "trash")
                                        }
                                    }
                                } else {
                                    Color.clear
                                        .frame(height: 150)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    Rectangle()
                        .fill(LinearGradient(colors: [Color(hex: "A97245"), Color(hex: "6F462A")], startPoint: .top, endPoint: .bottom))
                        .frame(height: 9)
                        .shadow(color: .black.opacity(0.24), radius: 5, y: 4)
                }
            }
        }
        .padding(.vertical, 14)
    }
}

struct DollObjectView: View {
    let item: CollectibleItem
    var compact = false

    var body: some View {
        let caseHeight: CGFloat = compact ? 100 : 150

        VStack(spacing: compact ? 2 : 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: compact ? 8 : 13)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.72), Color(hex: "DDE4E2").opacity(0.34)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: compact ? 8 : 13)
                            .stroke(.white.opacity(0.95), lineWidth: 1.5)
                    }

                if item.hasArtwork {
                    ArtworkView(item: item)
                        .aspectRatio(0.72, contentMode: .fit)
                        .padding(.horizontal, compact ? 7 : 10)
                        .padding(.top, compact ? 7 : 10)
                        .padding(.bottom, compact ? 15 : 21)
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 7 : 11))
                } else {
                    VStack(spacing: -2) {
                        Circle()
                            .fill(Color(hex: item.colorA))
                            .frame(width: compact ? 25 : 40, height: compact ? 25 : 40)
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: item.colorB), Color(hex: item.colorB).opacity(0.55)], startPoint: .top, endPoint: .bottom))
                            .frame(width: compact ? 33 : 53, height: compact ? 55 : 82)
                    }
                    .padding(.bottom, compact ? 15 : 22)
                }

                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "E8DED1"), Color(hex: "BDAF9D")], startPoint: .top, endPoint: .bottom))
                    .frame(height: compact ? 13 : 18)
                    .padding(.horizontal, compact ? 5 : 8)
                    .padding(.bottom, compact ? 4 : 6)

                LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 13))
                    .allowsHitTesting(false)
            }
            .frame(height: caseHeight)
            .shadow(color: ArchiveTheme.catalogGray.opacity(0.18), radius: 5, y: 4)

            if !compact {
                ShelfObjectName(title: item.title)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PosterWallView: View {
    let items: [CollectibleItem]
    let onDelete: (CollectibleItem) -> Void
    private let columns = [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
            ForEach(items) { item in
                NavigationLink {
                    ItemDetailView(item: item)
                } label: {
                    VStack(alignment: .center, spacing: 9) {
                        GeometryReader { geometry in
                            ArtworkView(item: item)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        }
                            .aspectRatio(0.68, contentMode: .fit)
                            .contrast(1.2)
                            .saturation(0.88)
                            .padding(7)
                            .background(ArchiveTheme.ink)
                            .padding(3)
                            .background(Color(hex: "3A3732"))
                            .shadow(color: .black.opacity(0.32), radius: 7, y: 4)
                        ShelfObjectName(title: item.title)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) {
                    MemoryBadge(itemID: item.id)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        onDelete(item)
                    } label: {
                        Label("Delete Item", systemImage: "trash")
                    }
                }
            }
        }
        .padding(20)
        .background(ArchiveTheme.paperTan.opacity(0.28), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct PhotocardBinderView: View {
    let items: [CollectibleItem]
    let onDelete: (CollectibleItem) -> Void
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(items) { item in
                NavigationLink {
                    ItemDetailView(item: item)
                } label: {
                    VStack(spacing: 8) {
                        PhotocardSleeveView(item: item)
                        ShelfObjectName(title: item.title)
                    }
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) {
                    MemoryBadge(itemID: item.id)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        onDelete(item)
                    } label: {
                        Label("Delete Item", systemImage: "trash")
                    }
                }
            }
        }
        .padding(18)
        .background(Color(hex: "D9D0C4"), in: RoundedRectangle(cornerRadius: 24))
        .overlay(alignment: .leading) {
            VStack(spacing: 70) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle().fill(ArchiveTheme.ivory).frame(width: 11, height: 11)
                }
            }
            .padding(.leading, -6)
        }
    }
}

struct PhotocardSleeveView: View {
    let item: CollectibleItem
    var compact = false

    var body: some View {
        ArtworkView(item: item)
            .aspectRatio(0.68, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 10))
            .padding(compact ? 5 : 9)
            .background(.white.opacity(0.36), in: RoundedRectangle(cornerRadius: compact ? 8 : 14))
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 8 : 14)
                    .stroke(.white.opacity(0.9), lineWidth: 1.2)
            }
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [.white.opacity(0.72), .clear, .white.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 14))
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.1), radius: 4, y: 3)
    }
}

private struct EmptyShelfView: View {
    let category: CollectionCategory

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: category.systemImage)
                .font(.system(size: 30, weight: .light))
            Text("THIS SHELF IS WAITING")
                .font(ArchiveTheme.heading(16))
            Text("Objects saved from the Create flow will appear here.")
                .font(ArchiveTheme.body(13))
                .multilineTextAlignment(.center)
                .foregroundStyle(ArchiveTheme.catalogGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// Marks objects that have at least one memory.
struct MemoryBadge: View {
    @EnvironmentObject private var store: CollectionStore
    let itemID: UUID

    var body: some View {
        if store.hasMemories(itemID) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(ArchiveTheme.collectedRed, in: Circle())
                .overlay {
                    Circle().stroke(.white, lineWidth: 1.5)
                }
                .offset(x: 4, y: -4)
                .accessibilityLabel("Has memories")
        }
    }
}


// One shared caption style for Vinyl, BJD, Posters and Photocards.
private struct ShelfObjectName: View {
    let title: String
    var body: some View {
        Text(title)
            .font(ArchiveTheme.body(9))
            .foregroundStyle(ArchiveTheme.ink)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: 26, alignment: .top)
    }
}
