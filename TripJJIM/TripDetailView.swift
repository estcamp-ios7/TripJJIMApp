import SwiftUI

struct TripDetailView: View {
    @Environment(TripStore.self) private var store
    let tripID: Trip.ID
    @Environment(\.dismiss) private var dismiss
    @State private var tripEditor: TripEditorRoute?
    @State private var isDeletingTrip = false
    @State private var editor: Editor?
    @State private var mode: Mode = .itinerary
    @State private var searchingPlace = false
    @State private var nearbySearchCoordinate: PlaceCoordinate?
    @State private var pendingPlace: PlaceSearchResult?
    @State private var mapDay: Date?

    private enum Mode: String, CaseIterable {
        case itinerary = "일정"
        case map = "지도"
    }

    private struct Editor: Identifiable {
        var id: Visit.ID { visit.id }
        let visit: Visit
        let isNew: Bool
    }
    @State private var visitToDelete: Visit?

    var body: some View {
        if let trip = store.trip(withID: tripID) {
            VStack(spacing: 0) {
                if let summary = trip.travelSummary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                Picker("여행 보기", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if mode == .itinerary {
                    itinerary(for: trip)
                } else {
                    TripMapView(trip: trip, selectedDay: Binding(
                        get: { mapDay ?? defaultMapDay(for: trip) },
                        set: { mapDay = Calendar.current.startOfDay(for: $0) }
                    ), onAdd: { coordinate, name, address in
                        startAddingVisit(at: coordinate, name: name ?? "", address: address)
                    }, onEdit: editVisit(_:), onSearch: openPlaceSearch(near:))
                }
            }
            .navigationTitle(trip.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("여행 수정", systemImage: "pencil") { tripEditor = .edit(trip) }
                        Button("여행 삭제", systemImage: "trash", role: .destructive) { isDeletingTrip = true }
                    } label: {
                        Label("여행 관리", systemImage: "ellipsis.circle")
                    }
                }
                if mode == .itinerary {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { openPlaceSearch(near: nil) } label: { Label("장소 검색", systemImage: "magnifyingglass") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            mode = .map
                        } label: {
                            Label("방문 일정 추가", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(item: $tripEditor) { route in
                TripEditorView(trip: route.trip) { _ in tripEditor = nil }
            }
            .alert("여행을 삭제할까요?", isPresented: $isDeletingTrip) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    if store.deleteTrip(tripID) { dismiss() }
                }
            } message: {
                Text("‘\(trip.name)’의 모든 방문 일정과 알림도 함께 삭제됩니다.")
            }
            .sheet(isPresented: $searchingPlace, onDismiss: openSelectedPlace) {
                NavigationStack {
                    PlaceSearchView(region: trip.region, nearby: nearbySearchCoordinate) { pendingPlace = $0 }
                }
            }
            .sheet(item: $editor) { editor in
                VisitEditorView(visit: editor.visit, isNew: editor.isNew, region: trip.region) { edited in
                    guard store.saveVisit(edited, in: tripID) else { return false }
                    mapDay = Calendar.current.startOfDay(for: edited.visitDate)
                    return true
                }
            }
            .alert("방문 일정을 삭제할까요?", isPresented: Binding(
                get: { visitToDelete != nil },
                set: { if !$0 { visitToDelete = nil } }
            ), presenting: visitToDelete) { visit in
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) { store.deleteVisit(visit.id, in: tripID) }
            } message: { visit in
                Text("‘\(visit.placeName)’ 일정의 알림도 함께 삭제됩니다.")
            }
        }
    }

    private func editVisit(_ visit: Visit) {
        editor = Editor(visit: visit, isNew: false)
    }

    private func defaultMapDay(for trip: Trip) -> Date {
        Calendar.current.startOfDay(for: trip.nextVisit(after: .now)?.visitDate ?? trip.days.first?.date ?? trip.startDate ?? .now)
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
        let day = mapDay ?? defaultMapDay(for: trip)
        let calendar = Calendar.current
        let date = calendar.isDateInToday(day)
            ? calendar.nextDate(after: .now, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime)
            : calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
        let fallback = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        let visitDate = date.flatMap { calendar.isDate($0, inSameDayAs: day) ? $0 : nil } ?? fallback
        let visit = Visit(placeName: name, visitDate: visitDate, coordinate: coordinate, address: address)
        editor = Editor(visit: visit, isNew: true)
    }

    private func itinerary(for trip: Trip) -> some View {
        List {
            if trip.visits.isEmpty {
                ContentUnavailableView {
                    Label("아직 방문 일정이 없어요", systemImage: "calendar")
                } description: {
                    Text("지도에서 가고 싶은 장소를 찜해 보세요.")
                } actions: {
                    Button("지도에서 장소 추가") { mode = .map }
                        .buttonStyle(.borderedProminent)
                }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let next = trip.nextVisit(after: context.date) {
                        Button {
                            editVisit(next)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("다음 목적지", systemImage: "location.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.teal)
                                Text(next.placeName)
                                    .font(.title2.bold())
                                Text("\(next.visitDate.dayLabel) · \(next.visitDate.timeLabel)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Label("다가오는 방문 일정이 없어요", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.teal.opacity(0.12))

                ForEach(trip.days) { day in
                    Section(day.date.dayLabel) {
                        ForEach(Array(day.visits.enumerated()), id: \.element.id) { index, visit in
                            Button { editVisit(visit) } label: {
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.teal)
                                        .frame(minWidth: 32, minHeight: 32)
                                        .background(.teal.opacity(0.12), in: Circle())
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(visit.placeName).font(.headline)
                                        Text(visit.visitDate.timeLabel)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("visit-row-\(visit.placeName)")
                            .swipeActions(allowsFullSwipe: false) {
                                Button { visitToDelete = visit } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .contextMenu {
                                Button("일정 삭제", systemImage: "trash", role: .destructive) { visitToDelete = visit }
                            }
                        }
                    }
                }
            }
        }
    }
}
