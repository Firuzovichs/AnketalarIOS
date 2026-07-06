import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location:    CLLocation?               = nil
    @Published var authStatus:  CLAuthorizationStatus     = .notDetermined
    @Published var isLoading:   Bool                      = false
    @Published var denied:      Bool                      = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate         = self
        manager.desiredAccuracy  = kCLLocationAccuracyHundredMeters
        authStatus               = manager.authorizationStatus
    }

    func requestLocation() {
        denied   = false
        isLoading = true
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLoading = false
            denied    = true
        @unknown default:
            isLoading = false
        }
    }

    // MARK: - Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location  = locations.first
        isLoading = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            manager.requestLocation()
        } else if authStatus == .denied || authStatus == .restricted {
            isLoading = false
            denied    = true
        }
    }
}
