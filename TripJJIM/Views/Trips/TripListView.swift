import SwiftUI

struct TripListView: View {
    @Environment(TripStore.self) private var store
    @Binding var path: [Trip.ID]
    @State private var editor: TripEditorRoute?
    @State private var createdTripID: Trip.ID?
    @State private var tripToDelete: Trip?
    @State private var isEditing = false
    @State private var selectedTripIDs: Set<Trip.ID> = []
    @State private var isConfirmingBulkDelete = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.trips.isEmpty {
                    ContentUnavailableView {
                        Label("어디로 떠날까요?", systemImage: "map")
                    } description: {
                        Text("여행을 만들고 가고 싶은 곳을 지도에 찜해 보세요.")
                    } actions: {
                        Button("새 여행 만들기") { editor = .create }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("create-trip")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(store.trips) { trip in
                            if isEditing {
                                Button {
                                    toggleSelection(for: trip.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedTripIDs.contains(trip.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundStyle(selectedTripIDs.contains(trip.id) ? Color.tripAccent : Color.secondary)
                                            .accessibilityHidden(true)
                                        TripListRowContent(trip: trip)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(trip.name), \(selectedTripIDs.contains(trip.id) ? "선택됨" : "선택 안 됨")")
                                .accessibilityIdentifier("select-trip-\(trip.id)")
                            } else {
                                HStack(spacing: 8) {
                                    NavigationLink(value: trip.id) {
                                        TripListRowContent(trip: trip)
                                    }

                                    Menu {
                                        Button("여행 수정", systemImage: "pencil") {
                                            editor = .edit(trip)
                                        }
                                        Button("여행 삭제", systemImage: "trash", role: .destructive) {
                                            tripToDelete = trip
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.title3)
                                            .frame(minWidth: 44, minHeight: 44)
                                    }
                                    .accessibilityLabel("\(trip.name) 관리")
                                }
                                .swipeActions(edge: .leading) {
                                    Button { editor = .edit(trip) } label: {
                                        Label("여행 수정", systemImage: "pencil")
                                    }
                                    .tint(Color.tripAccent)
                                }
                                .swipeActions(allowsFullSwipe: false) {
                                    Button { tripToDelete = trip } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                                .contextMenu {
                                    Button("여행 수정", systemImage: "pencil") { editor = .edit(trip) }
                                    Button("여행 삭제", systemImage: "trash", role: .destructive) { tripToDelete = trip }
                                }
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                TripListSubtitle()
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
            }
            .navigationTitle("나의 여행")
            .navigationDestination(for: UUID.self) { id in
                TripDetailView(tripID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "완료" : "편집") {
                        setEditing(!isEditing)
                    }
                    .disabled(store.trips.isEmpty)
                    .accessibilityIdentifier("edit-trips")
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    if isEditing {
                        Button(role: .destructive) {
                            isConfirmingBulkDelete = true
                        } label: {
                            Label("선택 삭제 (\(selectedTripIDs.count))", systemImage: "trash")
                        }
                        .disabled(selectedTripIDs.isEmpty)
                        .accessibilityIdentifier("delete-selected-trips")
                    } else {
                        Button { editor = .create } label: { Label("새 여행", systemImage: "plus") }
                    }
                }
            }
            .sheet(item: $editor, onDismiss: openCreatedTrip) { route in
                TripEditorView(trip: route.trip) { id in
                    if route.trip == nil { createdTripID = id }
                    editor = nil
                }
            }
            .alert("여행을 삭제할까요?", isPresented: Binding(
                get: { tripToDelete != nil },
                set: { if !$0 { tripToDelete = nil } }
            ), presenting: tripToDelete) { trip in
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) { store.deleteTrip(trip.id) }
            } message: { trip in
                Text("‘\(trip.name)’의 모든 방문 일정과 알림도 함께 삭제됩니다.")
            }
            .alert("선택한 여행을 삭제할까요?", isPresented: $isConfirmingBulkDelete) {
                Button("취소", role: .cancel) {}
                Button("\(selectedTripIDs.count)개 삭제", role: .destructive) {
                    deleteSelectedTrips()
                }
            } message: {
                Text("선택한 여행의 모든 방문 일정과 알림도 함께 삭제됩니다.")
            }
        }
    }

    private func toggleSelection(for tripID: Trip.ID) {
        if selectedTripIDs.contains(tripID) {
            selectedTripIDs.remove(tripID)
        } else {
            selectedTripIDs.insert(tripID)
        }
    }

    private func setEditing(_ editing: Bool) {
        isEditing = editing
        if !editing {
            selectedTripIDs.removeAll()
        }
    }

    private func deleteSelectedTrips() {
        for tripID in selectedTripIDs {
            store.deleteTrip(tripID)
        }
        selectedTripIDs.removeAll()
        isEditing = false
    }

    private func openCreatedTrip() {
        guard let createdTripID else { return }
        path.append(createdTripID)
        self.createdTripID = nil
    }
}

private struct TripListSubtitle: View {
    var body: some View {
        Text("어디로 떠나시나요?")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TripListRowContent: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "suitcase.rolling.fill")
                .foregroundStyle(Color.tripAccent)
                .frame(width: 40, height: 40)
                .background(Color.tripAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.title3.bold())
                if let region = trip.region, !region.isEmpty {
                    Text(region)
                        .font(.subheadline)
                        .readableSecondaryForeground()
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let period = TripListPeriod(start: trip.startDate, end: trip.endDate) {
                    Text("\(period.dates) · \(period.duration)")
                        .font(.subheadline)
                        .readableSecondaryForeground()
                        .fixedSize(horizontal: false, vertical: true)
                }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text("남은 방문 일정 \(trip.visits.lazy.filter { $0.visitDate > context.date }.count)개")
                        .font(.subheadline)
                        .readableSecondaryForeground()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TripListPeriod {
    let dates: String
    let duration: String

    init?(start: Date?, end: Date?, calendar: Calendar = .current) {
        guard let start, let end else { return nil }
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        guard first <= last,
              let nights = calendar.dateComponents([.day], from: first, to: last).day else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        let startLabel = formatter.string(from: first)

        if nights == 0 {
            dates = startLabel
            duration = "당일 여행"
        } else {
            if calendar.isDate(first, equalTo: last, toGranularity: .year) {
                formatter.dateFormat = "MM.dd"
            }
            dates = "\(startLabel) ~ \(formatter.string(from: last))"
            duration = "\(nights)박 \(nights + 1)일"
        }
    }
}
