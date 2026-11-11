import SwiftUI

@main
struct MonArchiveApp: App {
    @StateObject private var store = CollectionStore()
    @StateObject private var socialStore = SocialStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .environmentObject(socialStore)
        }
    }
}
