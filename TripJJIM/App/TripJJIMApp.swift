import SwiftUI
import UserNotifications

@main
struct TripJJIMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = TripStore()

    var body: some Scene {
        WindowGroup {
            TripListView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .tint(.teal)
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
