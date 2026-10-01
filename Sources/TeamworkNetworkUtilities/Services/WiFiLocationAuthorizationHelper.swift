import Foundation
import CoreLocation
import AppKit

@Observable
public final class WiFiLocationAuthorizationHelper: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    public static let shared = WiFiLocationAuthorizationHelper()
    
    private let locationManager = CLLocationManager()
    public private(set) var status: CLAuthorizationStatus = .notDetermined
    
    public override init() {
        super.init()
        self.status = locationManager.authorizationStatus
        locationManager.delegate = self
    }
    
    public var isAuthorized: Bool {
        status == .authorizedAlways
    }
    
    public func requestAuthorizationIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.status = self.locationManager.authorizationStatus
            if self.status == .notDetermined {
                self.locationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        DispatchQueue.main.async {
            self.status = newStatus
            if newStatus == .authorizedAlways {
                WiFiScannerService.shared.scanNearbyNetworks()
            }
        }
    }
}
