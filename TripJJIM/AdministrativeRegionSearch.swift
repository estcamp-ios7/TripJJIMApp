import MapKit

struct AdministrativeRegion: Identifiable {
    let id: String
    let province: String
    let district: String
    let locality: String

    static let integratedName = "전남광주통합특별시"
    private static let gwangjuDistricts: Set<String> = ["동구", "서구", "남구", "북구", "광산구"]

    static let formerGwangju = Self(id: "former-gwangju", province: integratedName, district: "", locality: "")
    static let formerJeonnam = Self(id: "former-jeonnam", province: integratedName, district: "", locality: "")

    var name: String {
        switch id {
        case Self.formerGwangju.id: "\(province) · 광주 지역"
        case Self.formerJeonnam.id: "\(province) · 전남 지역"
        default: [province, district, locality].filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    private var formerProvince: String? {
        guard province == Self.integratedName, !district.isEmpty else { return nil }
        return Self.gwangjuDistricts.contains(district) ? "광주광역시" : "전라남도"
    }

    var subtitle: String {
        if id == Self.formerGwangju.id { return "구 광주광역시 지역" }
        if id == Self.formerJeonnam.id { return "구 전라남도 지역" }
        if let formerProvince {
            return "구 " + [formerProvince, district, locality].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return district.isEmpty ? "대한민국" : province
    }

    var isIntegratedProvince: Bool {
        province == Self.integratedName && district.isEmpty && locality.isEmpty
            && id != Self.formerGwangju.id && id != Self.formerJeonnam.id
    }

    var mapQueries: [String] {
        if id == Self.formerGwangju.id { return ["광주광역시"] }
        if id == Self.formerJeonnam.id { return ["전라남도"] }
        if let formerProvince {
            return [name, [formerProvince, district, locality].filter { !$0.isEmpty }.joined(separator: " ")]
        }
        return [name]
    }

    private static let provinceAliases: [String: [String]] = [
        "서울특별시": ["서울", "Seoul"], "부산광역시": ["부산"], "대구광역시": ["대구"],
        "인천광역시": ["인천"], "대전광역시": ["대전"], "울산광역시": ["울산"],
        "세종특별자치시": ["세종", "세종시"], "경기도": ["경기"],
        "강원특별자치도": ["강원", "강원도"], "충청북도": ["충북"], "충청남도": ["충남"],
        "전북특별자치도": ["전북", "전라북도"], "경상북도": ["경북"], "경상남도": ["경남"],
        "제주특별자치도": ["제주", "제주도"], integratedName: ["광주특별시", "전남광주"]
    ]

    private var aliases: Set<String> {
        if id == Self.formerGwangju.id { return ["광주", "광주광역시", Self.key(name)] }
        if id == Self.formerJeonnam.id { return ["전남", "전라남도", Self.key(name)] }
        var parents = [province] + (Self.provinceAliases[province] ?? [])
        if formerProvince == "전라남도" { parents += ["전라남도", "전남"] }
        if formerProvince == "광주광역시" { parents += ["광주광역시", "광주"] }
        if district.isEmpty && locality.isEmpty { return Set(parents.map(Self.key)) }
        let districtParts = district.split(separator: " ").map(String.init)
        let districtNames = [district] + districtParts.suffix(1)
        let localNames = locality.isEmpty ? districtNames : [locality, district + " " + locality]
        let variants = locality.isEmpty ? Set(localNames.flatMap { [$0, Self.shortName($0)] }) : Set(localNames)
        return Set(variants.flatMap { part in ([part] + parents.map { $0 + part }).map(Self.key) })
    }

    private static func shortName(_ value: String) -> String {
        guard value.count >= 3, let suffix = value.last, "시군구읍면동".contains(suffix) else { return value }
        return String(value.dropLast())
    }

    static func key(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func load(_ data: String) -> [Self] {
        data.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 4 else { return nil }
            // Sejong's legal-district file repeats the city as an intermediate label.
            if fields[1] == "세종특별자치시", fields[2] == "세종시", fields[3].isEmpty { return nil }
            let district = fields[1] == "세종특별자치시" ? "" : fields[2]
            return Self(id: fields[0], province: fields[1], district: district, locality: fields[3])
        }
    }

    static let catalog: [Self] = {
        guard let url = Bundle.main.url(forResource: "KoreanAdministrativeRegions", withExtension: "txt"),
              let data = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return load(data)
    }()

    private static let index = makeIndex(catalog)

    static func makeIndex(_ catalog: [Self]) -> [String: [Self]] {
        var index: [String: [Self]] = [:]
        for region in [formerGwangju, formerJeonnam] + catalog {
            for alias in region.aliases where !alias.isEmpty {
                index[alias, default: []].append(region)
            }
        }
        // Incheon's July 2026 reorganization split old districts. Offer their successors
        // by name and resolve the chosen district separately.
        let incheonSuccessors = [
            "중구": ["제물포구", "영종구"], "동구": ["제물포구"], "서구": ["서해구", "검단구"]
        ]
        for (former, successors) in incheonSuccessors {
            let entries = successors.compactMap { district in
                catalog.first { $0.province == "인천광역시" && $0.district == district && $0.locality.isEmpty }
            }
            for prefix in ["인천", "인천광역시"] {
                index[key(prefix + former)] = entries
            }
        }
        return index
    }

    static func matches(_ query: String) -> [Self] {
        index[key(query)] ?? []
    }

    func validates(_ item: MKMapItem, query: String) -> Bool {
        let expected = Self.key(query)
        guard !expected.isEmpty else { return false }
        let address = item.address?.fullAddress ?? item.displayAddress ?? ""
        let verifiedAddress = Self.key(address).replacingOccurrences(of: "^대한민국", with: "", options: .regularExpression)
        return verifiedAddress == expected
    }
}

@MainActor
final class AdministrativeRegionSearch {
    private var operation: MKLocalSearch?

    func cancel() {
        operation?.cancel()
        operation = nil
    }

    func resolve(_ region: AdministrativeRegion) async throws -> TripRegionLocation? {
        if region.isIntegratedProvince {
            guard let gwangju = try await resolve(.formerGwangju),
                  let jeonnam = try await resolve(.formerJeonnam),
                  gwangju.latitudeDelta ?? 0 > 0, gwangju.longitudeDelta ?? 0 > 0,
                  jeonnam.latitudeDelta ?? 0 > 0, jeonnam.longitudeDelta ?? 0 > 0 else { return nil }
            return .union(gwangju, jeonnam)
        }

        for query in region.mapQueries {
            do {
                let response = try await lookup(query)
                if let item = response.mapItems.first(where: { region.validates($0, query: query) }) {
                    return TripRegionLocation(item: item, bounds: response.mapItems.count == 1 ? response.boundingRegion : nil)
                }
            } catch let error as NSError where error.domain == MKErrorDomain
                && error.code == MKError.Code.placemarkNotFound.rawValue {
                continue
            }
        }
        return nil
    }

    func lookup(_ query: String) async throws -> MKLocalSearch.Response {
        try Task.checkCancellation()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        let search = MKLocalSearch(request: request)
        operation = search
        defer { if operation === search { operation = nil } }
        let result: Result<MKLocalSearch.Response, Error>
        do {
            result = .success(try await search.start())
        } catch {
            result = .failure(error)
        }
        try Task.checkCancellation()
        guard operation === search else { throw CancellationError() }
        return try result.get()
    }
}

extension TripRegionLocation {
    init?(item: MKMapItem, bounds: MKCoordinateRegion?) {
        let point = item.location.coordinate
        guard CLLocationCoordinate2DIsValid(point) else { return nil }
        coordinate = PlaceCoordinate(latitude: point.latitude, longitude: point.longitude)
        sourceName = item.name
        sourceAddress = item.displayAddress
        latitudeDelta = bounds?.span.latitudeDelta
        longitudeDelta = bounds?.span.longitudeDelta
        boundsCenter = bounds.map { PlaceCoordinate(latitude: $0.center.latitude, longitude: $0.center.longitude) }
    }

    var mapRegion: MKCoordinateRegion {
        let center = boundsCenter ?? coordinate
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
            span: MKCoordinateSpan(latitudeDelta: max(latitudeDelta ?? 0, 0.01),
                                   longitudeDelta: max(longitudeDelta ?? 0, 0.01))
        )
    }

    static func union(_ first: Self, _ second: Self) -> Self {
        let a = first.mapRegion
        let b = second.mapRegion
        let south = min(a.center.latitude - a.span.latitudeDelta / 2, b.center.latitude - b.span.latitudeDelta / 2)
        let north = max(a.center.latitude + a.span.latitudeDelta / 2, b.center.latitude + b.span.latitudeDelta / 2)
        let west = min(a.center.longitude - a.span.longitudeDelta / 2, b.center.longitude - b.span.longitudeDelta / 2)
        let east = max(a.center.longitude + a.span.longitudeDelta / 2, b.center.longitude + b.span.longitudeDelta / 2)
        let center = PlaceCoordinate(latitude: (north + south) / 2, longitude: (east + west) / 2)
        return Self(coordinate: center, sourceName: [first.sourceName, second.sourceName].compactMap { $0 }.joined(separator: " / "),
                    sourceAddress: nil, latitudeDelta: north - south, longitudeDelta: east - west, boundsCenter: center)
    }
}
