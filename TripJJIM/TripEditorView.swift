import MapKit
import SwiftUI

enum TripEditorRoute: Identifiable {
    case create
    case edit(Trip)

    var trip: Trip? {
        if case let .edit(trip) = self { return trip }
        return nil
    }

    var id: String { trip?.id.uuidString ?? "create" }
}

struct TripEditorView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var region: String
    @State private var error: String?
    private let tripID: Trip.ID?
    private let onSave: (Trip.ID) -> Void

    init(trip: Trip?, onSave: @escaping (Trip.ID) -> Void) {
        self.tripID = trip?.id
        self.onSave = onSave
        let today = Calendar.current.startOfDay(for: .now)
        _name = State(initialValue: trip?.name ?? "")
        _startDate = State(initialValue: trip?.startDate ?? trip?.days.first?.date ?? today)
        _endDate = State(initialValue: trip?.endDate ?? trip?.days.last?.date ?? today)
        _region = State(initialValue: trip?.region ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("여행 정보") {
                    TextField("여행 이름", text: $name)
                        .accessibilityIdentifier("trip-name")
                }
                Section("여행 기간") {
                    DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                        .accessibilityIdentifier("trip-start-date")
                    DatePicker("종료일", selection: $endDate, displayedComponents: .date)
                        .accessibilityIdentifier("trip-end-date")
                }
                Section("여행 지역") {
                    TextField("지역 이름", text: $region)
                        .accessibilityIdentifier("trip-region")
                    NavigationLink {
                        TripRegionSearchView(region: $region)
                    } label: {
                        Label("지도에서 지역 찾기", systemImage: "magnifyingglass")
                    }
                }
                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("trip-editor-error")
                    }
                }
            }
            .navigationTitle(tripID == nil ? "새 여행 만들기" : "여행 수정")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .accessibilityIdentifier("save-trip")
                }
            }
        }
    }

    private func save() {
        do {
            let id = try store.saveTrip(name: name, startDate: startDate, endDate: endDate, region: region, id: tripID)
            onSave(id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct TripRegionSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var region: String
    @State private var query = ""
    @State private var results: [Result] = []
    @State private var search: MKLocalSearch?
    @State private var message = "지역 이름을 입력하고 검색해 주세요."

    private struct Result: Identifiable {
        let id = UUID()
        let name: String
    }

    var body: some View {
        List {
            if results.isEmpty { Text(message).foregroundStyle(.secondary) }
            ForEach(results) { result in
                Button {
                    region = result.name
                    dismiss()
                } label: {
                    Label(result.name, systemImage: "mappin.circle")
                }
            }
        }
        .navigationTitle("지역 검색")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "예: 제주")
        .onSubmit(of: .search, runSearch)
        .onChange(of: query) {
            cancelSearch()
            message = "지역 이름을 입력하고 검색해 주세요."
        }
        .onDisappear { cancelSearch() }
    }

    private func cancelSearch() {
        search?.cancel()
        search = nil
        results = []
    }

    private func runSearch() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        cancelSearch()
        message = "지역을 검색 중이에요."
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = term
        request.resultTypes = .address
        let operation = MKLocalSearch(request: request)
        search = operation
        Task {
            do {
                let response = try await operation.start()
                guard search === operation else { return }
                var seen: Set<String> = []
                results = response.mapItems.compactMap { item in
                    guard let name = item.name, seen.insert(name).inserted else { return nil }
                    return Result(name: name)
                }
                message = "검색 결과가 없어요. 다른 이름으로 검색하거나 지역을 직접 입력해 주세요."
            } catch {
                guard search === operation else { return }
                message = "지역을 검색할 수 없어요. 연결을 확인하거나 지역을 직접 입력해 주세요."
            }
        }
    }
}
