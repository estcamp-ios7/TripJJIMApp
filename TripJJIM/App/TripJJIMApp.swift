import SwiftUI
import UserNotifications
import Observation

@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case home
        case map
    }

    var selectedTab: Tab = .home
    var homePath: [Trip.ID] = []
    var mapPath: [Trip.ID] = []

    func showHome() {
        homePath.removeAll()
        selectedTab = .home
    }

    func showMap(for tripID: Trip.ID) {
        mapPath = [tripID]
        selectedTab = .map
    }
}

private struct RootTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: Binding(
            get: { router.selectedTab },
            set: { tab in
                if tab == .home {
                    router.showHome()
                } else {
                    router.selectedTab = tab
                }
            }
        )) {
            Tab("홈", systemImage: "house", value: AppRouter.Tab.home) {
                TripListView(path: $router.homePath)
            }

            Tab("지도", systemImage: "map", value: AppRouter.Tab.map) {
                TripMapTabView(path: $router.mapPath)
            }
        }
    }
}

@main
struct TripJJIMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = TripStore()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(router)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .tint(Color.tripAccent)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active { store.refreshReminders() }
                }
                .alert("TripJJIM", isPresented: Binding(
                    get: { store.storageError != nil || store.reminderError != nil },
                    set: {
                        if !$0 {
                            store.storageError = nil
                            store.reminderError = nil
                        }
                    }
                )) {
                    Button("확인", role: .cancel) {}
                } message: {
                    Text(store.storageError ?? store.reminderError ?? "")
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
