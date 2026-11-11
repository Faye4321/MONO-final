import SwiftUI

struct ExploreCategoryFilter: View {
    @Binding var category: CollectionCategory?
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("All finds", value: nil)
                ForEach(CollectionCategory.allCases) { item in chip(item.title, value: item) }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Filter by collection category")
    }
    private func chip(_ title: String, value: CollectionCategory?) -> some View {
        Button {
            category = value
            Haptics.selection()
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 15)
                .frame(minHeight: 44)
                .foregroundStyle(category == value ? BrandColor.archiveIvory : BrandColor.inkBlack)
                .background(category == value ? BrandColor.inkBlack : BrandColor.softCard, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(category == value ? .isSelected : [])
        .accessibilityIdentifier("explore.category.\(value?.rawValue ?? "all")")
    }
}

struct ExploreArtwork: View {
    let pick: ShopPick
    var body: some View {
        Group {
            if let name = pick.imageName, let image = UIImage(named: name) {
                artwork(Image(uiImage: image))
            } else if let url = pick.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): artwork(image)
                    case .empty: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    default: placeholder
                    }
                }
            } else { placeholder }
        }
        .accessibilityHidden(true)
    }
    private func artwork(_ image: Image) -> some View {
        image.resizable().scaledToFit().padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: pick.category.systemImage).font(.largeTitle)
            Text("Image unavailable").font(.caption)
        }
        .foregroundStyle(BrandColor.catalogGray)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ExploreSaveButton: View {
    @EnvironmentObject private var explore: ExploreStore
    let pick: ShopPick
    var showsTitle = false
    var body: some View {
        Button {
            Haptics.light()
            Task { await explore.toggle(pick) }
        } label: {
            HStack(spacing: 8) {
                if explore.pendingIDs.contains(pick.id) {
                    ProgressView().tint(BrandColor.collectedRed)
                } else {
                    Image(systemName: explore.isSaved(pick) ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .medium))
                }
                if showsTitle {
                    Text(explore.isSaved(pick) ? "Saved to wishlist" : "Save to wishlist")
                        .font(.subheadline.weight(.medium))
                }
            }
            .foregroundStyle(BrandColor.collectedRed)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, showsTitle ? 14 : 0)
            .background(BrandColor.archiveIvory, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!explore.wishlistState.isLoaded || explore.pendingIDs.contains(pick.id))
        .accessibilityLabel(explore.isSaved(pick) ? "Remove \(pick.title) from wishlist" : "Save \(pick.title) to wishlist")
        .accessibilityValue(explore.pendingIDs.contains(pick.id) ? "Saving" : (explore.isSaved(pick) ? "Saved" : "Not saved"))
        .accessibilityHint(explore.wishlistState.isLoaded ? "" : "Open Wishlist to retry loading your saved finds")
        .accessibilityIdentifier("explore.save.\(pick.id)")
    }
}

struct ExplorePickGrid: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let picks: [ShopPick]
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
            ForEach(picks) { pick in
                ZStack(alignment: .topTrailing) {
                    NavigationLink {
                        ExplorePickDetailView(pick: pick)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            ExploreArtwork(pick: pick)
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .background(BrandColor.softCard, in: RoundedRectangle(cornerRadius: 18))
                            Text(pick.category.title.uppercased())
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(BrandColor.catalogGray)
                            Text(pick.title)
                                .font(.headline)
                                .foregroundStyle(BrandColor.inkBlack)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(pick.priceText)
                                .font(.subheadline)
                                .foregroundStyle(BrandColor.catalogGray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("explore.pick.\(pick.id)")
                    ExploreSaveButton(pick: pick).padding(6)
                }
            }
        }
    }
    private var columns: [GridItem] {
        typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 145), spacing: 14, alignment: .top)]
    }
}

struct ExploreStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: () -> Void = {}
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 30, weight: .light))
                .foregroundStyle(BrandColor.collectedRed)
            Text(title).font(.title3.weight(.medium))
            Text(message).font(.subheadline).foregroundStyle(BrandColor.catalogGray)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent).tint(BrandColor.inkBlack)
                    .frame(minHeight: 44)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20).padding(.vertical, 32)
        .accessibilityElement(children: .contain)
    }
}

struct ExploreLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView("Finding your next favorite…")
            HStack(spacing: 14) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18).fill(BrandColor.softCard).frame(height: 170)
                }
            }
            .redacted(reason: .placeholder).accessibilityHidden(true)
        }.padding(.vertical, 22)
    }
}

/// One host around Home's NavigationStack keeps feedback consistent on every
/// destination, including search, detail and wishlist, without duplicate alerts.
struct ExploreFeedbackBar: View {
    @EnvironmentObject private var explore: ExploreStore
    var body: some View {
        if let feedback = explore.feedback {
            VStack(alignment: .leading, spacing: 4) {
                Label(feedback.message, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                HStack {
                    if let pick = feedback.removedPick {
                        Button("Undo removal") { Task { await explore.setSaved(pick, saved: true) } }
                            .disabled(explore.pendingIDs.contains(pick.id))
                            .accessibilityIdentifier("explore.undo")
                    }
                    Spacer()
                    Button("Dismiss") { explore.feedback = nil }
                }
                .font(.subheadline).buttonStyle(.plain)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 18).padding(.top, 12)
            .foregroundStyle(BrandColor.archiveIvory)
            .background(BrandColor.inkBlack)
            .accessibilityIdentifier("explore.feedback")
        }
    }
}
