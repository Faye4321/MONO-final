import SwiftUI

/// Chloe's module owns its navigation and ExploreStore. Pass Fei's repositories
/// through the initializer when the shared Firebase layer is ready.
@MainActor
struct HomeView: View {
    @EnvironmentObject private var store: CollectionStore
    @StateObject private var explore: ExploreStore
    @AppStorage(CollectingPreferences.storageKey) private var collectsRaw = ""
    @State private var category: CollectionCategory?
    let onProfileTapped: () -> Void
    let onOpenLab: () -> Void

    init(
        onProfileTapped: @escaping () -> Void = {},
        onOpenLab: @escaping () -> Void = {},
        catalogProvider: (any ExploreCatalogProviding)? = nil,
        wishlistProvider: (any ExploreWishlistProviding)? = nil
    ) {
        self.onProfileTapped = onProfileTapped
        self.onOpenLab = onOpenLab
        _explore = StateObject(wrappedValue: ExploreStore(catalog: catalogProvider, wishlist: wishlistProvider))
    }

    private var preferred: [CollectionCategory] { CollectingPreferences.categories(from: collectsRaw) }
    private var collected: [CollectionCategory] { store.activeItems.map(\.category) }
    private var ranked: [ShopPick] {
        ExploreQuery.ranked(explore.picks, preferred: preferred, saved: explore.saved, collected: collected)
    }
    private var filtered: [ShopPick] {
        ExploreQuery.results(ranked, query: "", category: category, sort: .recommended)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        header
                        searchEntry
                        discoveries
                        HomeJourneySection()
                        CollageStudioCard(height: proxy.size.width < 375 ? 340 : 360, showsArtwork: proxy.size.width >= 393) {
                            Haptics.light(); onOpenLab()
                        }
                    }
                    .padding(.horizontal, proxy.size.width < 375 ? 14 : 18)
                    .padding(.top, 12).padding(.bottom, 28)
                    .frame(maxWidth: 540).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .refreshable { await explore.loadCatalog() }
                .background(BrandColor.archiveIvory)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { ExploreFeedbackBar() }
        .environmentObject(explore)
        .tint(BrandColor.collectedRed)
        .task { await explore.loadIfNeeded() }
        .alert(item: $explore.mutationIssue) { issue in
            Alert(
                title: Text("Wishlist wasn’t updated"),
                message: Text("Your previous saved state is unchanged. Please try again."),
                primaryButton: .default(Text("Try again")) {
                    Task { await explore.setSaved(issue.pick, saved: issue.desiredSaved) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("EXPLORE").monoHeading(22, tracking: 0.6)
                    .foregroundStyle(BrandColor.inkBlack)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                        .font(.caption2).foregroundStyle(BrandColor.catalogGray)
                }
            }
            Spacer(minLength: 4)
            NavigationLink {
                ExploreWishlistView()
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 19))
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .topTrailing) {
                        if !explore.saved.isEmpty {
                            Circle().fill(BrandColor.collectedRed).frame(width: 7, height: 7).padding(5)
                        }
                    }
            }
            .accessibilityLabel("Wishlist, \(explore.saved.count) saved finds")
            .accessibilityIdentifier("explore.openWishlist")
            Button {
                Haptics.light(); onProfileTapped()
            } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 17)).foregroundStyle(BrandColor.archiveIvory)
                    .frame(width: 44, height: 44)
                    .background(BrandColor.collectedRed, in: Circle())
            }
            .buttonStyle(.plain).accessibilityLabel("Open profile")
        }
    }

    private var searchEntry: some View {
        NavigationLink {
            ExploreSearchView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                Text("Find your next favorite").font(.subheadline)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption)
            }
            .foregroundStyle(BrandColor.catalogGray)
            .padding(.horizontal, 16).frame(minHeight: 50)
            .background(BrandColor.softCard, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain).accessibilityIdentifier("explore.openSearch")
    }

    private var discoveries: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text("A good find.\nA little more you.")
                    .font(.system(.largeTitle, design: .serif))
                    .foregroundStyle(BrandColor.inkBlack)
                Text("PICKED FOR YOU").font(.caption.weight(.medium)).tracking(1)
                    .foregroundStyle(BrandColor.collectedRed)
            }
            switch explore.catalogState {
            case .idle, .loading:
                ExploreLoadingView()
            case .failed(let message):
                ExploreStateView(symbol: "wifi.exclamationmark", title: "A small pause in discovery", message: message, actionTitle: "Try again") {
                    Task { await explore.loadCatalog() }
                }
            case .loaded:
                if ranked.isEmpty {
                    ExploreStateView(symbol: "sparkle.magnifyingglass", title: "New finds are on their way", message: "There’s nothing to recommend just yet. Check back soon.", actionTitle: "Refresh finds") {
                        Task { await explore.loadCatalog() }
                    }
                } else {
                    ExploreFeaturedCarousel(picks: Array(ranked.prefix(6)), preferred: preferred, collected: collected)
                    Text("Selected using your interests, wishlist and collection categories. Curated sample listings; verify prices on eBay.")
                        .font(.footnote).foregroundStyle(BrandColor.catalogGray)
                    HStack {
                        Text("BROWSE FINDS").font(.caption.weight(.medium)).tracking(0.7)
                        Spacer()
                        Text("\(filtered.count) FINDS").font(.caption).foregroundStyle(BrandColor.catalogGray)
                    }
                    ExploreCategoryFilter(category: $category)
                    if filtered.isEmpty {
                        ExploreStateView(symbol: "tray", title: "No finds in this category yet", message: "Try browsing all finds.", actionTitle: "Show all finds") { category = nil }
                    } else { ExplorePickGrid(picks: filtered) }
                }
            }
            if case .failed = explore.wishlistState {
                NavigationLink { ExploreWishlistView() } label: {
                    Label("Wishlist unavailable · Open to retry", systemImage: "exclamationmark.circle")
                        .font(.subheadline).frame(minHeight: 44)
                }
            }
        }
    }
}

private struct ExploreFeaturedCarousel: View {
    @EnvironmentObject private var explore: ExploreStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var currentID: String?
    let picks: [ShopPick]
    let preferred: [CollectionCategory]
    let collected: [CollectionCategory]

    var body: some View {
        if typeSize.isAccessibilitySize {
            if let pick = picks.first {
                card(pick, index: 0)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            ScrollView(.horizontal) {
                // There are at most six featured picks. Measure them eagerly so
                // the row uses its content height rather than a fixed viewport.
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(picks.enumerated()), id: \.element.id) { index, pick in
                        card(pick, index: index)
                            .containerRelativeFrame(.horizontal) { width, _ in
                                max(1, width - 22)
                            }
                    }
                }
                .scrollTargetLayout()
                .fixedSize(horizontal: false, vertical: true)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $currentID)
            .scrollIndicators(.hidden)
            .contentMargins(.trailing, 22, for: .scrollContent)
        }
    }

    private func card(_ pick: ShopPick, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                ExplorePickDetailView(pick: pick)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(String(format: "%02d / %02d", index + 1, picks.count))
                                .font(.caption2).foregroundStyle(BrandColor.catalogGray)
                            Text(pick.title).font(.system(.title, design: .serif))
                                .foregroundStyle(BrandColor.inkBlack)
                                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        }
                        Spacer(minLength: 44)
                    }
                    ExploreArtwork(pick: pick)
                        .frame(height: typeSize.isAccessibilitySize ? 220 : 170)
                        .frame(maxWidth: .infinity)
                    // Keep the price at the bottom when a neighbouring title
                    // wraps, without adding space beneath the price itself.
                    Spacer(minLength: 0)
                    Text(ExploreQuery.reason(for: pick, preferred: preferred, saved: explore.saved, collected: collected))
                        .font(.footnote).foregroundStyle(BrandColor.catalogGray)
                    HStack {
                        Text(pick.priceText).font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right").frame(width: 44, height: 44)
                    }
                    .foregroundStyle(BrandColor.inkBlack)
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(BrandColor.heroStone, in: RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            ExploreSaveButton(pick: pick).padding(12)
        }
    }
}

// MARK: - Collection Journey

// The collection calendar on Explore. Read-only: memories are added when
// creating an object or from an object's page. The ME page keeps its own copy.
private struct HomeJourneySection: View {
    @EnvironmentObject private var store: CollectionStore

    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var focusedIndex = 0
    @State private var hasPositioned = false
    @State private var showingFlip = false
    @State private var selectedMoment: Moment?

    private var years: [Int] {
        MemoryCalendar.years(in: store.calendarSource)
    }

    private var pages: [CalendarPage] {
        MemoryCalendar.pages(for: year, source: store.calendarSource)
    }

    private var yearSummary: String {
        let entries = pages.flatMap { page in page.moments.map { (page, $0) } }
        let objects = Set(entries.flatMap { $0.1.itemIDs }).count
        let memories = entries.filter { !$0.0.isAddedEntry($0.1) }.count
        guard objects > 0 else {
            return "Objects you add to your collection appear here, month by month."
        }
        let objectText = objects == 1 ? "1 object" : "\(objects) objects"
        let memoryText = memories == 1 ? "1 memory" : "\(memories) memories"
        return "\(objectText) · \(memoryText) this year"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR COLLECTION JOURNEY")
                .monoLabel(11, tracking: 0.45)
                .foregroundStyle(BrandColor.inkBlack)

            HStack(alignment: .firstTextBaseline) {
                Text(String(year))
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(BrandColor.inkBlack)

                Spacer()

                yearSwitcher
            }
            .padding(.top, 12)

            Text(yearSummary)
                .monoBody(13)
                .foregroundStyle(BrandColor.catalogGray)
                .padding(.top, 6)

            CalendarStack(
                pages: pages,
                focusedIndex: $focusedIndex,
                onOpen: { showingFlip = true },
                onTapMoment: { selectedMoment = $0 }
            )
            .padding(.top, 18)
        }
        .onAppear {
            guard !hasPositioned else { return }
            hasPositioned = true
            focusedIndex = MemoryCalendar.defaultIndex(in: pages)
        }
        .onChange(of: year) {
            focusedIndex = MemoryCalendar.defaultIndex(in: pages)
        }
        .onChange(of: pages.count) {
            focusedIndex = max(0, min(focusedIndex, pages.count - 1))
        }
        .sheet(item: $selectedMoment) { moment in
            MomentObjectsSheet(moment: moment)
        }
        .fullScreenCover(isPresented: $showingFlip) {
            CalendarFlipView(pages: pages, focusedIndex: $focusedIndex)
        }
    }

    private var yearSwitcher: some View {
        let index = years.firstIndex(of: year) ?? 0
        return HStack(spacing: 14) {
            Button {
                Haptics.selection()
                year = years[index - 1]
            } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .disabled(index == 0)
            .accessibilityLabel("Previous year")

            Button {
                Haptics.selection()
                year = years[index + 1]
            } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .disabled(index >= years.count - 1)
            .accessibilityLabel("Next year")
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(BrandColor.inkBlack)
        .buttonStyle(.plain)
    }
}

// MARK: - Collage Studio

private struct CollageStudioCard: View {
    let height: CGFloat
    var showsArtwork = true
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(
                cornerRadius: 27,
                style: .continuous
            )
            .fill(Color(hex: 0x20231F))

            VStack(alignment: .leading, spacing: 0) {
                Text("COLLAGE STUDIO")
                    .monoLabel(10, tracking: 0.65)
                    .foregroundStyle(
                        Color.white.opacity(0.64)
                    )

                Text(
                    """
                    YOUR OBJECTS,
                    YOUR OWN
                    COMPOSITION.
                    """
                )
                .monoTitle(29, tracking: -0.4)
                .foregroundStyle(BrandColor.archiveIvory)
                .lineSpacing(-2)
                .padding(.top, 18)

                Text(
                    """
                    Turn your collection into a visual story
                    worth sharing.
                    """
                )
                .monoBody(11)
                .foregroundStyle(
                    Color.white.opacity(0.6)
                )
                .lineSpacing(5)
                .padding(.top, 20)

                Spacer()

                Button(action: action) {
                    Text("OPEN THE STUDIO  →")
                        .monoLabel(10, tracking: 0.35)
                        .foregroundStyle(
                            BrandColor.inkBlack
                        )
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(
                            BrandColor.archiveIvory,
                            in: Capsule()
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(21)

            if showsArtwork {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        CollageArtwork()
                            .frame(width: 178, height: 188)
                            .scaleEffect(0.7, anchor: .bottomTrailing)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.trailing, 12)
                .padding(.bottom, 18)
                .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 27,
                style: .continuous
            )
        )
    }
}

// MARK: - Collage Artwork

private struct CollageArtwork: View {
    var body: some View {
        ZStack {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(BrandColor.collectedRed)

                Circle()
                    .fill(BrandColor.inkBlack)
                    .frame(width: 52, height: 52)
                    .offset(x: 17, y: 22)

                Circle()
                    .fill(BrandColor.paperTan)
                    .frame(width: 15, height: 15)
                    .offset(x: 35, y: 40)

                Text("FIRST LOVE")
                    .monoLabel(7)
                    .foregroundStyle(
                        BrandColor.archiveIvory
                    )
                    .offset(x: 12, y: 98)
            }
            .frame(width: 92, height: 126)
            .rotationEffect(.degrees(-8))
            .offset(x: -33, y: 6)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color(hex: 0xDCC7A6))

                Path { path in
                    path.move(
                        to: CGPoint(x: 0, y: 86)
                    )
                    path.addLine(
                        to: CGPoint(x: 105, y: 43)
                    )
                    path.addLine(
                        to: CGPoint(x: 105, y: 130)
                    )
                    path.addLine(
                        to: CGPoint(x: 0, y: 130)
                    )
                    path.closeSubpath()
                }
                .fill(Color(hex: 0x9B6C4D))

                Text("DUNE")
                    .font(
                        .system(
                            size: 19,
                            design: .serif
                        )
                    )
                    .foregroundStyle(BrandColor.inkBlack)
                    .offset(x: 12, y: 10)
            }
            .frame(width: 105, height: 130)
            .rotationEffect(.degrees(6))
            .offset(x: 38, y: 5)

            VStack(spacing: -3) {
                Circle()
                    .fill(Color(hex: 0xDCC5B3))
                    .frame(width: 42, height: 42)

                UnevenRoundedRectangle(
                    topLeadingRadius: 22,
                    bottomLeadingRadius: 7,
                    bottomTrailingRadius: 7,
                    topTrailingRadius: 22
                )
                .fill(BrandColor.olive)
                .frame(width: 58, height: 83)
            }
            .offset(x: -44, y: 62)

            Rectangle()
                .fill(
                    BrandColor.paperTan.opacity(0.75)
                )
                .frame(width: 64, height: 14)
                .rotationEffect(.degrees(5))
                .offset(y: -68)

            Path { path in
                path.move(
                    to: CGPoint(x: 8, y: 169)
                )

                path.addCurve(
                    to: CGPoint(x: 166, y: 163),
                    control1: CGPoint(x: 58, y: 182),
                    control2: CGPoint(x: 119, y: 177)
                )
            }
            .stroke(
                BrandColor.collectedRed,
                lineWidth: 2
            )
        }
    }
}

// MARK: - Button Style

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed
                    ? 0.96
                    : 1
            )
            .opacity(
                configuration.isPressed
                    ? 0.86
                    : 1
            )
            .animation(
                .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}

#if DEBUG
#Preview("Explore · SE") {
    HomeView(catalogProvider: ExplorePreviewCatalog(), wishlistProvider: ExplorePreviewWishlist()).environmentObject(CollectionStore()).frame(width: 375, height: 667)
}
#Preview("Explore · Pro Max") {
    HomeView(catalogProvider: ExplorePreviewCatalog(), wishlistProvider: ExplorePreviewWishlist()).environmentObject(CollectionStore()).frame(width: 440, height: 956)
}
#Preview("Explore · Large text") {
    HomeView(catalogProvider: ExplorePreviewCatalog(), wishlistProvider: ExplorePreviewWishlist()).environmentObject(CollectionStore()).dynamicTypeSize(.accessibility2)
}

#endif
