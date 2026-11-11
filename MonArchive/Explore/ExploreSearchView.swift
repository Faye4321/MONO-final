import SwiftUI

struct ExploreSearchView: View {
    @EnvironmentObject private var explore: ExploreStore
    @State private var query = ""
    @State private var category: CollectionCategory?
    @State private var sort = ExploreSort.recommended

    private var results: [ShopPick] {
        ExploreQuery.results(explore.picks, query: query, category: category, sort: sort)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ExploreCategoryFilter(category: $category)
                HStack(alignment: .firstTextBaseline) {
                    Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "BROWSE FINDS" : "\(results.count) RESULTS")
                        .font(.caption.weight(.medium)).foregroundStyle(BrandColor.catalogGray)
                    Spacer()
                    Menu {
                        Picker("Sort results", selection: $sort) {
                            ForEach(ExploreSort.allCases) { value in Text(value.rawValue).tag(value) }
                        }
                    } label: {
                        Label(sort.rawValue, systemImage: "arrow.up.arrow.down").font(.subheadline)
                    }
                    .accessibilityIdentifier("explore.sort")
                }
                catalogContent
                Text("Search covers curated finds. To search objects and memories you own, open Collection → Search.")
                    .font(.footnote).foregroundStyle(BrandColor.catalogGray)
            }
            .padding(18).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .background(BrandColor.archiveIvory)
        .navigationTitle("Search finds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Title, artist, category…")
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await explore.loadCatalog() }
        .accessibilityIdentifier("explore.search")
    }

    @ViewBuilder private var catalogContent: some View {
        switch explore.catalogState {
        case .idle, .loading: ExploreLoadingView()
        case .failed(let message):
            ExploreStateView(symbol: "wifi.exclamationmark", title: "Finds couldn’t load", message: message, actionTitle: "Try again") {
                Task { await explore.loadCatalog() }
            }
        case .loaded:
            if results.isEmpty {
                ExploreStateView(symbol: "magnifyingglass", title: "No matching finds", message: "Try another title, artist or category.", actionTitle: "Clear search & filters") {
                    query = ""; category = nil; sort = .recommended
                }
            } else { ExplorePickGrid(picks: results) }
        }
    }
}

struct ExploreWishlistView: View {
    @EnvironmentObject private var explore: ExploreStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category: CollectionCategory?

    private var results: [ShopPick] {
        ExploreQuery.results(explore.saved.map(\.pick), query: query, category: category, sort: .recommended)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("KEEP WHAT CATCHES YOUR EYE").font(.caption.weight(.medium))
                    Spacer()
                    Text("\(explore.saved.count) SAVED").font(.caption)
                }.foregroundStyle(BrandColor.catalogGray)
                ExploreCategoryFilter(category: $category)
                content
            }
            .padding(18).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .background(BrandColor.archiveIvory)
        .navigationTitle("Wishlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search saved finds…")
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await explore.loadWishlist() }
        .accessibilityIdentifier("explore.wishlist")
    }
    @ViewBuilder private var content: some View {
        switch explore.wishlistState {
        case .idle, .loading: ProgressView("Loading wishlist…").frame(maxWidth: .infinity).padding(40)
        case .failed(let message):
            ExploreStateView(symbol: "exclamationmark.icloud", title: "Wishlist couldn’t load", message: message, actionTitle: "Try again") {
                Task { await explore.loadWishlist() }
            }
        case .loaded:
            if explore.saved.isEmpty {
                ExploreStateView(symbol: "heart", title: "A little room for possibility", message: "Tap a heart on any find to keep it here for later.", actionTitle: "Back to Explore") {
                    dismiss()
                }
            } else if results.isEmpty {
                ExploreStateView(symbol: "magnifyingglass", title: "No saved finds match", message: "Your other saved finds are still here.", actionTitle: "Clear search & filters") {
                    query = ""; category = nil
                }
            } else { ExplorePickGrid(picks: results) }
        }
    }
}

struct ExplorePickDetailView: View {
    @EnvironmentObject private var store: CollectionStore
    @Environment(\.openURL) private var openURL
    @State private var showingLinkError = false
    let pick: ShopPick

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ExploreArtwork(pick: pick)
                    .frame(height: 300).frame(maxWidth: .infinity)
                    .background(BrandColor.softCard, in: RoundedRectangle(cornerRadius: 24))
                Text(pick.category.title.uppercased()).font(.caption.weight(.medium)).foregroundStyle(BrandColor.catalogGray)
                Text(pick.title).font(.system(.largeTitle, design: .serif))
                Text(pick.subtitle).font(.subheadline).foregroundStyle(BrandColor.catalogGray)
                Text(pick.note).font(.body)
                ExploreSaveButton(pick: pick, showsTitle: true)
                VStack(alignment: .leading, spacing: 12) {
                    Text(pick.priceText).font(.title3)
                    Text("Curated sample listing. The price and availability may have changed. Check the seller’s page before purchasing.")
                        .font(.footnote).foregroundStyle(BrandColor.catalogGray)
                    Button {
                        store.pendingPurchase = pick
                        openURL(pick.itemWebURL) { accepted in
                            if !accepted {
                                if store.pendingPurchase?.id == pick.id { store.pendingPurchase = nil }
                                showingLinkError = true
                            }
                        }
                    } label: {
                        Label("Check listing on eBay", systemImage: "arrow.up.right")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent).tint(BrandColor.inkBlack)
                    .accessibilityIdentifier("explore.openListing")
                }
                .padding(18).background(BrandColor.softCard, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(18).frame(maxWidth: 540).frame(maxWidth: .infinity)
        }
        .background(BrandColor.archiveIvory)
        .navigationTitle("The find")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("Couldn’t open the listing", isPresented: $showingLinkError) {
            Button("OK", role: .cancel) {}
        } message: { Text("Please check your connection and try again.") }
    }
}
