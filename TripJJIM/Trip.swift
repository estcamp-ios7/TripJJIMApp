import Foundation

struct PlaceCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct Visit: Codable, Identifiable, Equatable {
    var id = UUID()
    var placeName: String
    var visitDate: Date
    var coordinate: PlaceCoordinate
    var address: String? = nil
    var reminderEnabled = false
    var customReminderDate: Date?

    var reminderDate: Date { customReminderDate ?? visitDate }
}

struct Trip: Codable, Identifiable {
    var id = UUID()
    var name: String
    var visits: [Visit] = []

    // Optional fields keep previously saved trips readable.
    var startDate: Date?
    var endDate: Date?
    var region: String?

    var travelSummary: String? {
        var parts = [region].compactMap { $0 }.filter { !$0.isEmpty }
        if let startDate, let endDate {
            let calendar = Calendar.current
            let first = calendar.startOfDay(for: startDate)
            let last = calendar.startOfDay(for: endDate)
            let nights = calendar.dateComponents([.day], from: first, to: last).day ?? 0
            let style = Date.FormatStyle(date: .numeric).locale(Locale(identifier: "ko_KR"))
            let firstLabel = first.formatted(style)
            if nights == 0 {
                parts.append("\(firstLabel) · 당일 여행")
            } else {
                parts.append("\(firstLabel) ~ \(last.formatted(style)) · \(nights)박 \(nights + 1)일")
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

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
