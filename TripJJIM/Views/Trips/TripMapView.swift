import MapKit
import OSLog
import SwiftUI

struct TripMapTabView: View {
    @Environment(TripStore.self) private var store
    @Binding var path: [Trip.ID]

    var body: some View {
        NavigationStack(path: $path) {
            List(store.trips) { trip in
                NavigationLink(value: trip.id) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.name)
                                .font(.headline)
                            if let region = trip.region, !region.isEmpty {
                                Text(region)
                                    .font(.subheadline)
                                    .readableSecondaryForeground()
                            }
                        }
                    } icon: {
                        Image(systemName: "map.fill")
                            .foregroundStyle(Color.tripAccent)
                    }
                }
            }
            .overlay {
                if store.trips.isEmpty {
                    ContentUnavailableView(
                        "지도로 볼 여행이 없어요",
                        systemImage: "map",
                        description: Text("홈에서 여행을 먼저 만들어 주세요.")
                    )
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                TripMapSubtitle()
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
            }
            .navigationTitle("지도")
            .navigationDestination(for: Trip.ID.self) { tripID in
                TripMapTripView(tripID: tripID)
            }
        }
    }
}

private struct TripMapSubtitle: View {
    var body: some View {
        Text("어디를 둘러볼까요?")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TripMapTripView: View {
    @Environment(TripStore.self) private var store
    let tripID: Trip.ID

    @State private var mapDay: Date?
    @State private var editor: Editor?
    @State private var searchingPlace = false
    @State private var nearbySearchCoordinate: PlaceCoordinate?
    @State private var pendingPlace: PlaceSearchResult?
    @State private var detailVisitID: Visit.ID?

    private struct Editor: Identifiable {
        var id: Visit.ID { visit.id }
        let visit: Visit
        let isNew: Bool
    }

    var body: some View {
        if let trip = store.trip(withID: tripID) {
            VStack(spacing: 0) {
                let days = travelDays(for: trip)
                TravelDayTabBar(days: days, selectedDay: selectedDayBinding(for: trip))

                TripMapView(
                    trip: trip,
                    selectedDay: selectedDayBinding(for: trip),
                    isShowingVisitDetail: detailVisitID != nil,
                    onAdd: { coordinate, name, address in
                        startAddingVisit(at: coordinate, name: name ?? "", address: address)
                    },
                    onEdit: editVisit(_:),
                    onDetail: showVisit(_:),
                    onSearch: openPlaceSearch(near:)
                )
            }
            .navigationTitle(trip.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $detailVisitID) { visitID in
                VisitDetailView(tripID: tripID, visitID: visitID) {
                    detailVisitID = nil
                }
            }
            .sheet(isPresented: $searchingPlace, onDismiss: openSelectedPlace) {
                NavigationStack {
                    PlaceSearchView(
                        region: trip.region,
                        nearby: nearbySearchCoordinate,
                        tripRegionLocation: trip.regionLocation
                    ) { pendingPlace = $0 }
                }
            }
            .sheet(item: $editor) { editor in
                VisitEditorView(
                    visit: editor.visit,
                    isNew: editor.isNew,
                    region: trip.region,
                    tripRegionLocation: trip.regionLocation
                ) { edited in
                    guard store.saveVisit(edited, in: tripID) else { return false }
                    mapDay = Calendar.current.startOfDay(for: edited.visitDate)
                    return true
                }
            }
        } else {
            ContentUnavailableView("여행을 찾을 수 없어요", systemImage: "map")
        }
    }

    private func showVisit(_ visit: Visit) {
        mapDay = Calendar.current.startOfDay(for: visit.visitDate)
        detailVisitID = visit.id
    }

    private func editVisit(_ visit: Visit) {
        editor = Editor(visit: visit, isNew: false)
    }

    private func selectedDayBinding(for trip: Trip) -> Binding<Date> {
        Binding(
            get: { selectedDay(for: trip) },
            set: { mapDay = Calendar.current.startOfDay(for: $0) }
        )
    }

    private func selectedDay(for trip: Trip) -> Date {
        let days = travelDays(for: trip)
        guard let mapDay else { return defaultMapDay(for: trip) }
        return days.contains(where: { Calendar.current.isDate($0, inSameDayAs: mapDay) })
            ? Calendar.current.startOfDay(for: mapDay)
            : defaultMapDay(for: trip)
    }

    private func defaultMapDay(for trip: Trip) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = travelDays(for: trip)

        if let currentDay = days.first(where: { calendar.isDate($0, inSameDayAs: today) }) {
            return currentDay
        }
        if let nextVisit = trip.nextVisit(after: .now) {
            return calendar.startOfDay(for: nextVisit.visitDate)
        }
        return days.first(where: { $0 >= today }) ?? days.last ?? today
    }

    private func travelDays(for trip: Trip) -> [Date] {
        let calendar = Calendar.current
        guard let startDate = trip.startDate, let endDate = trip.endDate else {
            return trip.days.map(\.date)
        }

        let first = calendar.startOfDay(for: startDate)
        let last = calendar.startOfDay(for: endDate)
        guard first <= last else { return [first] }

        var days: [Date] = []
        var day = first
        while day <= last {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    private func openPlaceSearch(near coordinate: PlaceCoordinate?) {
        nearbySearchCoordinate = coordinate
        searchingPlace = true
    }

    private func openSelectedPlace() {
        guard let place = pendingPlace else { return }
        pendingPlace = nil
        startAddingVisit(at: place.coordinate, name: place.name, address: place.address)
    }

    private func startAddingVisit(at coordinate: PlaceCoordinate, name: String = "", address: String? = nil) {
        guard let trip = store.trip(withID: tripID) else { return }
        let day = selectedDay(for: trip)
        let calendar = Calendar.current
        let date = calendar.isDateInToday(day)
            ? calendar.nextDate(after: .now, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime)
            : calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
        let fallback = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        let visitDate = date.flatMap { calendar.isDate($0, inSameDayAs: day) ? $0 : nil } ?? fallback
        let visit = Visit(placeName: name, visitDate: visitDate, coordinate: coordinate, address: address)
        editor = Editor(visit: visit, isNew: true)
    }
}

struct TripMapView: View {
    let trip: Trip
    @Binding var selectedDay: Date
    let isShowingVisitDetail: Bool
    let onAdd: (PlaceCoordinate, String?, String?) -> Void
    let onEdit: (Visit) -> Void
    let onDetail: (Visit) -> Void
    let onSearch: (PlaceCoordinate?) -> Void
    private let selectionLog = Logger(subsystem: "com.tripjjim.TripJJIM", category: "MapSelection")

    @State private var position: MapCameraPosition = .region(Self.region(around: .seoul))
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleCamera: MapCamera?
    @State private var didSetInitialCamera = false
    private static let selectionDistance: Double = 1_500

    @State private var draftCoordinate: PlaceCoordinate?
    @State private var draftAddress: String?
    @State private var draftName: String?
    @State private var mapSelection: MapSelection<Visit.ID>?
    @State private var draftFeature: MapFeature?
    @State private var draftID = UUID()
    @State private var pendingTap: Task<Void, Never>?
    @State private var nativeSelectionID = UUID()
    @State private var featureSelectedAt: ContinuousClock.Instant?
    @State private var lookingUpAddress = false
    @State private var selectedVisitID: Visit.ID?
    @State private var location = LocationManager()
    @State private var regionSearch: MKLocalSearch?
    @State private var administrativeSearch: AdministrativeRegionSearch?
    @State private var cachedRegion: String?
    @State private var cachedCenter: PlaceCoordinate?
    @State private var focusID = UUID()
    @State private var locationFocusID: UUID?

    private var visits: [Visit] {
        trip.days.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }?.visits ?? []
    }

    private struct CameraContext: Equatable {
        let day: Date
        let region: String?
        let regionLocation: TripRegionLocation?
        let coordinates: [PlaceCoordinate]
    }

    private var cameraContext: CameraContext {
        CameraContext(day: selectedDay, region: trip.region, regionLocation: trip.regionLocation, coordinates: visits.map(\.coordinate))
    }

    private var selectionBinding: Binding<MapSelection<Visit.ID>?> {
        Binding(
            get: { mapSelection },
            set: { selection in
                mapSelection = selection
                guard let selection else {
                    selectionLog.info("Native selection cleared")
                    return
                }
                if let feature = selection.feature, feature.kind == .pointOfInterest {
                    selectionLog.info("Native POI selection; has title=\(feature.title?.isEmpty == false)")
                    nativeSelectionID = UUID()
                    featureSelectedAt = .now
                    pendingTap?.cancel()
                    beginDraft(at: feature.coordinate, feature: feature)
                } else if let id = selection.value, let visit = visits.first(where: { $0.id == id }) {
                    nativeSelectionID = UUID()
                    select(visit)
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { onSearch(nil) }) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("장소 검색")
                Button {
                    pendingTap?.cancel()
                    cancelRegionFocus()
                    locationFocusID = focusID
                    location.requestCurrentLocation()
                } label: {
                    Label("내 위치", systemImage: "location.fill")
                }
                .buttonStyle(.bordered)
                .disabled(location.isLocating)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            MapReader { proxy in
                Map(position: $position, interactionModes: [.pan, .zoom], selection: selectionBinding) {
                    ForEach(Array(visits.enumerated()), id: \.element.id) { index, visit in
                        Annotation(visit.placeName, coordinate: visit.coordinate.mapCoordinate, anchor: .bottom) {
                            Button {
                                select(visit)
                            } label: {
                                NumberedPin(number: index + 1, isSelected: selectedVisitID == visit.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(index + 1)번 \(visit.placeName)")
                            .accessibilityIdentifier("map-pin-\(visit.placeName)")
                        }
                        .tag(MapSelection(visit.id))
                        .annotationTitles(.hidden)
                    }
                    if let current = location.currentCoordinate {
                        Annotation("내 위치", coordinate: current.mapCoordinate) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 17, height: 17)
                                .overlay { Circle().strokeBorder(.white, lineWidth: 3) }
                                .shadow(radius: 2)
                                .accessibilityElement()
                                .accessibilityLabel("현재 위치")
                                .accessibilityIdentifier("current-location")
                        }
                        .annotationTitles(.hidden)
                    }
                    if let draftCoordinate {
                        Annotation("선택한 위치", coordinate: draftCoordinate.mapCoordinate, anchor: .bottom) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 40))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .orange)
                                .shadow(radius: 3)
                                .accessibilityIdentifier("draft-pin")
                        }
                        .annotationTitles(.hidden)
                    }
                }
                .onMapCameraChange { context in
                    visibleCamera = context.camera
                }
                .mapControls {}
                .mapFeatureSelectionAccessory(nil)
                .mapFeatureSelectionDisabled { $0.kind != .pointOfInterest }
                .simultaneousGesture(SpatialTapGesture().onEnded { tap in
                    queueMapTap(at: tap.location, using: proxy)
                })
                .accessibilityIdentifier("trip-map")
            }

            mapFooter
        }
        .onAppear {
            guard !didSetInitialCamera else { return }
            didSetInitialCamera = true
            focusOnSavedPlaces()
        }
        .onChange(of: position.positionedByUser) { _, positionedByUser in
            guard positionedByUser else { return }
            pendingTap?.cancel()
            cancelRegionFocus()
        }
        .task(id: draftID) {
            guard let draftCoordinate else { return }
            await resolveDraft(at: draftCoordinate, feature: draftFeature, id: draftID)
        }
        .onChange(of: selectedDay) {
            clearDraft()
            selectedVisitID = nil
        }
        .onChange(of: trip.visits) {
            clearDraft()
            if let selectedVisitID, !visits.contains(where: { $0.id == selectedVisitID }) {
                self.selectedVisitID = nil
            }
        }
        .onChange(of: cameraContext) { previous, current in
            if previous.day != current.day {
                focusOnSavedPlaces()
            } else if !isShowingVisitDetail && !position.positionedByUser && locationFocusID != focusID {
                focusOnSavedPlaces()
            }
        }
        .onDisappear {
            pendingTap?.cancel()
            cancelRegionFocus()
        }
        .onChange(of: location.currentCoordinate) { _, coordinate in
            guard let coordinate, locationFocusID == focusID else { return }
            locationFocusID = nil
            moveMap(to: coordinate)
        }
        .alert("내 위치", isPresented: Binding(
            get: { location.message != nil },
            set: { if !$0 { location.message = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(location.message ?? "")
        }
    }

    @ViewBuilder
    private var mapFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let draftCoordinate {
                VStack(alignment: .leading, spacing: 8) {
                    Label(draftName ?? (lookingUpAddress ? "장소 정보를 확인 중이에요" : draftAddress ?? "선택한 위치"), systemImage: "mappin")
                        .accessibilityIdentifier("draft-location-address")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                    if draftName != nil, let draftAddress {
                        Text(draftAddress)
                            .font(.footnote)
                            .readableSecondaryForeground()
                            .lineLimit(2)
                    }
                    if draftName == nil {
                        Button("이 위치 주변 장소 검색") { onSearch(draftCoordinate) }
                            .font(.subheadline)
                    }
                    HStack {
                        Spacer()
                        Button("취소") { clearDraft() }
                        Button("일정 추가") { onAdd(draftCoordinate, draftName, draftAddress) }
                            .disabled(lookingUpAddress)
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else if let visit = visits.first(where: { $0.id == selectedVisitID }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(visit.placeName).font(.headline)
                        if let address = visit.address {
                            Text(address).font(.footnote).readableSecondaryForeground()
                        }
                        Text(visit.visitDate.timeLabel)
                            .font(.subheadline)
                            .readableSecondaryForeground()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Button("상세 보기") { onDetail(visit) }
                            .buttonStyle(.borderedProminent)
                        Button("일정 수정") { onEdit(visit) }
                            .buttonStyle(.bordered)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .accessibilityIdentifier("map-place-detail")
            } else {
                Label("지도를 탭해 장소를 찜해 보세요.", systemImage: "hand.tap")
                    .font(.subheadline)
                    .readableSecondaryForeground()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func mapTapped(at point: CGPoint, using proxy: MapProxy) {
        // 핀 위를 누른 경우에는 기존 일정을 선택합니다.
        if let visit = visits.first(where: { visit in
            guard let pin = proxy.convert(visit.coordinate.mapCoordinate, to: .local) else { return false }
            return abs(point.x - pin.x) <= 22 && (pin.y - 44...pin.y + 8).contains(point.y)
        }) {
            select(visit)
            return
        }

        guard let coordinate = proxy.convert(point, from: .local) else { return }
        selectionLog.info("Coordinate tap accepted")
        mapSelection = nil
        beginDraft(at: coordinate, feature: nil)
    }

    private func queueMapTap(at point: CGPoint, using proxy: MapProxy) {
        pendingTap?.cancel()
        let selectionID = nativeSelectionID
        let tappedAt = ContinuousClock.now
        if let featureSelectedAt, featureSelectedAt.duration(to: tappedAt) < .milliseconds(180),
           let feature = mapSelection?.feature,
           let marker = proxy.convert(feature.coordinate, to: .local),
           hypot(point.x - marker.x, point.y - marker.y) < 44 {
            return
        }
        pendingTap = Task {
            // Give the native map selection first chance to claim this tap.
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, nativeSelectionID == selectionID else { return }
            mapTapped(at: point, using: proxy)
        }
    }

    private func beginDraft(at coordinate: CLLocationCoordinate2D, feature: MapFeature?) {
        cancelRegionFocus()
        selectedVisitID = nil
        draftCoordinate = PlaceCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        draftFeature = feature
        draftName = cleanName(feature?.title)
        draftAddress = nil
        lookingUpAddress = true
        draftID = UUID()
        focusOnDraft(at: coordinate)
    }

    private func focusOnDraft(at coordinate: CLLocationCoordinate2D) {
        let current = position.camera ?? visibleCamera
        let camera = MapCamera(
            centerCoordinate: coordinate,
            distance: min(current?.distance ?? Self.selectionDistance, Self.selectionDistance),
            heading: current?.heading ?? 0,
            pitch: current?.pitch ?? 0
        )
        // The footer is outside the map, so its center stays above the place information.
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            position = .camera(camera)
        }
    }

    private func clearDraft() {
        pendingTap?.cancel()
        draftCoordinate = nil
        draftFeature = nil
        mapSelection = nil
        featureSelectedAt = nil
        draftID = UUID()
        draftName = nil
        draftAddress = nil
        lookingUpAddress = false
    }

    private func resolveDraft(at coordinate: PlaceCoordinate, feature: MapFeature?, id: UUID) async {
        var point = coordinate
        var name = cleanName(feature?.title)
        var address: String?
        if let feature {
            let request = MKMapItemRequest(feature: feature)
            if let item = try? await request.mapItem {
                let location = item.location.coordinate
                point = PlaceCoordinate(latitude: location.latitude, longitude: location.longitude)
                address = item.displayAddress
                if let itemName = cleanName(item.name), itemName != address {
                    name = itemName
                }
            }
        }
        guard !Task.isCancelled, draftID == id else { return }
        if address == nil, let request = MKReverseGeocodingRequest(
            location: CLLocation(latitude: point.latitude, longitude: point.longitude)
        ) {
            request.preferredLocale = Locale(identifier: "ko_KR")
            address = (try? await request.mapItems)?.compactMap(\.displayAddress).first
        }
        guard !Task.isCancelled, draftID == id else { return }
        selectionLog.info("Draft resolved; feature=\(feature != nil) name=\(name != nil) address=\(address != nil)")
        draftCoordinate = point
        draftName = name
        draftAddress = address
        lookingUpAddress = false
    }

    private func cleanName(_ value: String?) -> String? {
        guard let name = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }

    private func select(_ visit: Visit) {
        clearDraft()
        selectedVisitID = visit.id
    }

    private func focusOnSavedPlaces() {
        cancelRegionFocus()
        guard let first = visits.first else {
            focusOnTripRegion()
            return
        }
        if visits.count == 1 {
            moveMap(to: first.coordinate)
            return
        }

        let bounds = visits.reduce(MKMapRect.null) { bounds, visit in
            let point = MKMapPoint(visit.coordinate.mapCoordinate)
            return bounds.union(MKMapRect(origin: point, size: MKMapSize(width: 1, height: 1)))
        }
        let padding = max(bounds.width, bounds.height) * 0.2 + 4_000
        withAnimation { position = .rect(bounds.insetBy(dx: -padding, dy: -padding)) }
    }

    private func cancelRegionFocus() {
        regionSearch?.cancel()
        regionSearch = nil
        administrativeSearch?.cancel()
        administrativeSearch = nil
        focusID = UUID()
    }

    private func focusOnTripRegion() {
        if let location = trip.regionLocation {
            withAnimation { position = .region(location.mapRegion) }
            return
        }
        guard let region = trip.region?.trimmingCharacters(in: .whitespacesAndNewlines),
              !region.isEmpty else {
            moveMap(to: .seoul)
            return
        }
        let matches = AdministrativeRegion.matches(region)
        if let entry = matches.first {
            guard matches.count == 1 else { return }
            let service = AdministrativeRegionSearch()
            administrativeSearch = service
            let requestID = focusID
            Task {
                let location = try? await service.resolve(entry)
                guard administrativeSearch === service, focusID == requestID, !position.positionedByUser else { return }
                administrativeSearch = nil
                if let location {
                    withAnimation { position = .region(location.mapRegion) }
                }
            }
            return
        }

        if cachedRegion == region, let cachedCenter {
            showRegion(cachedCenter)
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = region
        request.resultTypes = .address
        let search = MKLocalSearch(request: request)
        let requestID = focusID
        regionSearch = search
        Task {
            let response = try? await search.start()
            guard regionSearch === search, focusID == requestID, !position.positionedByUser else { return }
            regionSearch = nil
            guard let point = response?.mapItems.first?.location.coordinate else {
                moveMap(to: .seoul)
                return
            }
            let center = PlaceCoordinate(latitude: point.latitude, longitude: point.longitude)
            cachedRegion = region
            cachedCenter = center
            showRegion(center)
        }
    }

    private func showRegion(_ center: PlaceCoordinate) {
        withAnimation {
            position = .region(MKCoordinateRegion(center: center.mapCoordinate,
                                                  latitudinalMeters: 24_000,
                                                  longitudinalMeters: 24_000))
        }
    }

    private func moveMap(to coordinate: PlaceCoordinate) {
        withAnimation { position = .region(Self.region(around: coordinate)) }
    }

    private static func region(around coordinate: PlaceCoordinate) -> MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate.mapCoordinate,
                           span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035))
    }
}

private struct NumberedPin: View {
    let number: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: -5) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .frame(minWidth: 34, minHeight: 34)
                .background(isSelected ? Color.indigo : Color.tripAccent, in: Capsule())
                .overlay { Capsule().strokeBorder(.white, lineWidth: 2) }
                .zIndex(1)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.indigo : Color.tripAccent)
        }
        .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
    }
}

private extension PlaceCoordinate {
    static let seoul = PlaceCoordinate(latitude: 37.5665, longitude: 126.9780)

    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
