import Foundation
import OSLog
import UserNotifications

@MainActor
struct ReminderScheduler {
    private let center = UNUserNotificationCenter.current()
    private let prefix = "tripjjim.visit."
    private let logger = Logger(subsystem: "com.tripjjim.TripJJIM", category: "Reminders")

    func requestPermission() async throws -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        return settings.authorizationStatus.allowsReminders
    }

    func reconcile(with visits: [Visit]) async throws {
        let now = Date()
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(prefix) }
        let requested = settings.authorizationStatus.allowsReminders
            ? visits.filter { $0.reminderEnabled && $0.reminderDate > now }
            : []
        let activeIDs = Set(requested.map { identifier(for: $0) })

        let toCancel = pending.map(\.identifier).filter { !activeIDs.contains($0) }
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toCancel)
        }

        let existing = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })
        var failure: Error?
        for visit in requested {
            let id = identifier(for: visit)
            let body = visit.reminderBody
            if let request = existing[id],
               request.content.body == body,
               let trigger = request.trigger as? UNCalendarNotificationTrigger,
               trigger.nextTriggerDate() == visit.reminderDate {
                continue
            }

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
            let components = calendar.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
                from: visit.reminderDate
            )
            let content = UNMutableNotificationContent()
            content.title = "TripJJIM 일정 알림"
            content.body = body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                // 동일한 ID로 등록하면 이전 예약이 새 장소 이름과 시각으로 교체됩니다.
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            } catch {
                let systemError = error as NSError
                logger.error("Could not schedule visit reminder: \(systemError.domain, privacy: .public) (\(systemError.code)). \(systemError.localizedDescription, privacy: .private)")
                center.removePendingNotificationRequests(withIdentifiers: [id])
                failure = error
            }
        }
        #if DEBUG
        await logPendingRequestsForUITests()
        #endif
        if let failure { throw failure }
    }

    private func identifier(for visit: Visit) -> String { prefix + visit.id.uuidString }

    #if DEBUG
    private func logPendingRequestsForUITests() async {
        guard ProcessInfo.processInfo.environment["TRIPJJIM_VERIFY_REMINDERS"] == "1" else { return }
        let pending = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(prefix) }
        let snapshot = pending.sorted { $0.identifier < $1.identifier }.map { request in
            let trigger = request.trigger as? UNCalendarNotificationTrigger
            let date = trigger?.nextTriggerDate()?.ISO8601Format() ?? "unknown"
            return "\(request.identifier) | \(request.content.body) | \(date) | repeats=\(trigger?.repeats ?? false)"
        }.joined(separator: "; ")
        Logger(subsystem: "com.tripjjim.TripJJIM", category: "ReminderVerification")
            .notice("pending[\(pending.count)] \(snapshot, privacy: .public)")
    }
    #endif
}

private extension UNAuthorizationStatus {
    var allowsReminders: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }
}
