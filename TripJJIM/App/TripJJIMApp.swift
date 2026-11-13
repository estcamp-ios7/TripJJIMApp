import SwiftUI
import UserNotifications

private struct RootTabView: View {
    private enum TabSelection: Hashable {
        case home
        case trips
    }

    @State private var selectedTab: TabSelection = .home
    @State private var tripPath: [Trip.ID] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("홈", systemImage: "house", value: TabSelection.home) {
                HomeView { tripID in
                    tripPath = tripID.map { [$0] } ?? []
                    selectedTab = .trips
                }
            }

            Tab("내 여행", systemImage: "calendar", value: TabSelection.trips) {
                TripListView(path: $tripPath)
            }
        }
    }
}

@main
struct TripJJIMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = TripStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
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
