import SwiftUI

// MARK: - Past Collection

struct PastCollectionSection: View {
    @EnvironmentObject private var store: CollectionStore

    var body: some View {
        if !store.pastItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("PAST COLLECTION")
                        .font(ArchiveTheme.heading(18))
                        .foregroundStyle(ArchiveTheme.ink)
                    Spacer()
                    Text("\(store.pastItems.count)")
                        .font(ArchiveTheme.label(11))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                }
                .padding(.top, 24)
                .padding(.horizontal, 3)

                VStack(spacing: 0) {
                    ForEach(store.pastItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            HStack(spacing: 12) {
                                ArtworkView(item: item)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .saturation(0.4)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(ArchiveTheme.heading(14))
                                        .foregroundStyle(ArchiveTheme.ink)
                                    if let partedOn = item.partedOn {
                                        Text("Parted on \(partedOn.formatted(date: .abbreviated, time: .omitted))")
                                            .font(ArchiveTheme.body(12))
                                            .foregroundStyle(ArchiveTheme.catalogGray)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ArchiveTheme.catalogGray)
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 25))
            }
        }
    }
}
