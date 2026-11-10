import Foundation
import Observation

@MainActor
@Observable
final class TripStore {
    private static let storageKey = "tripjjim.trips"
    private let defaults: UserDefaults
    private let reminders = ReminderScheduler()
    @ObservationIgnored private var reminderTask: Task<Void, Never>?
    private var didLoadTrips = true

    private(set) var trips: [Trip] = []
    var storageError: String?
    var reminderError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.storageKey) else { return }
        do {
            trips = try JSONDecoder().decode([Trip].self, from: data)
        } catch {
            didLoadTrips = false
            storageError = "저장된 여행을 불러오지 못했습니다."
        }
    }

    func trip(withID id: Trip.ID) -> Trip? {
        trips.first { $0.id == id }
    }

    @discardableResult
    func saveTrip(name: String, id: Trip.ID? = nil) -> Bool {
        var updated = trips
        if let id {
            guard let index = updated.firstIndex(where: { $0.id == id }) else { return false }
            updated[index].name = name
        } else {
            updated.append(Trip(name: name))
        }
        return persist(updated)
    }

    func deleteTrip(_ id: Trip.ID) {
        persist(trips.filter { $0.id != id })
    }

    @discardableResult
    func saveVisit(_ visit: Visit, in tripID: Trip.ID) -> Bool {
        var updated = trips
        guard let tripIndex = updated.firstIndex(where: { $0.id == tripID }) else { return false }
        if let visitIndex = updated[tripIndex].visits.firstIndex(where: { $0.id == visit.id }) {
            updated[tripIndex].visits[visitIndex] = visit
        } else {
            updated[tripIndex].visits.append(visit)
        }
        return persist(updated)
    }

    func deleteVisit(_ id: Visit.ID, in tripID: Trip.ID) {
        var updated = trips
        guard let index = updated.firstIndex(where: { $0.id == tripID }) else { return }
        updated[index].visits.removeAll { $0.id == id }
        persist(updated)
    }

    func requestReminderPermission() async throws -> Bool {
        try await reminders.requestPermission()
    }

    func refreshReminders() {
        guard didLoadTrips else { return }
        let previous = reminderTask
        let visits = trips.flatMap(\.visits)
        reminderTask = Task { [weak self, reminders] in
            // 저장과 삭제가 이어져도 알림 갱신 순서를 유지합니다.
            await previous?.value
            do {
                try await reminders.reconcile(with: visits)
            } catch {
                self?.reminderError = "일정은 저장됐지만 iOS에 방문 알림을 등록하지 못했습니다. 앱을 다시 열면 시간이 지나지 않은 알림을 다시 시도합니다."
            }
        }
    }

    @discardableResult
    private func persist(_ updated: [Trip]) -> Bool {
        guard didLoadTrips else {
            storageError = "저장된 여행을 불러오지 못해 변경 사항을 저장할 수 없습니다."
            return false
        }
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: Self.storageKey)
            trips = updated
            refreshReminders()
            return true
        } catch {
            storageError = "여행 정보를 저장하지 못했습니다."
            return false
        }
    }
}
