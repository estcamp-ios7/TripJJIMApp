#if DEBUG
import Foundation

@MainActor
enum PreviewData {
    static let startDate = Calendar.current.startOfDay(for: .now)
    static let secondDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate

    static let marketVisit = Visit(
        placeName: "제주 동문시장",
        visitDate: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: startDate) ?? startDate,
        coordinate: PlaceCoordinate(latitude: 33.5125, longitude: 126.5261),
        address: "제주특별자치도 제주시 관덕로14길 20",
        memo: "점심을 먹고 시장 간식 둘러보기",
        reminderEnabled: true,
        reminderPreset: .thirtyMinutesBefore
    )

    static let beachVisit = Visit(
        placeName: "함덕해수욕장",
        visitDate: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: secondDate) ?? secondDate,
        coordinate: PlaceCoordinate(latitude: 33.5434, longitude: 126.6698),
        address: "제주특별자치도 제주시 조천읍 조함해안로 525",
        memo: "해변을 산책하고 카페 들르기"
    )

    static let trip = Trip(
        name: "제주 여행",
        visits: [marketVisit, beachVisit],
        startDate: startDate,
        endDate: secondDate,
        region: "제주특별자치도",
        regionLocation: TripRegionLocation(
            coordinate: PlaceCoordinate(latitude: 33.38, longitude: 126.55),
            sourceName: "제주특별자치도",
            sourceAddress: "대한민국 제주특별자치도",
            latitudeDelta: 0.6,
            longitudeDelta: 0.8,
            boundsCenter: nil
        )
    )

    static let course = RecommendedCourse(
        id: "preview-jeju",
        title: "제주의 시장과 바다",
        summary: "제주의 대표 시장과 푸른 해변을 여유롭게 둘러보는 코스예요.",
        region: "제주특별자치도",
        theme: .coast,
        imageName: nil,
        days: [
            RecommendedCourseDay(
                number: 1,
                summary: "제주 도심의 먹거리와 문화를 만나요.",
                places: [
                    RecommendedPlace(
                        id: "preview-market",
                        name: "제주 동문시장",
                        area: "제주시",
                        coordinate: marketVisit.coordinate,
                        order: 1,
                        category: .market,
                        reason: "제주의 다양한 먹거리를 한곳에서 만날 수 있어요.",
                        suggestedTime: "12:30",
                        source: URL(fileURLWithPath: "/"),
                        coordinateSource: nil
                    )
                ]
            ),
            RecommendedCourseDay(
                number: 2,
                summary: "바다를 바라보며 천천히 쉬어 가요.",
                places: [
                    RecommendedPlace(
                        id: "preview-beach",
                        name: "함덕해수욕장",
                        area: "조천읍",
                        coordinate: beachVisit.coordinate,
                        order: 1,
                        category: .attraction,
                        reason: "맑은 바다와 완만한 해변 풍경이 아름다워요.",
                        suggestedTime: "15:00",
                        source: URL(fileURLWithPath: "/"),
                        coordinateSource: nil
                    )
                ]
            )
        ]
    )

    static func makeStore(trips: [Trip]? = nil) -> TripStore {
        let defaults = UserDefaults(suiteName: "TripJJIM.Preview.\(UUID().uuidString)") ?? UserDefaults()
        if let data = try? JSONEncoder().encode(trips ?? [trip]) {
            defaults.set(data, forKey: "tripjjim.trips")
        }
        return TripStore(defaults: defaults)
    }
}
#endif
