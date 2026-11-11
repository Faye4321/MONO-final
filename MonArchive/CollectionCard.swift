import SwiftUI

struct CollectionCard: View {
    let category: CollectionCategory
    let itemCount: Int
    let items: [CollectibleItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.shelfLabel)
                        .font(ArchiveTheme.label(9))
                        .tracking(0.8)
                        .foregroundStyle(ArchiveTheme.collectedRed)

                    Text(category.title)
                        .font(ArchiveTheme.heading(18))
                        .foregroundStyle(ArchiveTheme.ink)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 7) {
                    Image(systemName: category.systemImage)
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
        switch category {
        case .vinyl:
            ZStack(alignment: .bottom) {
                ArchiveTheme.paperTan.opacity(0.45)
                HStack(spacing: -8) {
                    ForEach(items) { item in
                        VinylObjectView(item: item, compact: true)
                            .scaleEffect(1.22, anchor: .bottom)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                Rectangle().fill(ArchiveTheme.catalogGray).frame(height: 8)
            }
        case .bjd:
            ZStack(alignment: .bottom) {
                ArchiveTheme.paperTan.opacity(0.3)
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        DollObjectView(item: item, compact: true)
                            .scaleEffect(1.18, anchor: .bottom)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 10)
                Rectangle().fill(Color(hex: "8C4E20")).frame(height: 7)
            }
        case .poster:
            HStack(alignment: .center, spacing: 7) {
                ForEach(items) { item in
                    ArtworkView(item: item)
                        .aspectRatio(0.7, contentMode: .fit)
                        .contrast(1.2)
                        .saturation(0.88)
                        .frame(maxWidth: .infinity)
                        .padding(3)
                        .background(ArchiveTheme.ink)
                        .shadow(color: .black.opacity(0.16), radius: 3, y: 2)
                }
            }
            .padding(10)
            .background(ArchiveTheme.paperTan.opacity(0.42))
        case .photocard:
            HStack(spacing: 8) {
                ForEach(items) { item in
                    PhotocardSleeveView(item: item, compact: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(9)
            .background(Color(hex: "D8CEC0"))
        }
    }
}
