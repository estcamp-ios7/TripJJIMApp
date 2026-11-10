import Foundation

struct PlaceCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct Visit: Codable, Identifiable, Equatable {
    var id = UUID()
    var placeName: String
    var visitDate: Date
    let coordinate: PlaceCoordinate
    var reminderEnabled = false
    var customReminderDate: Date?

    var reminderDate: Date { customReminderDate ?? visitDate }
}

struct Trip: Codable, Identifiable {
    var id = UUID()
    var name: String
    var visits: [Visit] = []

    var days: [VisitDay] {
        let grouped = Dictionary(grouping: visits) { Calendar.current.startOfDay(for: $0.visitDate) }
        return grouped.keys.sorted().map { date in
            VisitDay(date: date, visits: (grouped[date] ?? []).sorted(by: Self.isEarlier))
        }
    }

    func nextVisit(after date: Date) -> Visit? {
        visits.filter { $0.visitDate > date }.min(by: Self.isEarlier)
    }

    private static func isEarlier(_ first: Visit, _ second: Visit) -> Bool {
        if first.visitDate == second.visitDate {
            return first.id.uuidString < second.id.uuidString
        }
        return first.visitDate < second.visitDate
    }
}

struct VisitDay: Identifiable {
    var id: Date { date }
    let date: Date
    let visits: [Visit]
}

extension Date {
    private static let korean = Locale(identifier: "ko_KR")

    var dayLabel: String {
        formatted(.dateTime.year().month().day().weekday(.wide).locale(Self.korean))
    }

    var timeLabel: String {
        formatted(.dateTime.hour().minute().locale(Self.korean))
    }
}
