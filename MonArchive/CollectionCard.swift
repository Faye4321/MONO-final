import SwiftUI

struct CollectionCard: View {
    let category: CollectionCategory
    let itemCount: Int
    let items: [CollectibleItem]
    var collectionName: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(items.isEmpty ? "COLLECTION" : category.shelfLabel)
                        .font(ArchiveTheme.label(9))
                        .tracking(0.8)
                        .foregroundStyle(ArchiveTheme.collectedRed)

                    Text(collectionName ?? category.title)
                        .font(ArchiveTheme.heading(18))
                        .foregroundStyle(ArchiveTheme.ink)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 7) {
                    Image(systemName: items.isEmpty ? "rectangle.stack" : category.systemImage)
                    Text("\(itemCount)")
                }
                .font(ArchiveTheme.label(10))
                .foregroundStyle(ArchiveTheme.collectedRed)
            }

            preview
                .frame(maxWidth: .infinity)
                .frame(height: 142)
                .clipShape(RoundedRectangle(cornerRadius: 13))

            HStack {
                Text("VIEW COLLECTION")
                    .font(ArchiveTheme.label(9))
                    .tracking(0.7)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(ArchiveTheme.catalogGray)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var preview: some View {
        if items.isEmpty {
            EmptyCollectionDisplayShelf(category: category)
        } else {
            populatedPreview
        }
    }

    private func previewSlots<Content: View>(spacing: CGFloat,
        @ViewBuilder _ itemView: @escaping (CollectibleItem) -> Content) -> some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(0..<3, id: \.self) { index in
                Group {
                    if index < items.count {
                        itemView(items[index])
                    } else {
                        Color.clear.frame(height: 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
    }

    @ViewBuilder
    private var populatedPreview: some View {
        switch category {
        case .vinyl:
            ZStack(alignment: .bottom) {
                ArchiveTheme.paperTan.opacity(0.45)
                previewSlots(spacing: -8) { item in
                    VinylObjectView(item: item, compact: true)
                        .scaleEffect(1.22, anchor: .bottom)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                Rectangle().fill(ArchiveTheme.catalogGray).frame(height: 8)
            }
        case .bjd:
            ZStack(alignment: .bottom) {
                ArchiveTheme.paperTan.opacity(0.3)
                previewSlots(spacing: 8) { item in
                    DollObjectView(item: item, compact: true)
                        .scaleEffect(1.18, anchor: .bottom)
                }
                .padding(.horizontal, 10)
                Rectangle().fill(Color(hex: "8C4E20")).frame(height: 7)
            }
        case .poster:
            previewSlots(spacing: 7) { item in
                ArtworkView(item: item)
                    .aspectRatio(0.7, contentMode: .fit)
                    .padding(3)
                    .background(ArchiveTheme.ivory)
                    .overlay { Rectangle().stroke(ArchiveTheme.paperTan.opacity(0.7), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
            }
            .padding(10)
            .background(ArchiveTheme.paperTan.opacity(0.42))
        case .photocard:
            previewSlots(spacing: 8) { item in
                PhotocardSleeveView(item: item, compact: true)
            }
            .padding(9)
            .background(Color(hex: "D8CEC0"))
        }
    }

}


/// Remove objects without inventing a new cabinet: keep the established base and backdrop.
struct EmptyCollectionDisplayShelf: View {
    var category: CollectionCategory = .poster

    private var backdrop: Color {
        switch category {
        case .vinyl: return ArchiveTheme.paperTan.opacity(0.45)
        case .bjd: return ArchiveTheme.paperTan.opacity(0.3)
        case .poster: return ArchiveTheme.ivory
        case .photocard: return Color(hex: "D8CEC0")
        }
    }

    private var baseColor: Color {
        switch category {
        case .vinyl: return ArchiveTheme.catalogGray
        case .bjd: return Color(hex: "8C4E20")
        case .poster: return ArchiveTheme.catalogGray.opacity(0.75)
        case .photocard: return ArchiveTheme.catalogGray.opacity(0.55)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            backdrop
            Rectangle()
                .fill(baseColor)
                .frame(height: category == .vinyl ? 8 : 7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Empty collection")
    }
}
