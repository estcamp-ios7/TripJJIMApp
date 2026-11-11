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

private struct RegionSelection {
    let name: String
    let location: TripRegionLocation?
}

private struct TripRegionSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (RegionSelection) -> Void
    @State private var query = ""
    @State private var officialResults: [AdministrativeRegion] = []
    @State private var otherResults: [RegionSelection] = []
    @State private var service = AdministrativeRegionSearch()
    @State private var task: Task<Void, Never>?
    @State private var message = "지역 이름을 입력하고 검색해 주세요."
    @State private var unresolvedName: String?
    @State private var resolving = false

    var body: some View {
        List {
            if resolving {
                ProgressView("선택한 지역의 지도 위치를 확인하고 있어요.")
            } else if officialResults.isEmpty && otherResults.isEmpty {
                Text(message).foregroundStyle(.secondary)
            }
            ForEach(officialResults) { result in
                Button { select(result) } label: { row(result.name, subtitle: result.subtitle) }
                    .disabled(resolving)
                    .accessibilityIdentifier("trip-region-result-\(result.id)")
            }
            ForEach(otherResults, id: \.name) { result in
                Button { finish(result) } label: { row(result.name, subtitle: result.location?.sourceAddress) }
            }
        }
        .navigationTitle("지역 검색")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "예: 제주")
        .onSubmit(of: .search, runSearch)
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

    private func row(_ title: String, subtitle: String?) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                if let subtitle, subtitle != title {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "mappin.circle")
        }
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
        message = "지역 이름을 입력하고 검색해 주세요."
    }

    private func runSearch() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        updateQuery()
        guard officialResults.isEmpty else { return }
        message = "지역을 검색 중이에요."
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
                message = "검색 결과가 없어요. 시·도 이름을 함께 입력해 보세요."
            } catch let error as NSError {
                guard !Task.isCancelled else { return }
                message = error.domain == MKErrorDomain && error.code == MKError.Code.placemarkNotFound.rawValue
                    ? "검색 결과가 없어요. 시·도 이름을 함께 입력해 보세요."
                    : "지역을 검색할 수 없어요. 연결을 확인해 주세요."
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
