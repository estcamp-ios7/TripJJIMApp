import SwiftUI

struct TripListView: View {
    @Environment(TripStore.self) private var store
    @State private var path: [Trip.ID] = []
    @State private var editor: TripEditorRoute?
    @State private var createdTripID: Trip.ID?
    @State private var tripToDelete: Trip?

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
                    Section("내 여행") {
                        ForEach(store.trips) { trip in
                            NavigationLink(value: trip.id) {
                                HStack(spacing: 14) {
                                    Image(systemName: "suitcase.rolling.fill")
                                        .foregroundStyle(.teal)
                                        .frame(width: 40, height: 40)
                                        .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(trip.name)
                                            .font(.headline)
                                        if let summary = trip.travelSummary {
                                            Text(summary)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text("방문 일정 \(trip.visits.count)개")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .leading) {
                                Button { editor = .edit(trip) } label: {
                                    Label("여행 수정", systemImage: "pencil")
                                }
                                .tint(.teal)
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
            .navigationTitle("TripJJIM")
            .navigationDestination(for: UUID.self) { id in
                TripDetailView(tripID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editor = .create } label: { Label("새 여행", systemImage: "plus") }
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
        }
    }

    private func openCreatedTrip() {
        guard let createdTripID else { return }
        path.append(createdTripID)
        self.createdTripID = nil
    }
}
