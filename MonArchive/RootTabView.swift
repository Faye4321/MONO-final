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

    /// The blank CREATE tab only reserves the middle slot. It is never
    /// selected, so the system's liquid-glass selection pill never appears
    /// behind the custom button; Create opens full screen instead.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == .create { showingCreate = true } else { selection = newValue }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView(
                onProfileTapped: { selection = .me },
                onOpenLab: { selection = .lab }
            )
            .tabItem {
                Label("EXPLORE", systemImage: "safari")
            }
            .tag(AppTab.explore)

            CollectionView(onProfileTapped: { selection = .me })
                .tabItem { Label("COLLECTION", systemImage: "rectangle.stack") }
                .tag(AppTab.collection)

            // The visible CREATE control is the round button overlaid below;
            // the system item stays blank so it doesn't show through.
            Color.clear
                .tabItem { Text("") }
                .tag(AppTab.create)

            LabRootView(collectionProvider: ArchiveLabCollectionProvider(items: store.activeItems))
                .tabItem { Label("LAB", systemImage: "wand.and.stars") }
                .tag(AppTab.lab)

            ProfileView()
                .tabItem {
                    Label("ME", systemImage: "person")
                }
                .tag(AppTab.me)
        }
        .tint(ArchiveTheme.collectedRed)
        .overlay(alignment: .bottom) {
            Button {
                showingCreate = true
            } label: {
                CreateTabButton()
            }
            .buttonStyle(.plain)
            .padding(.bottom, CreateTabButton.bottomPadding)
            .accessibilityLabel("Create")
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

// Emphasised, inverted CREATE control centred on the tab bar.
struct CreateTabButton: View {
    var isSelected = false

    static let diameter: CGFloat = 46
    /// Negative nudges the button down so it sits on the vertical centre of
    /// the floating tab bar rather than on the safe-area edge.
    static let bottomPadding: CGFloat = -5

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: Self.diameter, height: Self.diameter)
            .background(isSelected ? ArchiveTheme.collectedRed : ArchiveTheme.ink, in: Circle())
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
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
