import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: CollectionStore
    @EnvironmentObject private var profileStore: CloudProfileStore
    @Environment(\.scenePhase) private var scenePhase

    @Binding var selection: AppTab
    @State private var leftForListing = false
    @State private var purchaseQuestion: ShopPick?
    @State private var purchaseMemory: Moment?
    @State private var showingCreate = false

    var body: some View {
        // The system tab bar is hidden on every tab; MonoTabBar below replaces
        // it so all five slots are exactly equal width (the system bar sizes
        // items by label length) and the Create button sits in a real slot.
        TabView(selection: $selection) {
            HomeView(
                onProfileTapped: { selection = .me },
                onOpenLab: { selection = .lab }
            )
            .toolbar(.hidden, for: .tabBar)
            .tag(AppTab.explore)

            CollectionView(onProfileTapped: { selection = .me })
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.collection)

            LabRootView(collectionProvider: ArchiveLabCollectionProvider(items: store.activeItems))
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.lab)

            ProfileView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.me)
        }
        .tint(ArchiveTheme.collectedRed)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MonoTabBar(selection: selection) { tab in
                if tab == .create { showingCreate = true } else { selection = tab }
            }
        }
        .fullScreenCover(isPresented: $showingCreate) {
            CreateFlowView(
                onSaved: {
                    showingCreate = false
                    selection = .collection
                },
                onCancel: { showingCreate = false }
            )
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.retryCloudSync(); profileStore.retry() }
            if phase == .background, store.pendingPurchase != nil {
                leftForListing = true
            } else if phase == .active, leftForListing {
                leftForListing = false
                purchaseQuestion = store.pendingPurchase
            }
        }
        .alert(
            "Did you get it?",
            isPresented: Binding(
                get: { purchaseQuestion != nil },
                set: { if !$0 { purchaseQuestion = nil } }
            ),
            presenting: purchaseQuestion
        ) { pick in
            Button("Yes, add to my archive") {
                purchaseMemory = store.addPurchase(of: pick)
                store.pendingPurchase = nil
            }
            Button("Not yet", role: .cancel) {
                store.pendingPurchase = nil
            }
        } message: { pick in
            Text("You opened \(pick.title) on eBay. If you bought it, we'll add it with today's date, the price and eBay as the place. You can add the rest yourself.")
        }
        .sheet(item: $purchaseMemory) { moment in
            MomentEditorView(moment: moment, initialItemIDs: moment.itemIDs)
        }
    }
}

enum AppTab: Hashable, CaseIterable {
    case explore
    case collection
    case create
    case lab
    case me

    var title: String {
        switch self {
        case .explore: "EXPLORE"
        case .collection: "COLLECTION"
        case .create: "CREATE"
        case .lab: "LAB"
        case .me: "ME"
        }
    }

    var systemImage: String {
        switch self {
        case .explore: "safari"
        case .collection: "rectangle.stack"
        case .create: "plus.circle"
        case .lab: "wand.and.stars"
        case .me: "person"
        }
    }
}

// Emphasised, inverted CREATE control in the middle slot of the tab bar.
struct CreateTabButton: View {
    var isSelected = false

    static let diameter: CGFloat = 46

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: Self.diameter, height: Self.diameter)
            .background(isSelected ? ArchiveTheme.collectedRed : ArchiveTheme.ink, in: Circle())
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

/// The app's floating tab bar: five strictly equal slots on liquid glass.
/// The onboarding tour draws this same view and uses `slotFrame` to place
/// its spotlight, so both always line up.
struct MonoTabBar: View {
    static let tabs: [AppTab] = [.explore, .collection, .create, .lab, .me]
    static let height: CGFloat = 62
    static let horizontalMargin: CGFloat = 20
    /// How far the bar sits into the home-indicator area, matching where the
    /// system iOS 26 tab bar sits.
    static let bottomOffset: CGFloat = 12
    static let innerPadding: CGFloat = 4

    let selection: AppTab
    var onSelect: (AppTab) -> Void = { _ in }

    @Namespace private var pill

    /// The rect of a tab's slot, in the coordinate space of a container whose
    /// size is `container` and whose bottom edge is the bar's safe-area edge.
    static func slotFrame(for tab: AppTab, in container: CGSize) -> CGRect {
        let index = CGFloat(tabs.firstIndex(of: tab) ?? 0)
        let barWidth = container.width - horizontalMargin * 2
        let slotWidth = (barWidth - innerPadding * 2) / CGFloat(tabs.count)
        let barTop = container.height + bottomOffset - height
        return CGRect(
            x: horizontalMargin + innerPadding + slotWidth * index,
            y: barTop + innerPadding,
            width: slotWidth,
            height: height - innerPadding * 2
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.tabs, id: \.self) { tab in
                Button {
                    Haptics.selection()
                    onSelect(tab)
                } label: {
                    slot(tab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab == .create ? "Create" : tab.title.capitalized)
                .accessibilityAddTraits(tab == selection ? .isSelected : [])
            }
        }
        .padding(Self.innerPadding)
        .frame(height: Self.height)
        .background { glass }
        .padding(.horizontal, Self.horizontalMargin)
        .offset(y: Self.bottomOffset)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selection)
    }

    @ViewBuilder
    private func slot(_ tab: AppTab) -> some View {
        if tab == .create {
            CreateTabButton()
        } else {
            let isSelected = tab == selection
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .symbolVariant(.fill)
                    .font(.system(size: 19, weight: .medium))
                    .frame(height: 24)
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? ArchiveTheme.collectedRed : ArchiveTheme.ink)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    Capsule()
                        .fill(ArchiveTheme.ink.opacity(0.07))
                        .matchedGeometryEffect(id: "selection", in: pill)
                }
            }
        }
    }

    @ViewBuilder
    private var glass: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        } else {
            Capsule()
                .fill(.regularMaterial)
                .overlay { Capsule().stroke(.white.opacity(0.6), lineWidth: 1) }
                .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
        }
    }
}

// Feeds the Lab collage editor with the photos of objects in the archive.
struct ArchiveLabCollectionProvider: LabCollectionProviding {
    let items: [CollectibleItem]

    func fetchCollectionItems() async -> [LabCollectionItem] {
        items.compactMap { item in
            guard let image = item.uploadedImage ?? item.imageName.flatMap({ UIImage(named: $0) }) else {
                return nil
            }
            return LabCollectionItem(
                id: item.id,
                name: item.title,
                maker: item.creator,
                year: item.year.map(String.init) ?? "",
                category: item.category.title,
                image: image
            )
        }
    }
}
