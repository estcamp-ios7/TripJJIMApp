import Foundation

struct PlaceCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct TripRegionLocation: Codable, Equatable {
    let coordinate: PlaceCoordinate
    let sourceName: String?
    let sourceAddress: String?
    let latitudeDelta: Double?
    let longitudeDelta: Double?
    let boundsCenter: PlaceCoordinate?
}

enum ReminderPreset: String, Codable, CaseIterable, Identifiable {
    case atVisit, tenMinutesBefore, thirtyMinutesBefore, oneHourBefore, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atVisit: "방문 시간"
        case .tenMinutesBefore: "10분 전"
        case .thirtyMinutesBefore: "30분 전"
        case .oneHourBefore: "1시간 전"
        case .custom: "직접 설정"
        }
    }

    var secondsBeforeVisit: TimeInterval {
        switch self {
        case .atVisit, .custom: 0
        case .tenMinutesBefore: 600
        case .thirtyMinutesBefore: 1_800
        case .oneHourBefore: 3_600
        }
    }
}

struct Visit: Codable, Identifiable, Equatable {
    var id = UUID()
    var placeName: String
    var visitDate: Date
    var coordinate: PlaceCoordinate
    var address: String? = nil
    var memo: String? = nil
    var reminderEnabled = false
    var customReminderDate: Date?

    // Optional so JSON saved before presets were introduced still decodes.
    var reminderPreset: ReminderPreset?

    var selectedReminderPreset: ReminderPreset {
        get { reminderPreset ?? (customReminderDate == nil ? .atVisit : .custom) }
        set {
            if newValue == .custom && customReminderDate == nil {
                customReminderDate = reminderDate
            }
            reminderPreset = newValue
        }
    }

    var reminderDate: Date {
        if selectedReminderPreset == .custom { return customReminderDate ?? visitDate }
        return visitDate.addingTimeInterval(-selectedReminderPreset.secondsBeforeVisit)
    }

    var reminderBody: String {
        switch selectedReminderPreset {
        case .atVisit: "\(placeName) 방문 시간입니다."
        case .custom: "\(placeName) 방문 알림입니다."
        default: "\(placeName) 방문 \(selectedReminderPreset.title)입니다."
        }
    }

    func hasPastReminderChange(from original: Visit, now: Date = .now) -> Bool {
        reminderEnabled && reminderDate <= now &&
            (!original.reminderEnabled || reminderDate != original.reminderDate ||
             selectedReminderPreset != original.selectedReminderPreset)
    }
}

struct Trip: Codable, Identifiable {
    var id = UUID()
    var name: String
    var visits: [Visit] = []

    // Optional fields keep previously saved trips readable.
    var startDate: Date?
    var endDate: Date?
    var region: String?
    var regionLocation: TripRegionLocation?

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
