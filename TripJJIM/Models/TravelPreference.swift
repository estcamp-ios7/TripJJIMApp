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
