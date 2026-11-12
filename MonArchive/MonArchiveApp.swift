import SwiftUI
import UIKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        print("Firebase 初始化成功")
        return true
    }
}

@main
struct MonArchiveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var delegate

    @StateObject private var store = CollectionStore()
    @StateObject private var socialStore = SocialStore()
    @StateObject private var profileStore = CloudProfileStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .environmentObject(socialStore)
                .environmentObject(profileStore)
                .task {
                    profileStore.startCloud()
                    ProfileStore.shared.connect(cloud: profileStore)
                    store.startCloud()
                    socialStore.startCloud(collectionStore: store)
                }
        }
    }
}

