import Foundation

enum TravelTheme: String, CaseIterable, Codable {
    case nature, coast, culture

    var title: String {
        switch self {
        case .nature: "자연·힐링"
        case .coast: "바다·도시"
        case .culture: "문화·맛집"
        }
    }
}

struct RecommendedCourse: Codable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let region: String
    let theme: TravelTheme
    let imageName: String?
    let days: [RecommendedCourseDay]

    var dayCount: Int { days.count }
    var nightCount: Int { max(0, dayCount - 1) }
    var duration: String { nightCount == 0 ? "당일 여행" : "\(nightCount)박 \(dayCount)일" }
}

struct RecommendedCourseDay: Codable, Identifiable {
    var id: Int { number }
    let number: Int
    let summary: String?
    let places: [RecommendedPlace]
}

struct RecommendedPlace: Codable, Identifiable {
    enum Category: String, Codable {
        case attraction, restaurant, cafe, market, culture

        var title: String {
            switch self {
            case .attraction: "관광지"
            case .restaurant: "식당"
            case .cafe: "카페"
            case .market: "시장"
            case .culture: "문화"
            }
        }
    }

    let id: String
    let name: String
    let area: String
    let coordinate: PlaceCoordinate?
    let order: Int
    let category: Category
    let reason: String
    let suggestedTime: String?
    let source: URL
    let coordinateSource: URL?
}

extension RecommendedCourse {
    enum ImportError: LocalizedError {
        case invalidSchedule

        var errorDescription: String? { "코스의 여행 날짜를 계산할 수 없어요." }
    }

    func visitDay(_ number: Int, starting startDate: Date, calendar: Calendar) throws -> Date {
        guard number > 0, number <= dayCount,
              let date = calendar.date(byAdding: .day, value: number - 1, to: calendar.startOfDay(for: startDate))
        else { throw ImportError.invalidSchedule }
        return calendar.startOfDay(for: date)
    }

    func makeVisits(starting startDate: Date, calendar: Calendar) throws -> [Visit] {
        try days.sorted { $0.number < $1.number }.flatMap { day in
            let date = try visitDay(day.number, starting: startDate, calendar: calendar)
            return day.places.sorted { $0.order < $1.order }.map { place in
                Visit(placeName: place.name, visitDate: date, coordinate: place.coordinate,
                      address: place.area, untimedOrder: place.order)
            }
        }
    }
}
