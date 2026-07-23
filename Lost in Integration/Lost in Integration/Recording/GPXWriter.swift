//
//  GPXWriter.swift
//  Lost in Integration
//
//  Accumulates GPS fixes and emits a standard GPX 1.1 track. Only lat/lon/ele
//  and UTC time go into the GPX (maximally compatible with viewers); the full
//  fidelity fields (speed, course, accuracies) live in location.csv instead.
//

import Foundation
import CoreLocation

nonisolated final class GPXWriter: @unchecked Sendable {
    struct Point: Sendable {
        var latitude: Double
        var longitude: Double
        var elevation: Double
        var time: Date
    }

    private let queue = DispatchQueue(label: "gpx-writer", qos: .utility)
    private var points: [Point] = []
    private let trackName: String

    init(trackName: String) {
        self.trackName = trackName
    }

    func add(_ location: CLLocation) {
        let point = Point(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            elevation: location.altitude,
            time: location.timestamp
        )
        queue.async { self.points.append(point) }
    }

    var count: Int { queue.sync { points.count } }

    func gpxString() -> String {
        queue.sync { Self.buildGPX(trackName: trackName, points: points) }
    }

    func write(to url: URL) throws {
        try gpxString().write(to: url, atomically: true, encoding: .utf8)
    }

    /// Pure builder, exposed for testing.
    static func buildGPX(trackName: String, points: [Point]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Lost in Integration" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <name>\(xmlEscape(trackName))</name>
            <trkseg>

        """
        for p in points {
            xml += """
                  <trkpt lat="\(fixed(p.latitude, 7))" lon="\(fixed(p.longitude, 7))">
                    <ele>\(fixed(p.elevation, 3))</ele>
                    <time>\(formatter.string(from: p.time))</time>
                  </trkpt>

            """
        }
        xml += """
            </trkseg>
          </trk>
        </gpx>

        """
        return xml
    }

    /// Locale-independent fixed-decimal formatting (always '.' separator).
    static func fixed(_ value: Double, _ decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
