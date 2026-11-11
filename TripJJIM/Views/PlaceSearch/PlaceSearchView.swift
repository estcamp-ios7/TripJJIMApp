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
    var category: MKPointOfInterestCategory? = nil
}

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let region: String?
    var nearby: PlaceCoordinate? = nil
    var tripRegionLocation: TripRegionLocation? = nil
    var onShowMap: (() -> Void)? = nil
    let onSelect: (PlaceSearchResult) -> Void
    @FocusState private var searchFocused: Bool
    @State private var canSearchWider = false
    private let logger = Logger(subsystem: "com.tripjjim.TripJJIM", category: "PlaceSearch")
    @State private var query = ""
    @State private var results: [PlaceSearchResult] = []
    @State private var operation: MKLocalSearch?
    @State private var administrativeLookup: AdministrativeRegionSearch?
    @State private var message = "장소 이름이나 주소를 입력해 주세요."
    @State private var loading = false
    @State private var searchFailed = false
    @State private var searchID = UUID()
    @State private var regionHint: MKCoordinateRegion?
    @State private var activeHint: MKCoordinateRegion?
    @State private var hintLabel: String?
    @State private var widening = false
    @State private var suggestions: [MKLocalSearchCompletion] = []
    @State private var completer: PlaceSearchCompleter?
    @State private var submitted = false
    @State private var selectedSuggestion = false
    private var relatedResults: [PlaceSearchResult] {
        if selectedSuggestion { return results }
        let intent = PlaceSearchIntent(searchText)
        return results.filter { intent.relevance($0) <= 2 }
    }
    private var searchText: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var nearbyHint: MKCoordinateRegion? {
        nearby.map { coordinate in
            MKCoordinateRegion(center: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
                               latitudinalMeters: 8_000, longitudinalMeters: 8_000)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TripSearchField(prompt: "장소 이름 또는 주소", query: $query,
                            focused: $searchFocused, submitID: "place-search-submit",
                            verticalInset: 8, leadingInset: 8, emphasizesPrompt: true,
                            showMap: onShowMap.map { action in
                                { dismiss(); action() }
                            }) { search() }

            if query.isEmpty && suggestions.isEmpty && results.isEmpty && !loading {
                initialSearchGuide
            } else {
                searchResultsList
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("장소 검색")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") { dismiss() }
            }
        }
        .task(id: query) {
            guard !searchText.isEmpty else { return }
            let text = searchText
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch { return }
            guard searchText == text, !submitted else { return }
            let source = PlaceSearchCompleter()
            completer = source
            source.start(text, region: nearbyHint ?? tripRegionLocation?.mapRegion ?? regionHint) { [weak source] items in
                guard let source, completer === source, searchText == text, !submitted else { return }
                suggestions = items
                message = items.isEmpty ? "검색 버튼을 눌러 장소를 찾아보세요." : ""
            }
        }
        .onChange(of: query) {
            cancel()
            submitted = false
            results = []
            hintLabel = nil
            activeHint = nil
            canSearchWider = false
            message = searchText.isEmpty ? "장소 이름이나 주소를 입력해 주세요." : "검색어를 입력하고 있어요."
        }
        .onDisappear { cancel() }
    }

    private var initialSearchGuide: some View {
        GeometryReader { space in
            ScrollView {
                VStack(spacing: 12) {
                    Image(systemName: "location.circle")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.tripAccent)
                        .frame(width: 64, height: 64)
                        .background(Color.tripAccent.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    Text("어디를 방문할 예정인가요?")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("장소 이름이나 주소를 검색해 여행 일정에 추가해 보세요.")
                        .font(.subheadline)
                        .readableSecondaryForeground()
                        .frame(maxWidth: 264)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 52)
                .frame(maxWidth: .infinity, minHeight: space.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var searchResultsList: some View {
        List {
            if let label = hintLabel {
                Text(label).font(.footnote).readableSecondaryForeground()
                    .listRowBackground(Color.clear)
            }
            if loading {
                TripSearchStatusRow(title: widening ? "다른 지역도 검색 중이에요." : "장소를 검색 중이에요.",
                                    isLoading: true)
            } else if searchFailed {
                TripSearchStatusRow(title: message, icon: "exclamationmark.circle")
            } else if !message.isEmpty {
                if submitted && !widening && relatedResults.isEmpty {
                    TripSearchStatusRow(title: "검색 결과를 찾지 못했어요.",
                                        detail: "다른 검색어나 지역명으로 다시 검색해 보세요.")
                } else {
                    TripSearchStatusRow(title: message)
                }
            }
            if !suggestions.isEmpty {
                Section("자동완성 제안") {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                        Button { search(completion: suggestion) } label: {
                            TripSearchResultRow(title: suggestion.title, subtitle: suggestion.subtitle,
                                                icon: "magnifyingglass")
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color(uiColor: .systemBackground))
                    }
                }
            }
            let related = relatedResults
            let relatedIDs = Set(related.map(\.id))
            let other = results.filter { !relatedIDs.contains($0.id) }
            if !related.isEmpty {
                resultSection("검색 결과 \(related.count)개", items: related)
            }
            if !other.isEmpty {
                resultSection("다른 검색 결과 \(other.count)개", items: other)
            }
            if canSearchWider {
                Button { search(wider: true) } label: {
                    Label("다른 지역도 검색", systemImage: "globe")
                        .frame(minHeight: 44)
                }
                .disabled(loading)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    #if DEBUG
    fileprivate static func previewWithResults() -> Self {
        var view = Self(region: "부산") { _ in }
        view._query = State(initialValue: "부산역")
        view._submitted = State(initialValue: true)
        view._message = State(initialValue: "")
        view._results = State(initialValue: [
            PlaceSearchResult(name: "부산역", address: "부산광역시 동구 중앙대로 206",
                              coordinate: .init(latitude: 35.1151, longitude: 129.0415))
        ])
        return view
    }
    #endif

    private func resultSection(_ title: String, items: [PlaceSearchResult]) -> some View {
        Section(title) {
            ForEach(items) { result in
                Button {
                    onSelect(result)
                    dismiss()
                } label: {
                    TripSearchResultRow(title: result.name, subtitle: result.address ?? "주소 정보 없음")
                }
                .buttonStyle(.plain)
                .listRowBackground(Color(uiColor: .systemBackground))
            }
        }
    }

    private func cancel() {
        searchID = UUID()
        operation?.cancel()
        operation = nil
        administrativeLookup?.cancel()
        administrativeLookup = nil
        completer?.cancel()
        completer = nil
        suggestions = []
        loading = false
        searchFailed = false
    }

    private func search(wider: Bool = false, completion: MKLocalSearchCompletion? = nil) {
        let text = searchText
        guard !text.isEmpty else { return }
        searchFocused = false
        cancel()
        submitted = true
        if !wider { selectedSuggestion = completion != nil }
        widening = wider
        loading = true
        canSearchWider = false
        message = ""
        let id = searchID
        let intent = PlaceSearchIntent(text)
        Task {
            defer {
                if searchID == id {
                    loading = false
                    operation = nil
                }
            }
            do {
                let scope = if wider || completion != nil { nil as SearchScope? }
                            else { try await searchRegion(for: intent, id: id) }
                let hint = scope?.region
                try checkCurrent(id)
                if !wider {
                    activeHint = hint
                    hintLabel = scope?.label
                }
                let request = completion.map { MKLocalSearch.Request(completion: $0) } ?? MKLocalSearch.Request()
                if completion == nil {
                    request.naturalLanguageQuery = intent.area != nil && scope?.isExplicit != true && !wider
                        ? text : (intent.brand?.query ?? text)
                    request.resultTypes = intent.brand == nil ? [.address, .pointOfInterest, .physicalFeature] : .pointOfInterest
                    if let hint { request.region = hint }
                }
                let primary = try await fetch(request, id: id)
                var candidates = primary
                let rankingHint = hint ?? (wider ? activeHint : nil)
                let resultIntent = completion.map { PlaceSearchIntent($0.title, interpretBrand: false) } ?? intent
                let primaryRanked = resultIntent.rank(primary, near: rankingHint?.center)
                var usedFallback = false
                if completion == nil, !wider, intent.brand == nil, !intent.isAddress,
                   !primaryRanked.contains(where: { intent.relevance($0) <= 2 }) {
                    let fallback = MKLocalSearch.Request()
                    fallback.naturalLanguageQuery = scope?.isExplicit == true ? (intent.categoryQuery ?? text) : text
                    fallback.resultTypes = .pointOfInterest
                    if let category = intent.category {
                        fallback.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
                    }
                    if let hint { fallback.region = hint }
                    usedFallback = true
                    do {
                        candidates += try await fetch(fallback, id: id)
                    } catch {
                        try checkCurrent(id)
                        if primary.isEmpty { throw error }
                    }
                }
                try checkCurrent(id)
                let existing = results
                let ranked = resultIntent.rank(candidates, near: rankingHint?.center)
                if wider {
                    results += ranked.filter { item in
                        resultIntent.relevance(item) <= 2 && !existing.contains { $0.matches(item) }
                    }
                } else {
                    results = ranked
                }
                let nearbyMatches = ranked.filter { resultIntent.relevance($0) <= 2 }
                let insideHint = hint.map { scope in nearbyMatches.filter { $0.distance(to: scope.center) <= scope.searchRadius }.count } ?? 0
                canSearchWider = completion == nil && !wider && hint != nil && insideHint < 3
                if wider && results.count == existing.count {
                    message = "추가로 찾은 장소가 없어요."
                } else if relatedResults.isEmpty {
                    message = "관련 장소를 찾지 못했어요. 장소명이나 주소를 확인해 주세요."
                }
                let names = results.prefix(3).map(\.name).joined(separator: ", ")
                let loggedScope = scope?.label ?? "없음"
                logger.info("query=\(text, privacy: .private) scope=\(loggedScope, privacy: .private) hint=\(hint != nil) wider=\(wider) fallback=\(usedFallback) completion=\(completion != nil) primary=\(primary.count) supplemental=\(candidates.count - primary.count) displayed=\(results.count) top=\(names, privacy: .private)")
            } catch {
                guard searchID == id else { return }
                canSearchWider = wider && activeHint != nil
                searchFailed = true
                message = wider ? "다른 지역을 검색하지 못했어요. 다시 시도해 주세요."
                    : "검색에 실패했어요. 연결을 확인하고 다시 시도해 주세요."
                let failure = error as NSError
                logger.error("search failed wider=\(wider) domain=\(failure.domain) code=\(failure.code)")
            }
        }
    }

    private struct SearchScope {
        let region: MKCoordinateRegion
        let label: String
        var isExplicit = false
    }

    private func searchRegion(for intent: PlaceSearchIntent, id: UUID) async throws -> SearchScope? {
        if let area = intent.area {
            let matches = AdministrativeRegion.matches(area)
            let selected = matches.first { $0.name == region }
            if let selected, let saved = tripRegionLocation {
                return SearchScope(region: saved.mapRegion, label: "\(selected.name) 주변 우선 검색", isExplicit: true)
            }
            if let match = selected ?? (matches.count == 1 ? matches.first : nil),
               let location = try await resolveAdministrativeRegion(match, id: id) {
                return SearchScope(region: location.mapRegion, label: "\(match.name) 주변 우선 검색", isExplicit: true)
            }
            if matches.isEmpty, let explicit = try await resolveRegion(area, size: 8_000, id: id) {
                return SearchScope(region: explicit, label: "\(area) 주변 우선 검색", isExplicit: true)
            }
            return nil
        }
        if let nearbyHint { return SearchScope(region: nearbyHint, label: "지도에서 선택한 위치 주변 우선 검색") }
        guard let region, !region.isEmpty else { return nil }
        if let savedRegion = tripRegionLocation?.mapRegion ?? regionHint {
            return SearchScope(region: savedRegion, label: "\(region) 주변 우선 검색")
        }
        let matches = AdministrativeRegion.matches(region)
        let resolved: MKCoordinateRegion?
        if matches.count == 1, let match = matches.first {
            resolved = try await resolveAdministrativeRegion(match, id: id)?.mapRegion
        } else if matches.isEmpty {
            resolved = try await resolveRegion(region, size: 40_000, id: id)
        } else {
            resolved = nil
        }
        try checkCurrent(id)
        regionHint = resolved
        return resolved.map { SearchScope(region: $0, label: "\(region) 주변 우선 검색") }
    }

    private func resolveAdministrativeRegion(_ region: AdministrativeRegion, id: UUID) async throws -> TripRegionLocation? {
        let service = AdministrativeRegionSearch()
        administrativeLookup = service
        let location = try? await service.resolve(region)
        try checkCurrent(id)
        administrativeLookup = nil
        return location
    }

    private func resolveRegion(_ name: String, size: CLLocationDistance, id: UUID) async throws -> MKCoordinateRegion? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.resultTypes = .address
        let items: [PlaceSearchResult]
        do {
            items = try await fetch(request, id: id)
        } catch {
            try checkCurrent(id)
            return nil
        }
        let key = PlaceSearchIntent.normalized(name)
        guard let item = items.first(where: {
            PlaceSearchIntent.normalized($0.name).contains(key)
                || PlaceSearchIntent.normalized($0.address ?? "").contains(key)
        }) else { return nil }
        return MKCoordinateRegion(center: item.point, latitudinalMeters: size, longitudinalMeters: size)
    }

    private func checkCurrent(_ id: UUID) throws {
        guard searchID == id else { throw CancellationError() }
    }

    private func fetch(_ request: MKLocalSearch.Request, id: UUID) async throws -> [PlaceSearchResult] {
        try checkCurrent(id)
        request.regionPriority = .default
        let search = MKLocalSearch(request: request)
        operation = search
        do {
            let response = try await search.start()
            try checkCurrent(id)
            let results: [PlaceSearchResult] = response.mapItems.compactMap { item in
                let address = item.displayAddress
                let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let point = item.location.coordinate
                guard let displayName = name.flatMap({ $0.isEmpty ? nil : $0 }) ?? address,
                      CLLocationCoordinate2DIsValid(point) else { return nil }
                return PlaceSearchResult(name: displayName, address: address,
                                         coordinate: .init(latitude: point.latitude, longitude: point.longitude),
                                         category: item.pointOfInterestCategory)
            }
            logger.info("MapKit returned=\(response.mapItems.count) usable=\(results.count)")
            return results
        } catch let error as NSError where error.domain == MKErrorDomain
            && error.code == MKError.Code.placemarkNotFound.rawValue {
            try checkCurrent(id)
            logger.info("MapKit returned=0 usable=0")
            return []
        }
    }
}

@MainActor
private final class PlaceSearchCompleter: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var onUpdate: (([MKLocalSearchCompletion]) -> Void)?

    func start(_ query: String, region: MKCoordinateRegion?, onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onUpdate = onUpdate
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.regionPriority = .default
        if let region { completer.region = region }
        completer.queryFragment = query
    }

    func cancel() {
        onUpdate = nil
        completer.cancel()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate?(Array(completer.results.prefix(8)))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onUpdate?([])
    }
}

private extension MKCoordinateRegion {
    var searchRadius: CLLocationDistance {
        // Half the region's diagonal, used only to decide when to offer more results.
        CLLocation(latitude: center.latitude, longitude: center.longitude).distance(from:
            CLLocation(latitude: center.latitude + span.latitudeDelta / 2,
                       longitude: center.longitude + span.longitudeDelta / 2))
    }
}

extension PlaceSearchResult {
    fileprivate var point: CLLocationCoordinate2D {
        .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    fileprivate func distance(to point: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from:
            CLLocation(latitude: point.latitude, longitude: point.longitude))
    }

    fileprivate func matches(_ other: Self) -> Bool {
        guard PlaceSearchIntent.normalized(name) == PlaceSearchIntent.normalized(other.name) else { return false }
        if let address, let otherAddress = other.address,
           PlaceSearchIntent.normalized(address) != PlaceSearchIntent.normalized(otherAddress) {
            return coordinate == other.coordinate
        }
        return distance(to: other.point) < 20
    }
}

struct PlaceSearchIntent {
    struct Brand {
        let query: String
        let aliases: [String]

        func matches(_ name: String) -> Bool {
            let value = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return aliases.contains { alias in
                if value == alias { return true }
                guard value.hasPrefix(alias) else { return false }
                let suffix = value.dropFirst(alias.count)
                return suffix.first?.isWhitespace == true || suffix.hasSuffix("점")
            }
        }
    }

    private let term: String
    private let tokens: [String]
    let brand: Brand?
    let area: String?
    let isAddress: Bool
    let category: MKPointOfInterestCategory?
    let categoryQuery: String?

    init(_ text: String, interpretBrand: Bool = true) {
        let words = text.split(whereSeparator: \.isWhitespace)
        term = Self.normalized(text)
        tokens = words.map { Self.normalized(String($0)) }.filter { !$0.isEmpty }
        let token = words.first.map { String($0).lowercased() }
        let brands = [Brand(query: "CU", aliases: ["cu", "씨유"]),
                      Brand(query: "GS25", aliases: ["gs25", "지에스25"]),
                      Brand(query: "스타벅스", aliases: ["스타벅스", "starbucks"])]
        let remainder = words.dropFirst().joined(separator: " ")
        isAddress = text.range(of: #"(?:로|길|동|리)\s*\d|\d+-\d+"#, options: .regularExpression) != nil
        brand = isAddress || !interpretBrand ? nil : brands.first { candidate in token.map(candidate.aliases.contains) ?? false }
        let categoryTerms: [String: MKPointOfInterestCategory] = ["카페": .cafe, "맛집": .restaurant, "식당": .restaurant]
        category = !isAddress && interpretBrand && brand == nil ? words.last.flatMap { categoryTerms[String($0)] } : nil
        categoryQuery = category == nil ? nil : words.last.map(String.init)
        if brand != nil, !remainder.isEmpty {
            area = remainder
        } else if category != nil, words.count > 1 {
            area = words.dropLast().joined(separator: " ")
        } else {
            area = nil
        }
    }

    static func normalized(_ value: String) -> String {
        String(value.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    func relevance(_ result: PlaceSearchResult) -> Int {
        guard !term.isEmpty else { return 3 }
        let name = Self.normalized(result.name)
        let address = Self.normalized(result.address ?? "")
        if let brand, brand.matches(result.name) {
            if let area {
                let key = Self.normalized(area)
                if address.contains(key) { return 0 }
                if name.contains(key) { return 1 }
                return 2
            }
            return 0
        }
        if let category, result.category == category {
            if let area { return address.contains(Self.normalized(area)) ? 1 : 3 }
            return 1
        }
        if name == term || address == term { return 0 }
        if name.contains(term) || address.contains(term) { return 1 }
        if tokens.count > 1 && tokens.allSatisfy({ name.contains($0) || address.contains($0) }) { return 2 }
        return 3
    }

    func rank(_ results: [PlaceSearchResult], near center: CLLocationCoordinate2D?) -> [PlaceSearchResult] {
        let sorted = results.enumerated().filter { pair in
            brand?.matches(pair.element.name) ?? true
        }.sorted { lhs, rhs in
            let left = relevance(lhs.element)
            let right = relevance(rhs.element)
            if left != right { return left < right }
            if let center {
                let leftDistance = lhs.element.distance(to: center)
                let rightDistance = rhs.element.distance(to: center)
                if leftDistance != rightDistance { return leftDistance < rightDistance }
            }
            return lhs.offset < rhs.offset
        }
        var unique: [PlaceSearchResult] = []
        for (_, result) in sorted where !unique.contains(where: { $0.matches(result) }) {
            unique.append(result)
        }
        return unique
    }
}

struct TripSearchField: View {
    @Environment(\.colorScheme) private var colorScheme
    let prompt: String
    @Binding var query: String
    var focused: FocusState<Bool>.Binding
    let submitID: String
    var verticalInset: CGFloat = 4
    var leadingInset: CGFloat = 4
    var emphasizesPrompt = false
    var showMap: (() -> Void)? = nil
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: submit) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.medium))
                    .readableSecondaryForeground()
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("검색")
            .accessibilityIdentifier(submitID)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            TextField(prompt, text: $query,
                      prompt: emphasizesPrompt
                          ? Text(prompt).foregroundStyle(
                              colorScheme == .dark
                                  ? Color.primary.opacity(0.78)
                                  : Color.secondary
                          )
                          : nil)
                .focused(focused)
                .submitLabel(.search)
                .onSubmit(submit)
                .frame(minHeight: 48)

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .readableSecondaryForeground()
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("검색어 지우기")
            }

            if let showMap {
                Button(action: showMap) {
                    Image(systemName: "map")
                        .font(.body.weight(.medium))
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("지도에서 장소 선택")
                .accessibilityIdentifier("show-trip-map")
            }
        }
        .buttonStyle(.plain)
        .padding(.leading, leadingInset)
        .padding(.trailing, 4)
        .padding(.vertical, verticalInset)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.quaternary.opacity(0.45)) }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

struct TripSearchResultRow: View {
    let title: String
    let subtitle: String?
    var icon = "mappin.circle.fill"

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.tripAccent)
                .frame(width: 36, height: 36)
                .background(Color.tripAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                if let subtitle, !subtitle.isEmpty, subtitle != title {
                    Text(subtitle)
                        .font(.footnote)
                        .readableSecondaryForeground()
                        .lineLimit(3)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

struct TripSearchStatusRow: View {
    let title: String
    var detail: String? = nil
    var icon = "magnifyingglass"
    var isLoading = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isLoading {
            ProgressView().tint(Color.tripAccent).accessibilityHidden(true)
            } else {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.tripAccent)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                if let detail {
                    Text(detail).font(.footnote).readableSecondaryForeground()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview("장소 검색 · 초기 화면") {
    NavigationStack {
        PlaceSearchView(region: "부산") { _ in }
    }
}

#if DEBUG
#Preview("장소 검색 · 부산역 결과") {
    NavigationStack {
        PlaceSearchView.previewWithResults()
    }
}
#endif
