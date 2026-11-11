// swift-tools-version: 5.9
import PackageDescription

// macOS test harness for production model/repository/store code. It does not
// replace the iOS app build or simulator interaction checks.
let package = Package(
    name: "MONOExploreCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ExploreCore", targets: ["ExploreCore"])],
    targets: [
        .target(
            name: "ExploreCore",
            path: "MonArchive",
            exclude: [
                "Assets.xcassets", "Resources", "archive_bjd.wav", "archive_photocard.wav", "archive_poster.wav", "archive_vinyl.wav",
                "AppTheme.swift", "ArchiveSearchView.swift", "ArtworkView.swift", "ChatView.swift", "CollectionCalendarView.swift",
                "CollectionCard.swift", "CollectionStore.swift", "CollectionView.swift", "CreateFlowView.swift", "CreateSharedCollectionView.swift",
                "CSVImporter.swift", "FriendProfileView.swift", "FriendsView.swift", "HomeSupport.swift", "HomeView.swift", "ImageStore.swift",
                "ItemDetailView.swift", "JourneyViews.swift", "LabEditorViews.swift", "LabFlowViews.swift", "LabImageServices.swift", "LabModels.swift",
                "Memory.swift", "MemoryComponents.swift", "MockData.swift", "MomentEditorView.swift", "MonArchiveApp.swift", "MonoLogoView.swift",
                "OnboardingFlow.swift", "ProfileView.swift", "RootTabView.swift", "SeedData.swift", "ShareCard.swift", "SharedCollectionDetailView.swift",
                "ShelfDetailView.swift", "SocialModels.swift", "SocialStore.swift", "Explore/ExploreComponents.swift", "Explore/ExploreSearchView.swift",
                "Explore/ExplorePreviewData.swift"
            ],
            sources: ["Models.swift", "ShopPicks.swift", "Explore/ExploreCore.swift", "Explore/ExploreRepositories.swift", "Explore/ExploreStore.swift"]
        ),
        .testTarget(name: "ExploreCoreTests", dependencies: ["ExploreCore"], path: "Tests/ExploreCoreTests")
    ]
)
