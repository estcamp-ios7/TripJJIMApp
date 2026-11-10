import MapKit
import SwiftUI

struct TripMapView: View {
    let trip: Trip
    @Binding var selectedDay: Date
    let onAdd: (PlaceCoordinate) -> Void
    let onEdit: (Visit) -> Void

    @State private var position: MapCameraPosition = .region(Self.region(around: .seoul))
    @State private var draftCoordinate: PlaceCoordinate?
    @State private var selectedVisitID: Visit.ID?
    @State private var location = LocationManager()

    private var visits: [Visit] {
        trip.days.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }?.visits ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                DatePicker("지도 날짜", selection: $selectedDay, displayedComponents: .date)
                    .labelsHidden()
                    .accessibilityLabel("지도 날짜")
                Spacer()
                Button(action: location.requestCurrentLocation) {
                    Label("내 위치", systemImage: "location.fill")
                }
                .buttonStyle(.bordered)
                .disabled(location.isLocating)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            MapReader { proxy in
                Map(position: $position, interactionModes: [.pan, .zoom]) {
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
                .onTapGesture(coordinateSpace: .local) { point in
                    mapTapped(at: point, using: proxy)
                }
                .accessibilityIdentifier("trip-map")
            }

            mapFooter
        }
        .onAppear { focusOnSavedPlaces() }
        .onChange(of: selectedDay) {
            draftCoordinate = nil
            selectedVisitID = nil
            focusOnSavedPlaces()
        }
        .onChange(of: trip.visits) { draftCoordinate = nil }
        .onChange(of: location.currentCoordinate) { _, coordinate in
            if let coordinate { moveMap(to: coordinate) }
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
                HStack {
                    Label("선택한 위치", systemImage: "mappin")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("취소") { self.draftCoordinate = nil }
                    Button("일정 추가") { onAdd(draftCoordinate) }
                        .buttonStyle(.borderedProminent)
                }
            } else if let visit = visits.first(where: { $0.id == selectedVisitID }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(visit.placeName).font(.headline)
                        Text(visit.visitDate.timeLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("일정 수정") { onEdit(visit) }
                        .buttonStyle(.bordered)
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
        selectedVisitID = nil
        draftCoordinate = PlaceCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private func select(_ visit: Visit) {
        draftCoordinate = nil
        selectedVisitID = visit.id
    }

    private func focusOnSavedPlaces() {
        guard let first = visits.first else { return }
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
