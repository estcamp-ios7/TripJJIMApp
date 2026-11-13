struct TravelPreference: Equatable {
    enum Region: Equatable {
        case selected(String)
        case undecided

        var title: String {
            switch self {
            case .selected(let name): name
            case .undecided: "아직 정하지 않았어요"
            }
        }
    }

    enum Duration: Int, CaseIterable {
        case dayTrip = 1, oneNight, twoNights, threeNightsOrMore

        var title: String {
            switch self {
            case .dayTrip: "당일 여행"
            case .oneNight: "1박 2일"
            case .twoNights: "2박 3일"
            case .threeNightsOrMore: "3박 4일 이상"
            }
        }

        func includes(days count: Int) -> Bool {
            self == .threeNightsOrMore ? count >= rawValue : count == rawValue
        }
    }

    enum DailyVisits: CaseIterable {
        case oneToTwo, threeToFour, fiveOrMore, unspecified

        var title: String {
            switch self {
            case .oneToTwo: "1~2곳"
            case .threeToFour: "3~4곳"
            case .fiveOrMore: "5곳 이상"
            case .unspecified: "아직 모르겠어요"
            }
        }

        var bounds: (minimum: Int, maximum: Int?)? {
            switch self {
            case .oneToTwo: (1, 2)
            case .threeToFour: (3, 4)
            case .fiveOrMore: (5, nil)
            case .unspecified: nil
            }
        }
    }

    var region: Region?
    var duration: Duration?
    var theme: TravelTheme?
    var dailyVisits: DailyVisits?
}

// P2 evaluates existing courses only. Visit density is explanatory, never a filter.
enum PersonalizedRecommendation {
    enum InputError: Error, Equatable {
        case missingAnswers
        case unsupportedRegion
    }

    struct Match: Identifiable {
        let course: RecommendedCourse
        let reasons: [String]
        let dailyVisits: [String]
        var id: String { course.id }
    }

    static func evaluate(_ preference: TravelPreference, courses: [RecommendedCourse]) throws -> [Match] {
        guard let region = preference.region, let duration = preference.duration,
              let theme = preference.theme, let density = preference.dailyVisits else {
            throw InputError.missingAnswers
        }
        let allowed: Set<String>?
        switch region {
        case .undecided: allowed = nil
        case .selected(let name):
            guard let ids = regionCourses[normalize(name)] else { throw InputError.unsupportedRegion }
            allowed = ids
        }
        return courses.filter {
            (allowed?.contains($0.id) ?? true) && duration.includes(days: $0.dayCount) && $0.theme == theme
        }.map { course in
            let regionReason = allowed == nil ? "지역 제한 없이 찾았어요." : "선택한 지역의 코스예요."
            let counts = course.days.sorted { $0.number < $1.number }.map { day in
                let count = day.places.count
                let actual = "\(day.number)일차 등록 장소: \(count)곳"
                guard let bounds = density.bounds else { return actual }
                let fits = count >= bounds.minimum && (bounds.maximum.map { count <= $0 } ?? true)
                return actual + (fits ? " · 선택한 \(density.title) 범위예요." : " · 선택한 \(density.title)과 달라요.")
            }
            return Match(course: course, reasons: [regionReason, "\(course.duration) · 선택한 \(theme.title) 테마예요."], dailyVisits: counts)
        }
    }

    private static func normalize(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    // Explicit full names and verified aliases; no substring or ancestor guessing.
    private static let regionCourses: [String: Set<String>] = {
        var map: [String: Set<String>] = [:]
        for name in ["제주", "제주도", "제주특별자치도", "제주 서귀포시", "제주특별자치도 서귀포시",
                     "제주 서귀포시 성산읍", "제주특별자치도 서귀포시 성산읍"] {
            map[name] = ["jeju-seongsan"]
        }
        for name in ["부산", "부산광역시"] { map[name] = ["busan-haeundae", "busan-old-town"] }
        for name in ["부산 해운대구", "부산광역시 해운대구"] { map[name] = ["busan-haeundae"] }
        for name in ["부산 중구", "부산광역시 중구", "부산 중구 남포동·광복동"] { map[name] = ["busan-old-town"] }
        return map
    }()
}
