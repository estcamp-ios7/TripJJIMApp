import SwiftUI

struct TripListView: View {
    @Environment(TripStore.self) private var store
    @State private var tripToRename: Trip?
    @State private var tripToDelete: Trip?
    @State private var isEditingName = false
    @State private var name = ""

    var body: some View {
        NavigationStack {
            List {
                if store.trips.isEmpty {
                    ContentUnavailableView {
                        Label("어디로 떠날까요?", systemImage: "map")
                    } description: {
                        Text("여행을 만들고 가고 싶은 곳을 지도에 찜해 보세요.")
                    } actions: {
                        Button("새 여행 만들기") { editName() }
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
                                        Text("방문 일정 \(trip.visits.count)개")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .leading) {
                                Button { editName(of: trip) } label: {
                                    Label("이름 수정", systemImage: "pencil")
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
                                Button("이름 수정", systemImage: "pencil") { editName(of: trip) }
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
                    Button { editName() } label: { Label("새 여행", systemImage: "plus") }
                }
            }
            .alert(tripToRename == nil ? "새 여행" : "여행 이름 수정", isPresented: $isEditingName) {
                TextField("여행 이름", text: $name)
                Button("취소", role: .cancel) {}
                Button("저장") {
                    store.saveTrip(name: cleanName, id: tripToRename?.id)
                }
                .disabled(cleanName.isEmpty)
            } message: {
                Text("여행에 기억하기 쉬운 이름을 붙여 보세요.")
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

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func editName(of trip: Trip? = nil) {
        tripToRename = trip
        name = trip?.name ?? ""
        isEditingName = true
    }
}
