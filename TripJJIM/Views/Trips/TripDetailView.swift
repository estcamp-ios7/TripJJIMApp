import SwiftUI

struct TripDetailView: View {
    @Environment(TripStore.self) private var store
    @Environment(AppRouter.self) private var router
    let tripID: Trip.ID
    @Environment(\.dismiss) private var dismiss
    @State private var tripEditor: TripEditorRoute?
    @State private var isDeletingTrip = false
    @State private var editor: Editor?
    @State private var searchingPlace = false
    @State private var nearbySearchCoordinate: PlaceCoordinate?
    @State private var pendingPlace: PlaceSearchResult?
    @State private var mapDay: Date?

    private struct Editor: Identifiable {
        var id: Visit.ID { visit.id }
        let visit: Visit
        let isNew: Bool
    }
    @State private var detailVisitID: Visit.ID?
    @State private var visitToDelete: Visit?

    var body: some View {
        if let trip = store.trip(withID: tripID) {
            VStack(spacing: 0) {
                if let summary = trip.travelSummary {
                    Text(summary)
                        .font(.subheadline)
                        .readableSecondaryForeground()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                let days = travelDays(for: trip)
                TravelDayTabBar(days: days, selectedDay: selectedDayBinding(for: trip))
                itinerary(for: trip, on: selectedDay(for: trip))
            }
            .navigationDestination(item: $detailVisitID) { id in
                VisitDetailView(tripID: tripID, visitID: id) { date in
                    mapDay = Calendar.current.startOfDay(for: date)
                }
            }
            .navigationTitle(trip.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button("여행 수정", systemImage: "pencil") { tripEditor = .edit(trip) }
                        Button("여행 삭제", systemImage: "trash", role: .destructive) { isDeletingTrip = true }
                    } label: {
                        Label("여행 관리", systemImage: "ellipsis.circle")
                    }
                    Button { openPlaceSearch(near: nil) } label: { Label("장소 검색", systemImage: "magnifyingglass") }
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
                    PlaceSearchView(
                        region: trip.region,
                        nearby: nearbySearchCoordinate,
                        tripRegionLocation: trip.regionLocation,
                        onShowMap: { router.showMap(for: tripID) }
                    ) { pendingPlace = $0 }
                }
            }
            .sheet(item: $editor) { editor in
                VisitEditorView(visit: editor.visit, isNew: editor.isNew, region: trip.region, tripRegionLocation: trip.regionLocation) { edited in
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

    private func showVisit(_ visit: Visit) {
        detailVisitID = visit.id
    }

    private func editVisit(_ visit: Visit) {
        editor = Editor(visit: visit, isNew: false)
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

    private func selectedDay(for trip: Trip) -> Date {
        let days = travelDays(for: trip)
        guard let mapDay else { return defaultMapDay(for: trip) }
        return days.contains(where: { Calendar.current.isDate($0, inSameDayAs: mapDay) })
            ? Calendar.current.startOfDay(for: mapDay)
            : defaultMapDay(for: trip)
    }

    private func selectedDayBinding(for trip: Trip) -> Binding<Date> {
        Binding(
            get: { selectedDay(for: trip) },
            set: { mapDay = Calendar.current.startOfDay(for: $0) }
        )
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

    private func dayNumber(for visit: Visit, in trip: Trip) -> Int {
        let days = travelDays(for: trip)
        return (days.firstIndex {
            Calendar.current.isDate($0, inSameDayAs: visit.visitDate)
        } ?? 0) + 1
    }

    private func pinNumber(for visit: Visit, in trip: Trip) -> Int {
        let visits = trip.days.first {
            Calendar.current.isDate($0.date, inSameDayAs: visit.visitDate)
        }?.visits ?? []
        return (visits.firstIndex { $0.id == visit.id } ?? 0) + 1
    }

    private func itinerary(for trip: Trip, on selectedDay: Date) -> some View {
        let visits = trip.days.first {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDay)
        }?.visits ?? []

        return List {
            if !trip.visits.isEmpty {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let next = trip.nextVisit(after: context.date) {
                        Button {
                            showVisit(next)
                        } label: {
                            NextDestinationCard(
                                visit: next,
                                dayNumber: dayNumber(for: next, in: trip),
                                pinNumber: pinNumber(for: next, in: trip)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Label("다가오는 방문 일정이 없어요", systemImage: "checkmark.circle")
                            .readableSecondaryForeground()
                    }
                }
                .listRowBackground(Color.tripAccent.opacity(0.12))
            }

            if visits.isEmpty {
                ContentUnavailableView {
                    Label("이날은 아직 일정이 없어요", systemImage: "calendar")
                } description: {
                    Text("지도에서 이 날짜에 방문할 장소를 추가해 보세요.")
                } actions: {
                    Button("지도에서 장소 추가") { router.showMap(for: tripID) }
                        .buttonStyle(.borderedProminent)
                }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(Array(visits.enumerated()), id: \.element.id) { index, visit in
                        Button { showVisit(visit) } label: {
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.tripAccent)
                                        .frame(minWidth: 32, minHeight: 32)
                                        .background(Color.tripAccent.opacity(0.12), in: Circle())
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(visit.placeName).font(.headline)
                                        Text(visit.visitDate.timeLabel)
                                            .font(.subheadline)
                                            .readableSecondaryForeground()
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
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

private struct NextDestinationCard: View {
    let visit: Visit
    let dayNumber: Int
    let pinNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("다음 목적지", systemImage: "location.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.tripAccent)
                    Spacer()
                    Text("\(pinNumber)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.tripAccent)
                        .frame(minWidth: 32, minHeight: 32)
                        .background(Color.tripAccent.opacity(0.12), in: Circle())
                        .accessibilityLabel("\(pinNumber)번째 핀")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                NextDestinationInfoRow(
                    title: "\(dayNumber)일차",
                    systemImage: "calendar"
                )
                NextDestinationInfoRow(
                    title: addressLabel,
                    systemImage: "mappin.and.ellipse"
                )
                NextDestinationInfoRow(
                    title: reminderLabel,
                    systemImage: visit.reminderEnabled ? "bell.fill" : "bell.slash"
                )
                NextDestinationInfoRow(
                    title: memoLabel,
                    systemImage: "note.text",
                    isEmphasized: true
                )
            }
            .font(.subheadline)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addressLabel: String {
        guard let address = visit.address?.trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty else {
            return "주소 정보가 없어요"
        }
        return address
    }

    private var memoLabel: String {
        guard let memo = visit.memo?.trimmingCharacters(in: .whitespacesAndNewlines),
              !memo.isEmpty else {
            return "작성한 방문 메모가 없어요"
        }
        return memo
    }

    private var reminderLabel: String {
        guard visit.reminderEnabled else { return "알림 꺼짐" }

        let preset = visit.selectedReminderPreset
        guard preset == .custom else {
            return preset.title
        }
        return "직접 설정 · \(dayLabel(for: visit.reminderDate)) \(visit.reminderDate.timeLabel)"
    }

    private func dayLabel(for date: Date) -> String {
        date.formatted(
            .dateTime
                .month()
                .day()
                .weekday(.wide)
                .locale(Locale(identifier: "ko_KR"))
        )
    }
}

private struct NextDestinationInfoRow: View {
    let title: String
    let systemImage: String
    var isEmphasized = false

    var body: some View {
        Label {
            Text(title)
                .fontWeight(isEmphasized ? .medium : .regular)
                .foregroundStyle(Color.primary.opacity(isEmphasized ? 1 : 0.78))
                .lineLimit(isEmphasized ? 3 : 2)
                .multilineTextAlignment(.leading)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.tripAccent)
                .frame(width: 18)
        }
    }
}

struct TravelDayTabBar: View {
    let days: [Date]
    @Binding var selectedDay: Date

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                    Button {
                        selectedDay = day
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(index + 1)일차")
                                .font(.subheadline.weight(.semibold))
                            Text(day, format: .dateTime.month().day().weekday(.short))
                                .font(.caption)
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            isSelected
                                ? Color.tripAccent
                                : Color.secondary.opacity(0.12),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(index + 1)일차, \(day.dayLabel)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}
