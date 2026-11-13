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

    enum TripEditError: LocalizedError {
        case missingName, missingRegion, invalidPeriod, visitOutsidePeriod, missingTrip, storage

        var errorDescription: String? {
            switch self {
            case .missingName: "여행 이름을 입력해 주세요."
            case .missingRegion: "여행 지역을 입력하거나 검색 결과에서 선택해 주세요."
            case .invalidPeriod: "종료일은 시작일과 같거나 이후여야 합니다."
            case .visitOutsidePeriod: "저장된 방문 일정이 모두 포함되도록 여행 기간을 선택해 주세요."
            case .missingTrip: "수정할 여행을 찾을 수 없습니다."
            case .storage: "여행 정보를 저장하지 못했습니다. 다시 시도해 주세요."
            }
        }
    }

    func saveTrip(name: String, startDate: Date, endDate: Date, region: String, id: Trip.ID?, regionLocation: TripRegionLocation? = nil, initialVisits: [Visit] = []) throws -> Trip.ID {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = region.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw TripEditError.missingName }
        guard !region.isEmpty else { throw TripEditError.missingRegion }

        let calendar = Calendar.current
        let first = calendar.startOfDay(for: startDate)
        let last = calendar.startOfDay(for: endDate)
        guard first <= last else { throw TripEditError.invalidPeriod }

        var updated = trips
        let index: Int
        if let id {
            guard let existing = updated.firstIndex(where: { $0.id == id }) else {
                throw TripEditError.missingTrip
            }
            index = existing
        } else {
            index = updated.endIndex
            updated.append(Trip(name: name, visits: initialVisits))
        }

        let periodChanged = updated[index].startDate != first || updated[index].endDate != last
        if periodChanged && updated[index].visits.contains(where: {
            let day = calendar.startOfDay(for: $0.visitDate)
            return day < first || day > last
        }) {
            throw TripEditError.visitOutsidePeriod
        }

        updated[index].name = name
        updated[index].startDate = first
        updated[index].endDate = last
        if let regionLocation {
            updated[index].regionLocation = regionLocation
        } else if updated[index].region != region {
            updated[index].regionLocation = nil
        }
        updated[index].region = region
        guard persist(updated) else { throw TripEditError.storage }
        return updated[index].id
    }

    @discardableResult
    func deleteTrip(_ id: Trip.ID) -> Bool {
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

    @discardableResult
    func deleteVisit(_ id: Visit.ID, in tripID: Trip.ID) -> Bool {
        var updated = trips
        guard let index = updated.firstIndex(where: { $0.id == tripID }) else { return false }
        updated[index].visits.removeAll { $0.id == id }
        return persist(updated)
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
                self?.reminderError = "일정은 저장됐지만 iOS에 일정 알림을 등록하지 못했습니다. 앱을 다시 열면 시간이 지나지 않은 알림을 다시 시도합니다."
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
