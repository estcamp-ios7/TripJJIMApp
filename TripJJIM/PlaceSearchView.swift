import MapKit
import OSLog
import SwiftUI

extension MKMapItem {
    var displayAddress: String? {
        let representations = addressRepresentations
        return [address?.fullAddress, representations?.fullAddress(includingRegion: false, singleLine: true),
                representations?.cityWithContext, representations?.regionName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

struct PlaceSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String?
    let coordinate: PlaceCoordinate
}

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let region: String?
    var nearby: PlaceCoordinate? = nil
    let onSelect: (PlaceSearchResult) -> Void
    @FocusState private var searchFocused: Bool
    @State private var canSearchWider = false
    private let logger = Logger(subsystem: "com.tripjjim.TripJJIM", category: "PlaceSearch")
    @State private var query = ""
    @State private var results: [PlaceSearchResult] = []
    @State private var operation: MKLocalSearch?
    @State private var message = "장소 이름이나 주소를 입력해 주세요."
    @State private var loading = false
    @State private var searchID = UUID()
    @State private var regionHint: MKCoordinateRegion?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("장소 이름 또는 주소", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit { search() }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("검색어 지우기")
                }
                Button { search() } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("검색")
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .buttonStyle(.plain)
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .frame(minHeight: 52)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary.opacity(0.22)) }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List {
                if loading {
                    ProgressView("장소를 검색 중이에요.")
                        .listRowBackground(Color.clear)
                } else if results.isEmpty {
                    Text(message).foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                if !results.isEmpty {
                    Section("검색 결과 \(results.count)개") {
                        ForEach(results) { result in
                            Button {
                                onSelect(result)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(result.name).font(.headline).foregroundStyle(.primary)
                                    Text(result.address ?? "주소 정보 없음")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if canSearchWider {
                    Button("지역 힌트 없이 다시 검색") { search(useRegionHint: false) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("장소 검색")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") { dismiss() }
            }
        }
        .onChange(of: query) {
            cancel()
            message = query.isEmpty ? "장소 이름이나 주소를 입력해 주세요." : "검색 키를 눌러 장소를 찾아보세요."
        }
        .onDisappear { cancel() }
    }

    private func cancel() {
        searchID = UUID()
        operation?.cancel()
        operation = nil
        loading = false
        canSearchWider = false
        results = []
    }

    private func search(useRegionHint: Bool = true) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        searchFocused = false
        cancel()
        let id = searchID
        loading = true
        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            request.resultTypes = [.address, .pointOfInterest, .physicalFeature]
            request.regionPriority = .default
            if useRegionHint, let nearby {
                let point = CLLocationCoordinate2D(latitude: nearby.latitude, longitude: nearby.longitude)
                request.region = MKCoordinateRegion(center: point, latitudinalMeters: 8_000, longitudinalMeters: 8_000)
            } else if useRegionHint, let regionHint {
                request.region = regionHint
            } else if useRegionHint, let region, !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let lookup = MKLocalSearch.Request()
                lookup.naturalLanguageQuery = region
                lookup.resultTypes = .address
                let lookupSearch = MKLocalSearch(request: lookup)
                operation = lookupSearch
                let response = try? await lookupSearch.start()
                guard searchID == id else { return }
                if let point = response?.mapItems.first?.location.coordinate {
                    let hint = MKCoordinateRegion(center: point, latitudinalMeters: 40_000, longitudinalMeters: 40_000)
                    regionHint = hint
                    request.region = hint
                }
            }
            guard searchID == id else { return }
            let hasHint = request.region.span.latitudeDelta > 0 && request.region.span.latitudeDelta < 180
                && useRegionHint && (nearby != nil || regionHint != nil)
            let search = MKLocalSearch(request: request)
            operation = search
            do {
                let response = try await search.start()
                guard searchID == id, operation === search else { return }
                results = response.mapItems.compactMap { item in
                    let address = item.displayAddress
                    guard let name = item.name ?? address else { return nil }
                    let point = item.location.coordinate
                    return PlaceSearchResult(name: name, address: address,
                                             coordinate: .init(latitude: point.latitude, longitude: point.longitude))
                }
                results = results.enumerated().sorted { lhs, rhs in
                    let left = relevance(lhs.element, to: text)
                    let right = relevance(rhs.element, to: text)
                    return left == right ? lhs.offset < rhs.offset : left < right
                }.map(\.element)
                logger.info("query=\(text, privacy: .private) hinted=\(hasHint) returned=\(response.mapItems.count) displayed=\(results.count)")
                message = "검색 결과가 없어요. 다른 검색어를 입력해 주세요."
            } catch {
                guard searchID == id, operation === search else { return }
                let mapError = error as NSError
                logger.info("query=\(text, privacy: .private) hinted=\(hasHint) failed domain=\(mapError.domain) code=\(mapError.code) displayed=0")
                message = mapError.domain == MKErrorDomain && mapError.code == MKError.Code.placemarkNotFound.rawValue
                    ? "검색 결과가 없어요. 다른 검색어를 입력해 주세요."
                    : "검색에 실패했어요. 인터넷 연결을 확인하고 다시 검색해 주세요."
            }
            canSearchWider = hasHint
            loading = false
        }
    }
    private func relevance(_ result: PlaceSearchResult, to text: String) -> Int {
        func normalized(_ value: String) -> String {
            String(value.lowercased().filter { $0.isLetter || $0.isNumber })
        }
        let term = normalized(text)
        guard !term.isEmpty else { return 3 }
        let name = normalized(result.name)
        if name == term { return 0 }
        if name.contains(term) { return 1 }
        if let address = result.address, normalized(address).contains(term) { return 2 }
        return 3
    }
}
