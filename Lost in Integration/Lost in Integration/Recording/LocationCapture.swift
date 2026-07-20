//
//  LocationCapture.swift
//  Lost in Integration
//
//  Drives CLLocationManager for the GPS track. Feeds both the full-fidelity
//  location.csv (speed, course, accuracies) and the GPXWriter. Configured for
//  background updates so a session survives locking the screen.
//

import Foundation
import CoreLocation

@MainActor
final class LocationCapture: NSObject, CLLocationManagerDelegate {
    static let header =
        "t_utc,lat,lon,alt,hAcc,vAcc,speed,speedAcc,course,courseAcc"

    private let manager = CLLocationManager()
    private var writer: SampleWriter?
    private var gpx: GPXWriter?
    private(set) var authorizationStatus: CLAuthorizationStatus

    /// Surfaced to the UI so it can warn if the user denied location access.
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
    }

    func start(writer: SampleWriter, gpx: GPXWriter) {
        self.writer = writer
        self.gpx = gpx
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        // Requires "location" in UIBackgroundModes; keeps the process alive
        // (and therefore CMMotionManager delivering) while backgrounded.
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        writer = nil
        gpx = nil
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            gpx?.add(loc)
            let row = [
                fmt(loc.timestamp.timeIntervalSince1970),
                fmt(loc.coordinate.latitude, 7),
                fmt(loc.coordinate.longitude, 7),
                fmt(loc.altitude, 3),
                fmt(loc.horizontalAccuracy, 3),
                fmt(loc.verticalAccuracy, 3),
                fmt(loc.speed, 3),
                fmt(loc.speedAccuracy, 3),
                fmt(loc.course, 3),
                fmt(loc.courseAccuracy, 3)
            ].joined(separator: ",")
            writer?.append(row)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        onAuthorizationChange?(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient errors (e.g. no fix yet) are expected; recording continues.
    }

    private func fmt(_ value: Double, _ decimals: Int = 6) -> String {
        String(format: "%.\(decimals)f", value)
    }
}
