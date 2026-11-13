import MapKit
import SwiftUI

struct RecommendedCourseDetailView: View {
    let course: RecommendedCourse
    let onImported: (Trip.ID) -> Void

    @State private var isImporting = false
    @State private var savedTripID: Trip.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 0) {
                    RecommendedCourseArtwork(course: course)
                    VStack(alignment: .leading, spacing: 10) {
                        RecommendedCourseHeading(course: course)
                        Text(course.summary)
                            .font(.subheadline)
                            .readableSecondaryForeground()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 18))

                ForEach(course.days.sorted { $0.number < $1.number }) { day in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(day.number)일 차")
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                        if let summary = day.summary {
                            Text(summary).font(.subheadline).readableSecondaryForeground()
                        }
                        ForEach(day.places.sorted { $0.order < $1.order }) { place in
                            placeRow(place)
                        }
                    }
                }

                let pins = course.days.flatMap { day in
                    day.places.compactMap { place in
                        place.coordinate.map { CoursePin(day: day.number, place: place, coordinate: $0) }
                    }
                }
                if !pins.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("코스 지도").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                        if pins.count < course.days.flatMap(\.places).count {
                            Text("위치가 확인된 장소만 지도에 표시해요.")
                                .font(.footnote).readableSecondaryForeground()
                        }
                        RecommendedCourseMap(pins: pins)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RecommendedCourseAction(title: "이 코스로 여행 만들기", icon: "suitcase.fill") {
                isImporting = true
            }
            .accessibilityIdentifier("start-course-import")
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("코스 상세")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isImporting, onDismiss: {
            guard let savedTripID else { return }
            self.savedTripID = nil
            onImported(savedTripID)
        }) {
            RecommendedCourseImportView(course: course) { tripID in
                savedTripID = tripID
                isImporting = false
            }
        }
    }

    private func placeRow(_ place: RecommendedPlace) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(place.order, format: .number)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .padding(8)
                .frame(minWidth: 34)
                .background(Color.tripAccent.opacity(0.16), in: Circle())
                .accessibilityLabel("방문 순서 \(place.order)")

            VStack(alignment: .leading, spacing: 5) {
                Text(place.name).font(.headline)
                Text("\(place.category.title) · \(place.area)")
                    .font(.footnote).readableSecondaryForeground()
                Text(place.reason).font(.subheadline)
                if let time = place.suggestedTime {
                    Label(time, systemImage: "clock")
                        .font(.footnote).readableSecondaryForeground()
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("course-place-\(place.id)")
    }
}

private struct CoursePin: Identifiable {
    let day: Int
    let place: RecommendedPlace
    let coordinate: PlaceCoordinate

    var id: String { place.id }
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    var title: String { "\(day)일 차 · \(place.order). \(place.name)" }
}

private struct RecommendedCourseMap: View {
    let pins: [CoursePin]
    @State private var position: MapCameraPosition

    init(pins: [CoursePin]) {
        self.pins = pins
        let bounds = pins.reduce(MKMapRect.null) { rect, pin in
            let point = MKMapPoint(pin.location)
            let padding = 280 * MKMapPointsPerMeterAtLatitude(pin.location.latitude)
            let area = MKMapRect(x: point.x - padding, y: point.y - padding,
                                 width: padding * 2, height: padding * 2)
            return rect.union(area)
        }
        _position = State(initialValue: .rect(bounds))
    }

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            ForEach(pins) { pin in
                Marker(pin.title, coordinate: pin.location)
                    .tint(Color.tripAccent)
            }
        }
        .frame(height: 240)
        .clipShape(.rect(cornerRadius: 16))
        .accessibilityIdentifier("recommended-course-map")
    }
}

struct RecommendedCourseAction: View {
    @Environment(\.isEnabled) private var isEnabled

    let title: String
    let icon: String
    var isWorking = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isWorking {
                    ProgressView().tint(.white).accessibilityHidden(true)
                    Text("여행을 만드는 중")
                } else {
                    Label(title, systemImage: icon)
                }
            }
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                Color.tripAccent
                    .opacity(isEnabled || isWorking ? 1 : 0.48),
                in: .rect(cornerRadius: 16)
            )
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 520)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
