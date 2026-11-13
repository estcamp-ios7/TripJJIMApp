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
