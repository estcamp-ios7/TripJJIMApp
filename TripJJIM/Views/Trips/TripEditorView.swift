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
    @State private var regionSelection: RegionSelection?
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
        if let name = trip?.region, let location = trip?.regionLocation {
            _regionSelection = State(initialValue: RegionSelection(name: name, location: location))
        }
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
                        TripRegionSearchView { selection in
                            region = selection.name
                            regionSelection = selection
                        }
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
            let id = try store.saveTrip(name: name, startDate: startDate, endDate: endDate, region: region, id: tripID,
                                        regionLocation: regionSelection?.name == region.trimmingCharacters(in: .whitespacesAndNewlines) ? regionSelection?.location : nil)
            onSave(id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct RegionSelection {
    let name: String
    let location: TripRegionLocation?
}

struct TripRegionSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (RegionSelection) -> Void
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var officialResults: [AdministrativeRegion] = []
    @State private var otherResults: [RegionSelection] = []
    @State private var service = AdministrativeRegionSearch()
    @State private var task: Task<Void, Never>?
    @State private var status: RegionSearchStatus = .ready
    @State private var unresolvedName: String?
    @State private var resolving = false

    private enum RegionSearchStatus {
        case ready, loading, empty, failure
    }

    var body: some View {
        VStack(spacing: 0) {
            TripSearchField(prompt: "예: 제주", query: $query,
                            focused: $searchFocused, submitID: "trip-region-submit", submit: runSearch)
            List {
                if resolving {
                    TripSearchStatusRow(title: "선택한 지역의 지도 위치를 확인하고 있어요.", isLoading: true)
                } else if officialResults.isEmpty && otherResults.isEmpty {
                    statusRow
                }
                if !officialResults.isEmpty || !otherResults.isEmpty {
                    Section("검색 결과 \(officialResults.count + otherResults.count)개") {
                        ForEach(officialResults) { result in
                            Button { select(result) } label: {
                                TripSearchResultRow(title: displayTitle(for: result), subtitle: displaySubtitle(for: result))
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color(uiColor: .systemBackground))
                            .disabled(resolving)
                            .accessibilityIdentifier("trip-region-result-\(result.id)")
                        }
                        ForEach(otherResults, id: \.name) { result in
                            Button { finish(result) } label: {
                                TripSearchResultRow(title: result.name, subtitle: result.location?.sourceAddress)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color(uiColor: .systemBackground))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("지역 검색")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") { dismiss() }
            }
        }
        .onChange(of: query) { updateQuery() }
        .onDisappear { cancelSearch() }
        .alert("지역의 지도 위치를 확인하지 못했어요", isPresented: Binding(
            get: { unresolvedName != nil },
            set: { if !$0 { unresolvedName = nil } }
        ), presenting: unresolvedName) { name in
            Button("지역 이름만 선택") { finish(RegionSelection(name: name, location: nil)) }
            Button("취소", role: .cancel) {}
        } message: { _ in
            Text("지역 이름을 저장하거나 다른 검색 결과를 선택할 수 있어요.")
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch status {
        case .ready:
            TripSearchStatusRow(title: "지역 이름을 입력하고 검색해 주세요.", detail: "시·도와 시·군·구 이름을 함께 입력해도 좋아요.")
        case .loading:
            TripSearchStatusRow(title: "지역을 검색 중이에요.", isLoading: true)
        case .empty:
            TripSearchStatusRow(title: "검색 결과를 찾지 못했어요.", detail: "시·도 이름을 함께 입력해 보세요.")
        case .failure:
            TripSearchStatusRow(title: "지역을 검색할 수 없어요.", detail: "연결을 확인하고 다시 검색해 주세요.",
                                icon: "exclamationmark.circle")
        }
    }

    private func displayTitle(for result: AdministrativeRegion) -> String {
        if !result.locality.isEmpty { return result.locality }
        if result.province == AdministrativeRegion.integratedName, !result.district.isEmpty {
            return result.district
        }
        return result.name
    }

    private func displaySubtitle(for result: AdministrativeRegion) -> String {
        if !result.locality.isEmpty {
            return [result.province, result.district].filter { !$0.isEmpty }.joined(separator: " ")
        }
        if result.province == AdministrativeRegion.integratedName, !result.district.isEmpty {
            return result.district.hasSuffix("구") ? "\(result.province) · \(result.subtitle)" : result.province
        }
        return result.subtitle
    }

    private func cancelSearch() {
        task?.cancel()
        task = nil
        service.cancel()
        resolving = false
    }

    private func updateQuery() {
        cancelSearch()
        officialResults = AdministrativeRegion.matches(query)
        otherResults = []
        status = .ready
    }

    private func runSearch() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        searchFocused = false
        updateQuery()
        guard officialResults.isEmpty else { return }
        status = .loading
        task = Task {
            do {
                let response = try await service.lookup(term)
                try Task.checkCancellation()
                var seen: Set<String> = []
                for item in response.mapItems {
                    guard let address = item.displayAddress,
                          AdministrativeRegion.key(address).contains(AdministrativeRegion.key(term)) else { continue }
                    let fullName = address.replacingOccurrences(of: "^대한민국\\s+", with: "", options: .regularExpression)
                    let official = AdministrativeRegion.matches(fullName)
                    if !official.isEmpty {
                        officialResults += official.filter { seen.insert($0.id).inserted }
                    } else if seen.insert(AdministrativeRegion.key(fullName)).inserted,
                              let location = TripRegionLocation(item: item, bounds: response.mapItems.count == 1 ? response.boundingRegion : nil) {
                        otherResults.append(RegionSelection(name: fullName, location: location))
                    }
                }
                status = .empty
            } catch let error as NSError {
                guard !Task.isCancelled else { return }
                status = error.domain == MKErrorDomain && error.code == MKError.Code.placemarkNotFound.rawValue
                    ? .empty : .failure
            }
        }
    }

    private func select(_ region: AdministrativeRegion) {
        cancelSearch()
        resolving = true
        task = Task {
            let location = try? await service.resolve(region)
            guard !Task.isCancelled else { return }
            resolving = false
            if let location {
                finish(RegionSelection(name: region.name, location: location))
            } else {
                unresolvedName = region.name
            }
        }
    }

    #if DEBUG
    static func preview(query: String) -> Self {
        var view = Self { _ in }
        view._query = State(initialValue: query)
        view._officialResults = State(initialValue: AdministrativeRegion.matches(query))
        return view
    }
    #endif

    private func finish(_ selection: RegionSelection) {
        onSelect(selection)
        dismiss()
    }
}

#Preview("지역 검색") {
    NavigationStack {
        TripRegionSearchView { _ in }
    }
}

#Preview("여행 만들기") {
    TripEditorView(trip: nil) { _ in }
        .environment(PreviewData.makeStore(trips: []))
}

#Preview("여행 수정") {
    TripEditorView(trip: PreviewData.trip) { _ in }
        .environment(PreviewData.makeStore())
}
