import CoreLocation
import XCTest

final class TripFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomePlanningRoutesAndTripCreation() {
        let app = XCUIApplication()
        let trip = "Home trip \(UUID().uuidString.prefix(6))"
        app.launch()

        let heading = app.staticTexts["어떤 여행을 떠나볼까요?"]
        XCTAssertTrue(heading.waitForExistence(timeout: 10))
        attachScreen("Home upper cards", in: app)

        for (identifier, title) in [
            ("home-recommendations", "추천 여행 기능을 준비 중이에요."),
            ("home-preferences", "취향에 맞는 여행 계획 기능을 준비 중이에요.")
        ] {
            app.buttons[identifier].tap()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
            app.buttons["닫기"].tap()
        }

        app.swipeUp()
        let create = app.buttons["home-create-trip"]
        XCTAssertTrue(create.isHittable)
        attachScreen("Home lower cards", in: app)
        create.tap()
        XCTAssertTrue(app.textFields["trip-name"].waitForExistence(timeout: 5))
        app.buttons["취소"].tap()
        XCTAssertTrue(create.waitForExistence(timeout: 5))

        create.tap()
        fillTrip(name: trip, region: "Seoul", in: app)
        app.buttons["save-trip"].tap()
        XCTAssertTrue(app.navigationBars["나의 여행"].waitForExistence(timeout: 5))
        tripRow(named: trip, in: app).tap()
        app.buttons["지도"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["trip-map"].firstMatch.waitForExistence(timeout: 10))

        app.buttons["홈"].tap()
        app.buttons["내 여행"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["trip-map"].firstMatch.waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        showTripList(in: app)
        deleteTrip(trip, in: app)
    }

    func testBulkDeleteTrips() {
        let app = XCUIApplication()
        let suffix = UUID().uuidString.prefix(6)
        let firstTrip = "Bulk first \(suffix)"
        let secondTrip = "Bulk second \(suffix)"
        app.launch()
        showTripList(in: app)

        createTrip(firstTrip, in: app)
        showTripList(in: app)
        createTrip(secondTrip, in: app)
        showTripList(in: app)

        app.buttons["edit-trips"].tap()
        selectTrip(firstTrip, in: app)
        selectTrip(secondTrip, in: app)

        let delete = app.buttons["delete-selected-trips"]
        XCTAssertTrue(delete.isEnabled)
        delete.tap()
        app.alerts.buttons["2개 삭제"].tap()

        XCTAssertFalse(app.staticTexts[firstTrip].exists)
        XCTAssertFalse(app.staticTexts[secondTrip].exists)
        XCTAssertEqual(app.buttons["edit-trips"].label, "편집")
    }

    func testOfficialRegionSelectionSurvivesRelaunch() {
        let app = XCUIApplication()
        let trip = "Region trip \(UUID().uuidString.prefix(6))"
        app.launch()
        openTripEditor(in: app)
        app.textFields["trip-name"].tap()
        app.textFields["trip-name"].typeText(trip)
        app.buttons["지도에서 지역 찾기"].tap()

        let search = app.textFields["예: 제주"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        attachScreen("Region search empty", in: app)
        search.tap()
        search.typeText("Seoul")
        let result = app.buttons["trip-region-result-1100000000"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        attachScreen("Official region search result", in: app)
        result.tap()

        let field = app.textFields["trip-region"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertEqual(field.value as? String, "서울특별시")
        app.buttons["save-trip"].tap()
        XCTAssertTrue(app.navigationBars[trip].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        openTrip(trip, in: app)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "서울특별시")).firstMatch.waitForExistence(timeout: 5))
    }

    func testPlaceSearchKeepsDirectSearchAvailableWhileTyping() {
        let app = XCUIApplication()
        app.launch()
        createTrip("Search trip \(UUID().uuidString.prefix(6))", in: app)
        app.buttons["장소 검색"].tap()

        let field = app.textFields["장소 이름 또는 주소"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["show-trip-map"].exists)
        let guide = app.staticTexts["어디를 방문할 예정인가요?"]
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        attachScreen("Place search empty", in: app)
        field.tap()
        field.typeText("CU")
        XCTAssertFalse(guide.exists)
        if app.staticTexts["자동완성 제안"].waitForExistence(timeout: 4) {
            attachScreen("Place search suggestions", in: app)
        }
        XCTAssertTrue(app.buttons["place-search-submit"].isEnabled)
        app.buttons["검색어 지우기"].tap()
        XCTAssertFalse(app.buttons["place-search-submit"].isEnabled)
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["자동완성 제안"].exists)
        XCTAssertFalse(app.buttons["다른 지역도 검색"].exists)
    }

    func testMapPinSurvivesRelaunch() {
        let app = XCUIApplication()
        let trip = "Map trip \(UUID().uuidString.prefix(6))"
        let place = "Cafe"
        app.launch()

        createTrip(trip, in: app)
        app.buttons["지도에서 장소 추가"].tap()
        app.buttons["장소 검색"].tap()
        XCTAssertTrue(app.navigationBars["장소 검색"].waitForExistence(timeout: 5))
        attachScreen("Place search", in: app)
        app.buttons["닫기"].tap()
        addPin(named: place, in: app)

        let pin = app.buttons["map-pin-\(place)"]
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        attachScreen("Map with saved pin", in: app)
        pin.tap()
        XCTAssertTrue(app.buttons["일정 수정"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[place].exists)
        app.buttons["일정 수정"].tap()
        app.buttons["장소 변경"].tap()
        XCTAssertTrue(app.navigationBars["장소 검색"].waitForExistence(timeout: 5))
        app.buttons["닫기"].tap()
        app.buttons["취소"].tap()
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        showTripList(in: app)
        openTrip(trip, in: app)
        XCTAssertTrue(app.staticTexts["다음 목적지"].exists)
        XCTAssertTrue(app.buttons["visit-row-\(place)"].exists)

        app.terminate()
        app.launch()
        showTripList(in: app)
        let tripRow = tripRow(named: trip, in: app)
        XCTAssertTrue(tripRow.waitForExistence(timeout: 5))
        tripRow.tap()
        XCTAssertTrue(app.buttons["visit-row-\(place)"].exists)
        app.buttons["지도"].tap()
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        pin.tap()
        XCTAssertTrue(app.buttons["일정 수정"].exists)

        showTripList(in: app)
        let renamedTrip = trip + " Edited"
        let homeTripRow = self.tripRow(named: trip, in: app)
        homeTripRow.press(forDuration: 0.9)
        app.buttons["여행 수정"].tap()
        let nameField = app.textFields["trip-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(" Edited")
        app.buttons["save-trip"].tap()
        deleteTrip(renamedTrip, in: app)
    }

    @MainActor
    func testCurrentLocationRequiresPermission() {
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let trip = "Location trip \(UUID().uuidString.prefix(6))"
        app.resetAuthorizationStatus(for: .location)
        app.launch()

        createTrip(trip, in: app)
        app.buttons["지도에서 장소 추가"].tap()
        app.buttons["내 위치"].tap()

        let deny = springboard.alerts.buttons.matching(
            NSPredicate(format: "label IN %@", ["허용 안 함", "Don’t Allow", "Don't Allow"])
        ).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 5))
        deny.tap()
        let notice = app.alerts["내 위치"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        notice.buttons["확인"].tap()
        addPin(named: "Without location permission", in: app)
        XCTAssertTrue(app.buttons["map-pin-Without location permission"].waitForExistence(timeout: 10))

        app.terminate()
        app.resetAuthorizationStatus(for: .location)
        let device = XCUIDevice.shared
        let previousLocation = device.location
        device.location = XCUILocation(location: CLLocation(latitude: 35.1796, longitude: 129.0756))
        defer { device.location = previousLocation }

        app.launch()
        showTripList(in: app)
        openTrip(trip, in: app)
        app.buttons["지도"].tap()
        app.buttons["내 위치"].tap()
        let allow = springboard.alerts.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS[c] %@", "사용하는 동안", "while using")
        ).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        allow.tap()
        let marker = app.descendants(matching: .any).matching(identifier: "current-location").firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 15))

        showTripList(in: app)
        deleteTrip(trip, in: app)
    }

    func testReminderLifecycle() throws {
        let app = XCUIApplication()
        app.launchEnvironment["TRIPJJIM_VERIFY_REMINDERS"] = "1"
        let suffix = UUID().uuidString.prefix(6)
        let trip = "Reminder trip \(suffix)"
        let place = "Reminder Cafe \(suffix)"
        let editedPlace = place + " Updated"
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launch()

        createTrip(trip, in: app)
        app.buttons["지도에서 장소 추가"].tap()
        addPin(named: place, in: app) {
            app.datePickers["visit-date"].tap()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
            let label = tomorrow.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ko_KR")))
            if !app.buttons[label].exists { app.buttons["DatePicker.NextMonth"].tap() }
            app.buttons[label].tap()
            app.navigationBars["방문 일정 추가"].staticTexts["방문 일정 추가"].tap()
            app.swipeUp()
            tapSwitch("visit-reminder", in: app)
            let allow = springboard.alerts.buttons.matching(
                NSPredicate(format: "label IN %@", ["허용", "Allow"])
            ).firstMatch
            if allow.waitForExistence(timeout: 3) { allow.tap() }
            XCTAssertEqual(app.switches["visit-reminder"].value as? String, "1")
            selectPreset("10분 전", in: app)
        }
        showTripList(in: app)
        openTrip(trip, in: app)

        app.terminate()
        app.launch()
        openTrip(trip, in: app)
        editVisit(place, in: app)
        XCTAssertEqual(app.buttons["reminder-preset"].value as? String, "10분 전")
        for preset in ["30분 전", "1시간 전", "방문 시간", "10분 전"] {
            selectPreset(preset, in: app)
            app.buttons["저장"].tap()
            let summary = app.descendants(matching: .any).matching(identifier: "visit-detail-reminder").firstMatch
            XCTAssertTrue(summary.waitForExistence(timeout: 5))
            XCTAssertFalse(summary.label.contains(preset), summary.label)
            XCTAssertTrue(summary.label.contains(":"), summary.label)
            editVisit(place, in: app)
        }
        // Cancel a draft change and check the stored preset survives.
        selectPreset("30분 전", in: app)
        app.buttons["취소"].tap()
        editVisit(place, in: app)
        XCTAssertEqual(app.buttons["reminder-preset"].value as? String, "10분 전")
        // Change the visit date with the relative preset still selected.
        app.datePickers["visit-date"].tap()
        let future = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 2, to: .now))
        let futureLabel = future.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ko_KR")))
        if !app.buttons[futureLabel].exists { app.buttons["DatePicker.NextMonth"].tap() }
        app.buttons[futureLabel].tap()
        app.navigationBars["방문 일정 수정"].staticTexts["방문 일정 수정"].tap()
        app.buttons["저장"].tap()
        editVisit(place, in: app)
        let field = app.textFields["place-name"]
        field.tap()
        field.typeText(" Updated")
        app.swipeUp()
        selectPreset("직접 설정", in: app)
        let datePicker = app.datePickers["reminder-date"]
        XCTAssertTrue(datePicker.waitForExistence(timeout: 5))
        datePicker.tap()
        let newDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 3, to: .now))
        let dayLabel = newDate.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ko_KR")))
        let day = app.buttons[dayLabel]
        if !day.exists { app.buttons["DatePicker.NextMonth"].tap() }
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        app.navigationBars["방문 일정 수정"].staticTexts["방문 일정 수정"].tap()
        app.buttons["저장"].tap()

        editVisit(editedPlace, in: app)
        app.swipeUp()
        tapSwitch("visit-reminder", in: app)
        app.buttons["저장"].tap()
        let disabledSummary = app.descendants(matching: .any).matching(identifier: "visit-detail-reminder").firstMatch
        XCTAssertTrue(disabledSummary.waitForExistence(timeout: 5))
        XCTAssertTrue(disabledSummary.label.contains("알림 꺼짐"))

        editVisit(editedPlace, in: app)
        app.swipeUp()
        tapSwitch("visit-reminder", in: app)
        app.buttons["저장"].tap()

        let row = app.buttons["visit-row-\(editedPlace)"]
        let delete = app.buttons["일정 삭제"]
        if !delete.isHittable { app.swipeUp() }
        delete.tap()
        app.alerts.buttons["삭제"].tap()
        XCTAssertFalse(row.exists)

        app.buttons["지도에서 장소 추가"].tap()
        addPin(named: editedPlace, in: app) {
            app.swipeUp()
            tapSwitch("visit-reminder", in: app)
        }
        showTripList(in: app)
        deleteTrip(trip, in: app)
    }

    private func selectPreset(_ title: String, in app: XCUIApplication) {
        let picker = app.buttons["reminder-preset"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        app.buttons[title].tap()
    }
  
    func testVisitDetailMemoSurvivesRelaunch() throws {
        let app = XCUIApplication()
        let trip = "Memo trip \(UUID().uuidString.prefix(6))"
        let place = "Memo Cafe"
        let firstMemo = "First line"
        app.launch()

        createTrip(trip, in: app)
        app.buttons["지도에서 장소 추가"].tap()
        addPin(named: place, in: app)
        let pin = app.buttons["map-pin-\(place)"]
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        pin.tap()
        app.buttons["상세 보기"].tap()
        XCTAssertTrue(app.navigationBars["방문 일정 상세"].waitForExistence(timeout: 5))
        attachScreen("Visit detail", in: app)
        app.buttons["일정 수정"].tap()
        let memo = app.textFields["visit-memo"]
        if !memo.isHittable { app.swipeUp() }
        XCTAssertTrue(memo.waitForExistence(timeout: 5))
        memo.tap()
        memo.typeText(firstMemo)
        app.buttons["저장"].tap()
        XCTAssertTrue(app.staticTexts[firstMemo].waitForExistence(timeout: 5))

        app.buttons["일정 수정"].tap()
        if !memo.isHittable { app.swipeUp() }
        memo.tap()
        memo.typeText(" discarded")
        app.buttons["취소"].tap()
        XCTAssertTrue(app.staticTexts[firstMemo].waitForExistence(timeout: 5))

        app.buttons["일정 수정"].tap()
        if !memo.isHittable { app.swipeUp() }
        memo.tap()
        memo.typeText(" edited")
        let editedMemo = try XCTUnwrap(memo.value as? String)
        XCTAssertTrue(editedMemo.contains("edited"))
        XCTAssertNotEqual(editedMemo, firstMemo)
        app.buttons["저장"].tap()
        XCTAssertTrue(app.staticTexts[editedMemo].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        showTripList(in: app)
        let tripRow = tripRow(named: trip, in: app)
        XCTAssertTrue(tripRow.waitForExistence(timeout: 5))
        tripRow.tap()
        app.buttons["visit-row-\(place)"].tap()
        XCTAssertTrue(app.navigationBars["방문 일정 상세"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[editedMemo].waitForExistence(timeout: 5))
        attachScreen("Visit detail with memo", in: app)
        if !app.buttons["일정 삭제"].isHittable { app.swipeUp() }
        app.buttons["일정 삭제"].tap()
        app.alerts.buttons["삭제"].tap()
        XCTAssertTrue(app.navigationBars[trip].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["visit-row-\(place)"].exists)
        app.buttons["지도"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["trip-map"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(pin.exists)
    }

    private func tapSwitch(_ identifier: String, in app: XCUIApplication) {
        let toggle = app.switches[identifier]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }

    private func editVisit(_ name: String, in app: XCUIApplication) {
        if !app.navigationBars["방문 일정 상세"].exists {
            let row = app.buttons["visit-row-\(name)"]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.tap()
        }
        let edit = app.buttons["일정 수정"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
    }

    private func addPin(named name: String, in app: XCUIApplication, configure: () -> Void = {}) {
        let map = app.descendants(matching: .any).matching(identifier: "trip-map").firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["draft-location-address"].exists)
        let add = app.buttons["일정 추가"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: add)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 15), .completed)
        add.tap()
        let field = app.textFields["place-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        configure()
        app.buttons["저장"].tap()
    }

    private func createTrip(_ name: String, in app: XCUIApplication) {
        openTripEditor(in: app)
        fillTrip(name: name, region: "Seoul", in: app)
        app.buttons["save-trip"].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
    }

    private func showTripList(in app: XCUIApplication) {
        app.buttons["내 여행"].tap()
        let list = app.navigationBars["나의 여행"]
        for _ in 0..<3 where !list.exists {
            let back = app.navigationBars.firstMatch.buttons.firstMatch
            XCTAssertTrue(back.exists)
            back.tap()
        }
        XCTAssertTrue(list.waitForExistence(timeout: 5))
    }

    private func openTripEditor(in app: XCUIApplication) {
        showTripList(in: app)
        app.buttons["새 여행"].tap()
        XCTAssertTrue(app.textFields["trip-name"].waitForExistence(timeout: 5))
    }

    private func openTrip(_ name: String, in app: XCUIApplication) {
        showTripList(in: app)
        let row = tripRow(named: name, in: app)
        XCTAssertTrue(row.exists)
        row.tap()
    }

    private func selectTrip(_ name: String, in app: XCUIApplication) {
        let row = app.buttons["\(name), 선택 안 됨"]
        for _ in 0..<12 where !row.exists {
            app.swipeUp()
        }
        XCTAssertTrue(row.exists)
        row.tap()
    }

    private func tripRow(named name: String, in app: XCUIApplication) -> XCUIElement {
        let row = app.staticTexts[name]
        for _ in 0..<12 where !row.exists {
            app.swipeUp()
        }
        return row
    }

    private func fillTrip(name: String, region: String, in app: XCUIApplication) {
        let nameField = app.textFields["trip-name"]
        nameField.tap()
        nameField.typeText(name)
        let regionField = app.textFields["trip-region"]
        regionField.tap()
        regionField.typeText(region)
    }

    func testTripPeriodAndRegionFlow() {
        let app = XCUIApplication()
        let trip = "Period \(UUID().uuidString.prefix(6))"
        let edited = trip + " Edited"
        app.launch()

        openTripEditor(in: app)
        attachScreen("Trip creation", in: app)
        fillTrip(name: trip, region: "Seoul", in: app)
        app.buttons["save-trip"].tap()
        XCTAssertTrue(app.navigationBars[trip].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Seoul", "당일 여행")).firstMatch.exists)
        attachScreen("Trip detail", in: app)

        app.buttons["여행 관리"].tap()
        let editTrip = app.buttons["여행 수정"]
        XCTAssertTrue(editTrip.waitForExistence(timeout: 5))
        editTrip.tap()
        let nameField = app.textFields["trip-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        attachScreen("Trip editing", in: app)
        nameField.tap()
        nameField.typeText(" Edited")
        let regionField = app.textFields["trip-region"]
        regionField.tap()
        regionField.typeText(" City")
        app.buttons["save-trip"].tap()
        XCTAssertTrue(app.navigationBars[edited].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        showTripList(in: app)
        let row = tripRow(named: edited, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Seoul City")).firstMatch.exists)
        attachScreen("Trip list", in: app)
        deleteTrip(edited, in: app)
    }

    private func attachScreen(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func deleteTrip(_ name: String, in app: XCUIApplication) {
        let row = tripRow(named: name, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 0.9)
        app.buttons["여행 삭제"].tap()
        app.alerts.buttons["삭제"].tap()
        XCTAssertFalse(row.exists)
    }
}

// The app's Foundation-only model is also compiled into this test target.
final class ReminderModelTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_900_000_000)

    func testAllOffsetsAndVisitDateChanges() {
        var visit = Visit(placeName: "카페", visitDate: date, coordinate: PlaceCoordinate(latitude: 33.5, longitude: 126.5))
        for preset in ReminderPreset.allCases where preset != .custom {
            visit.selectedReminderPreset = preset
            XCTAssertEqual(visit.reminderDate, visit.visitDate.addingTimeInterval(-preset.secondsBeforeVisit))
            visit.visitDate = visit.visitDate.addingTimeInterval(3_600)
            XCTAssertEqual(visit.reminderDate, visit.visitDate.addingTimeInterval(-preset.secondsBeforeVisit))
        }
        visit.selectedReminderPreset = .custom
        let custom = visit.reminderDate
        visit.visitDate = visit.visitDate.addingTimeInterval(86_400)
        XCTAssertEqual(visit.reminderDate, custom)
    }

    func testCrossMidnight() throws {
        let formatter = ISO8601DateFormatter()
        let date = try XCTUnwrap(formatter.date(from: "2030-01-02T00:20:00+09:00"))
        var visit = Visit(placeName: "카페", visitDate: date, coordinate: PlaceCoordinate(latitude: 33.5, longitude: 126.5))
        visit.selectedReminderPreset = .oneHourBefore
        XCTAssertEqual(visit.reminderDate, formatter.date(from: "2030-01-01T23:20:00+09:00"))
    }

    func testLegacyAndNewDefaultsRestore() throws {
        let suite = "TripJJIM.reminder-tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var visit = Visit(placeName: "카페", visitDate: date, coordinate: PlaceCoordinate(latitude: 33.5, longitude: 126.5))
        visit.reminderEnabled = true
        // Encoding nil omits the preset key, matching the previous app version.
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(visit), as: UTF8.self).contains("reminderPreset"))
        var restored = try JSONDecoder().decode(Visit.self, from: JSONEncoder().encode(visit))
        XCTAssertEqual(restored.selectedReminderPreset, .atVisit)
        visit.customReminderDate = date.addingTimeInterval(-123)
        restored = try JSONDecoder().decode(Visit.self, from: JSONEncoder().encode(visit))
        XCTAssertEqual(restored.selectedReminderPreset, .custom)
        XCTAssertEqual(restored.reminderDate, visit.customReminderDate)

        for preset in ReminderPreset.allCases {
            visit.selectedReminderPreset = preset
            defaults.set(try JSONEncoder().encode([Trip(name: "제주", visits: [visit])]), forKey: "tripjjim.trips")
            let freshDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            let data = try XCTUnwrap(freshDefaults.data(forKey: "tripjjim.trips"))
            let trips = try JSONDecoder().decode([Trip].self, from: data)
            XCTAssertEqual(trips[0].visits[0], visit)
            XCTAssertEqual(trips[0].visits[0].reminderDate, visit.reminderDate)
        }
    }

    func testPastReminderValidationAndBody() {
        var visit = Visit(placeName: "카페", visitDate: date, coordinate: PlaceCoordinate(latitude: 33.5, longitude: 126.5))
        let original = visit
        visit.reminderEnabled = true
        visit.selectedReminderPreset = .tenMinutesBefore
        XCTAssertTrue(visit.hasPastReminderChange(from: original, now: date.addingTimeInterval(-300)))
        XCTAssertFalse(visit.hasPastReminderChange(from: original, now: date.addingTimeInterval(-900)))
        let saved = visit
        visit.placeName = "새 카페"
        XCTAssertFalse(visit.hasPastReminderChange(from: saved, now: date.addingTimeInterval(60)))
        XCTAssertEqual(visit.reminderBody, "새 카페 방문 10분 전입니다.")
        visit.selectedReminderPreset = .custom
        XCTAssertEqual(visit.reminderBody, "새 카페 방문 알림입니다.")
    }
}
