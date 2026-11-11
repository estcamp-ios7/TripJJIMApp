import MapKit
import OSLog
import SwiftUI

struct TripMapView: View {
    let trip: Trip
    @Binding var selectedDay: Date
    let onAdd: (PlaceCoordinate, String?, String?) -> Void
    let onEdit: (Visit) -> Void
    let onDetail: (Visit) -> Void
    let onSearch: (PlaceCoordinate?) -> Void
    private let selectionLog = Logger(subsystem: "com.tripjjim.TripJJIM", category: "MapSelection")

    @State private var position: MapCameraPosition = .region(Self.region(around: .seoul))
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
                DatePicker("지도 날짜", selection: $selectedDay, displayedComponents: .date)
                    .labelsHidden()
                    .accessibilityLabel("지도 날짜")
                Spacer()
                Button(action: { onSearch(nil) }) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("장소 검색")
                Button {
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
        .onAppear { focusOnSavedPlaces() }
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
        .onChange(of: cameraContext) { focusOnSavedPlaces() }
        .onDisappear {
            pendingTap?.cancel()
            cancelRegionFocus()
        }
        .onChange(of: location.currentCoordinate) { _, coordinate in
            if let coordinate, locationFocusID == focusID { moveMap(to: coordinate) }
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
                            .foregroundStyle(.secondary)
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
                            Text(address).font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(visit.visitDate.timeLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
        pendingTap = Task {
            // Give the native map selection first chance to claim this tap.
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, nativeSelectionID == selectionID else { return }
            if let featureSelectedAt, featureSelectedAt.duration(to: tappedAt) < .milliseconds(180),
               let feature = mapSelection?.feature,
               let marker = proxy.convert(feature.coordinate, to: .local),
               hypot(point.x - marker.x, point.y - marker.y) < 44 {
                return
            }
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
                guard administrativeSearch === service, focusID == requestID else { return }
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
            guard regionSearch === search, focusID == requestID else { return }
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
                .background(isSelected ? Color.indigo : .teal, in: Capsule())
                .overlay { Capsule().strokeBorder(.white, lineWidth: 2) }
                .zIndex(1)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.indigo : .teal)
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
