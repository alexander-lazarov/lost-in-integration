//
//  RecordingSession.swift
//  Lost in Integration
//
//  Index/metadata record for one recording session. The dense sample data
//  itself lives in per-stream CSV files on disk (see `relativeDir`); SwiftData
//  only holds this lightweight index so the session list stays fast.
//

import Foundation
import SwiftData

@Model
final class RecordingSession {
    /// Stable identifier; also the on-disk folder name under `Sessions/`.
    @Attribute(.unique) var id: UUID
    var name: String
    var startedAt: Date
    var endedAt: Date?

    /// Path relative to the app's Documents directory, e.g. `Sessions/<uuid>`.
    var relativeDir: String

    // MARK: Capture configuration (snapshot of settings at record time)

    var targetRateHz: Double
    var recordAccel: Bool
    var recordGyro: Bool
    var recordMagnetometer: Bool
    var recordDeviceMotion: Bool

    // MARK: Clock mapping (monotonic sensor time -> wall clock)

    /// `Date() - ProcessInfo.systemUptime` captured at session start. Adding a
    /// CoreMotion `t_mono` (seconds since boot) to this yields wall-clock UTC.
    var bootWallClock: Date

    // MARK: Running sample counts (updated live, finalized on stop)

    var accelCount: Int
    var gyroCount: Int
    var magCount: Int
    var deviceMotionCount: Int
    var locationCount: Int

    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        startedAt: Date,
        relativeDir: String,
        targetRateHz: Double,
        recordAccel: Bool,
        recordGyro: Bool,
        recordMagnetometer: Bool,
        recordDeviceMotion: Bool,
        bootWallClock: Date,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.endedAt = nil
        self.relativeDir = relativeDir
        self.targetRateHz = targetRateHz
        self.recordAccel = recordAccel
        self.recordGyro = recordGyro
        self.recordMagnetometer = recordMagnetometer
        self.recordDeviceMotion = recordDeviceMotion
        self.bootWallClock = bootWallClock
        self.accelCount = 0
        self.gyroCount = 0
        self.magCount = 0
        self.deviceMotionCount = 0
        self.locationCount = 0
        self.notes = notes
    }

    /// Session duration in seconds (uses `endedAt` if finalized, else now).
    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var isFinalized: Bool { endedAt != nil }
}
