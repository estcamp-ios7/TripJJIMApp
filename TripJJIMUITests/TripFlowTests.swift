import CoreLocation
import XCTest

final class TripFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
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
        app.navigationBars["장소 검색"].buttons.firstMatch.tap()
        app.buttons["취소"].tap()
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        app.buttons["일정"].tap()
        XCTAssertTrue(app.staticTexts["다음 목적지"].exists)
        XCTAssertTrue(app.buttons["visit-row-\(place)"].exists)

        app.terminate()
        app.launch()
        let tripRow = app.staticTexts[trip]
        XCTAssertTrue(tripRow.waitForExistence(timeout: 5))
        tripRow.tap()
        XCTAssertTrue(app.buttons["visit-row-\(place)"].exists)
        app.buttons["지도"].tap()
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        pin.tap()
        XCTAssertTrue(app.buttons["일정 수정"].exists)

        app.navigationBars[trip].buttons.firstMatch.tap()
        let renamedTrip = trip + " Edited"
        tripRow.press(forDuration: 0.9)
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
        app.staticTexts[trip].tap()
        app.buttons["지도"].tap()
        app.buttons["내 위치"].tap()
        let allow = springboard.alerts.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS[c] %@", "사용하는 동안", "while using")
        ).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        allow.tap()
        let marker = app.descendants(matching: .any).matching(identifier: "current-location").firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 15))

        app.navigationBars[trip].buttons.firstMatch.tap()
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
            app.swipeUp()
            tapSwitch("visit-reminder", in: app)
            let allow = springboard.alerts.buttons.matching(
                NSPredicate(format: "label IN %@", ["허용", "Allow"])
            ).firstMatch
            if allow.waitForExistence(timeout: 3) { allow.tap() }
            XCTAssertEqual(app.switches["visit-reminder"].value as? String, "1")
        }
        app.buttons["일정"].tap()

        editVisit(place, in: app)
        let field = app.textFields["place-name"]
        field.tap()
        field.typeText(" Updated")
        app.swipeUp()
        tapSwitch("remind-at-visit-time", in: app)
        let datePicker = app.datePickers["reminder-date"]
        XCTAssertTrue(datePicker.waitForExistence(timeout: 5))
        datePicker.tap()
        let newDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 2, to: .now))
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

        editVisit(editedPlace, in: app)
        app.swipeUp()
        tapSwitch("visit-reminder", in: app)
        app.buttons["저장"].tap()

        let row = app.buttons["visit-row-\(editedPlace)"]
        row.press(forDuration: 0.9)
        app.buttons["일정 삭제"].tap()
        app.alerts.buttons["삭제"].tap()
        XCTAssertFalse(row.exists)

        app.buttons["지도에서 장소 추가"].tap()
        addPin(named: editedPlace, in: app) {
            app.swipeUp()
            tapSwitch("visit-reminder", in: app)
        }
        app.navigationBars[trip].buttons.firstMatch.tap()
        deleteTrip(trip, in: app)
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
        let tripRow = app.staticTexts[trip]
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
        let row = app.buttons["visit-row-\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
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

    private func openTripEditor(in app: XCUIApplication) {
        app.buttons["새 여행"].tap()
        XCTAssertTrue(app.textFields["trip-name"].waitForExistence(timeout: 5))
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
        app.buttons["여행 수정"].tap()
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
        let row = app.staticTexts[edited]
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
        let row = app.staticTexts[name]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 0.9)
        app.buttons["여행 삭제"].tap()
        app.alerts.buttons["삭제"].tap()
        XCTAssertFalse(row.exists)
    }
}
