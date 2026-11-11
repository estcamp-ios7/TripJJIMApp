import MapKit
import SwiftUI

struct VisitDetailView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tripID: Trip.ID
    let visitID: Visit.ID
    let onSaved: (Date) -> Void
    @State private var editing: Visit?
    @State private var isDeleting = false
    @State private var deleteFailed = false

    var body: some View {
        Group {
            if let trip = store.trip(withID: tripID),
               let visit = trip.visits.first(where: { $0.id == visitID }) {
                detail(for: visit, region: trip.region, tripRegionLocation: trip.regionLocation)
            } else {
                ContentUnavailableView("방문 일정을 찾을 수 없어요", systemImage: "calendar")
            }
        }
        .navigationTitle("방문 일정 상세")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(for visit: Visit, region: String?, tripRegionLocation: TripRegionLocation?) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(visit.placeName).font(.title2.bold())
                    if let address = visit.address, !address.isEmpty {
                        Text(address).font(.subheadline).readableSecondaryForeground()
                    }
                }
                .padding(.vertical, 4)
                map(for: visit)
            }
            Section("방문 일시와 알림") {
                Label("\(visit.visitDate.dayLabel) · \(visit.visitDate.timeLabel)", systemImage: "calendar")
                    .readableSecondaryForeground()
                Label(reminderLabel(for: visit), systemImage: visit.reminderEnabled ? "bell" : "bell.slash")
                    .accessibilityIdentifier("visit-detail-reminder")
            }
            Section("방문 메모") {
                if let memo = visit.memo, !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(memo).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("visit-detail-memo")
                } else {
                    Text("작성한 메모가 없어요.").readableSecondaryForeground()
                }
            }
            Section {
                Button("일정 수정", systemImage: "pencil") { editing = visit }
                Button("일정 삭제", systemImage: "trash", role: .destructive) { isDeleting = true }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editing) { draft in
            VisitEditorView(visit: draft, isNew: false, region: region, tripRegionLocation: tripRegionLocation) { updated in
                guard store.saveVisit(updated, in: tripID) else { return false }
                onSaved(updated.visitDate)
                return true
            }
        }
        .alert("방문 일정을 삭제할까요?", isPresented: $isDeleting) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                if store.deleteVisit(visitID, in: tripID) {
                    dismiss()
                } else {
                    deleteFailed = true
                }
            }
        } message: {
            Text("‘\(visit.placeName)’ 일정의 알림도 함께 삭제됩니다.")
        }
        .alert("일정을 삭제할 수 없어요", isPresented: $deleteFailed) {
            Button("확인", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func map(for visit: Visit) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
        if CLLocationCoordinate2DIsValid(coordinate) {
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1_200, longitudinalMeters: 1_200)
            Map(position: .constant(.region(region)), interactionModes: []) {
                Marker(visit.placeName, coordinate: coordinate).tint(.teal)
            }
            .mapControls {}
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("visit-detail-map")
        } else {
            Label("지도에 표시할 위치 정보가 없어요.", systemImage: "map")
                .font(.subheadline).readableSecondaryForeground()
        }
    }

    private func reminderLabel(for visit: Visit) -> String {
        guard visit.reminderEnabled else { return "알림 꺼짐" }
        let date = visit.reminderDate
        return "\(date.dayLabel) \(date.timeLabel)"
    }
}

#Preview("방문 일정 상세") {
    let visit = Visit(
        placeName: "제주 동문시장",
        visitDate: .now,
        coordinate: PlaceCoordinate(latitude: 33.5125, longitude: 126.5261),
        address: "제주특별자치도 제주시 관덕로14길 20",
        memo: "점심 먹기\n시장 구경하기"
    )
    let trip = Trip(name: "제주 여행", visits: [visit], region: "제주")

    let defaults = UserDefaults(suiteName: "TripJJIM.VisitDetailPreview")!
    let store = {
        if let data = try? JSONEncoder().encode([trip]) {
            defaults.set(data, forKey: "tripjjim.trips")
        }
        return TripStore(defaults: defaults)
    }()

    NavigationStack {
        VisitDetailView(tripID: trip.id, visitID: visit.id) { _ in }
    }
    .environment(store)
}
