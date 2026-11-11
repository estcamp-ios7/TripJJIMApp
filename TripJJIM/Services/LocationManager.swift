import CoreLocation
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var currentCoordinate: PlaceCoordinate?
    private(set) var isLocating = false
    var message: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() {
        guard !isLocating else { return }
        isLocating = true
        currentCoordinate = nil
        message = nil
        handleAuthorization(manager.authorizationStatus)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLocating, manager.authorizationStatus != .notDetermined else { return }
        handleAuthorization(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLocating = false
        guard let coordinate = locations.last?.coordinate else {
            message = locationUnavailableMessage
            return
        }
        currentCoordinate = PlaceCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        message = locationUnavailableMessage
    }

    private var locationUnavailableMessage: String {
        #if targetEnvironment(simulator)
        "시뮬레이터에서 위치 좌표를 받지 못했습니다. Xcode의 Debug > Simulate Location에서 테스트 위치를 선택한 뒤 다시 시도해 주세요."
        #else
        "현재 위치를 찾지 못했습니다. 잠시 후 다시 시도해 주세요."
        #endif
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLocating = false
            message = "설정에서 TripJJIM의 위치 접근을 허용하면 내 위치를 찾을 수 있습니다. 지도에서 장소를 직접 선택할 수 있습니다."
        @unknown default:
            isLocating = false
            message = "현재 위치를 사용할 수 없습니다."
        }
    }
}
