//
//  SessionModels.swift
//  Lost in Integration
//
//  Value types shared across the capture layer plus the on-disk layout helper.
//

import Foundation

/// Capture configuration captured at the moment a session starts.
nonisolated struct SessionConfig: Codable, Sendable, Equatable {
    var targetRateHz: Double = 100
    var recordAccel: Bool = true
    var recordGyro: Bool = true
    var recordMagnetometer: Bool = true
    var recordDeviceMotion: Bool = true
}

/// `@AppStorage` keys for the default capture configuration.
nonisolated enum CaptureDefaults {
    static let targetRateHz = "targetRateHz"
    static let recordAccel = "recordAccel"
    static let recordGyro = "recordGyro"
    static let recordMagnetometer = "recordMagnetometer"
    static let recordDeviceMotion = "recordDeviceMotion"
}

/// Live counters surfaced to the recording UI.
nonisolated struct LiveCounts: Sendable, Equatable {
    var accel = 0
    var gyro = 0
    var mag = 0
    var deviceMotion = 0
    var location = 0
}

/// One entry in the session manifest describing a written stream file.
nonisolated struct StreamMeta: Codable, Sendable {
    var file: String
    var count: Int
    var columns: [String]
    var units: String
}

/// The `meta.json` manifest written next to the CSV/GPX files.
nonisolated struct SessionManifest: Codable, Sendable {
    var id: String
    var name: String
    var startedAt: Date
    var endedAt: Date?
    var targetRateHz: Double
    /// Unix epoch seconds for boot instant. `t_utc = bootWallClockEpoch + t_mono`.
    var bootWallClockEpoch: Double
    var timeReference: String
    var streams: [StreamMeta]
}

/// On-disk layout: `<Documents>/Sessions/<uuid>/…`.
nonisolated enum SessionStore {
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var sessionsURL: URL {
        documentsURL.appendingPathComponent("Sessions", isDirectory: true)
    }

    static func directory(for id: UUID) -> URL {
        sessionsURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func relativeDir(for id: UUID) -> String {
        "Sessions/\(id.uuidString)"
    }

    /// Resolve a session's absolute directory from its stored relative path.
    static func url(forRelativeDir relative: String) -> URL {
        documentsURL.appendingPathComponent(relative, isDirectory: true)
    }
}
