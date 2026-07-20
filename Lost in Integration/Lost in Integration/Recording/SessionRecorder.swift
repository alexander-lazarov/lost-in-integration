//
//  SessionRecorder.swift
//  Lost in Integration
//
//  Orchestrates one recording session: creates the on-disk folder + per-stream
//  writers, starts motion & location capture, and on stop flushes everything,
//  finalizes the GPX track, writes meta.json, and updates the SwiftData index.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SessionRecorder {
    private(set) var isRecording = false
    private(set) var startedAt: Date?
    private(set) var lastError: String?

    private let motion = MotionCapture()
    private let location = LocationCapture()

    private var config = SessionConfig()
    private var directory: URL?
    private var session: RecordingSession?
    private var modelContext: ModelContext?
    private var bootWallClock = Date()

    private var accelWriter: SampleWriter?
    private var gyroWriter: SampleWriter?
    private var magWriter: SampleWriter?
    private var deviceMotionWriter: SampleWriter?
    private var locationWriter: SampleWriter?
    private var gpx: GPXWriter?

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    /// Live counts read from the writers (cheap enough to poll ~1 Hz from UI).
    var liveCounts: LiveCounts {
        LiveCounts(
            accel: accelWriter?.count ?? 0,
            gyro: gyroWriter?.count ?? 0,
            mag: magWriter?.count ?? 0,
            deviceMotion: deviceMotionWriter?.count ?? 0,
            location: locationWriter?.count ?? 0
        )
    }

    func clearError() {
        lastError = nil
    }

    func start(config: SessionConfig, name: String, context: ModelContext) {
        guard !isRecording else { return }
        lastError = nil
        do {
            let id = UUID()
            let dir = SessionStore.directory(for: id)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            bootWallClock = Date().addingTimeInterval(-ProcessInfo.processInfo.systemUptime)
            let bootEpoch = bootWallClock.timeIntervalSince1970

            if config.recordAccel {
                accelWriter = try SampleWriter(url: dir.appendingPathComponent("accel_raw.csv"),
                                               header: MotionCapture.accelHeader)
            }
            if config.recordGyro {
                gyroWriter = try SampleWriter(url: dir.appendingPathComponent("gyro_raw.csv"),
                                              header: MotionCapture.gyroHeader)
            }
            if config.recordMagnetometer {
                magWriter = try SampleWriter(url: dir.appendingPathComponent("mag_raw.csv"),
                                             header: MotionCapture.magHeader)
            }
            if config.recordDeviceMotion {
                deviceMotionWriter = try SampleWriter(url: dir.appendingPathComponent("devicemotion.csv"),
                                                      header: MotionCapture.deviceMotionHeader)
            }
            locationWriter = try SampleWriter(url: dir.appendingPathComponent("location.csv"),
                                              header: LocationCapture.header)
            let gpxWriter = GPXWriter(trackName: name)

            motion.start(config: config, bootEpoch: bootEpoch,
                         accel: accelWriter, gyro: gyroWriter,
                         mag: magWriter, deviceMotion: deviceMotionWriter)
            location.start(writer: locationWriter!, gpx: gpxWriter)

            let model = RecordingSession(
                id: id,
                name: name,
                startedAt: Date(),
                relativeDir: SessionStore.relativeDir(for: id),
                targetRateHz: config.targetRateHz,
                recordAccel: config.recordAccel,
                recordGyro: config.recordGyro,
                recordMagnetometer: config.recordMagnetometer,
                recordDeviceMotion: config.recordDeviceMotion,
                bootWallClock: bootWallClock
            )
            context.insert(model)
            try context.save()

            self.config = config
            self.directory = dir
            self.session = model
            self.modelContext = context
            self.gpx = gpxWriter
            self.startedAt = model.startedAt
            self.isRecording = true
        } catch {
            lastError = "Could not start recording: \(error.localizedDescription)"
            cleanupWriters()
        }
    }

    func stop() {
        guard isRecording else { return }
        motion.stop()
        location.stop()

        accelWriter?.close()
        gyroWriter?.close()
        magWriter?.close()
        deviceMotionWriter?.close()
        locationWriter?.close()

        let counts = liveCounts

        if let dir = directory {
            try? gpx?.write(to: dir.appendingPathComponent("track.gpx"))
            writeManifest(to: dir, counts: counts)
        }

        if let session {
            session.endedAt = Date()
            session.accelCount = counts.accel
            session.gyroCount = counts.gyro
            session.magCount = counts.mag
            session.deviceMotionCount = counts.deviceMotion
            session.locationCount = counts.location
            try? modelContext?.save()
        }

        isRecording = false
        startedAt = nil
        cleanupWriters()
    }

    private func writeManifest(to dir: URL, counts: LiveCounts) {
        guard let session else { return }
        var streams: [StreamMeta] = []
        if config.recordAccel {
            streams.append(.init(file: "accel_raw.csv", count: counts.accel,
                                 columns: MotionCapture.accelHeader.components(separatedBy: ","),
                                 units: "acceleration in g (t in seconds / unix epoch)"))
        }
        if config.recordGyro {
            streams.append(.init(file: "gyro_raw.csv", count: counts.gyro,
                                 columns: MotionCapture.gyroHeader.components(separatedBy: ","),
                                 units: "rotation rate in rad/s"))
        }
        if config.recordMagnetometer {
            streams.append(.init(file: "mag_raw.csv", count: counts.mag,
                                 columns: MotionCapture.magHeader.components(separatedBy: ","),
                                 units: "magnetic field in microtesla (uncalibrated)"))
        }
        if config.recordDeviceMotion {
            streams.append(.init(file: "devicemotion.csv", count: counts.deviceMotion,
                                 columns: MotionCapture.deviceMotionHeader.components(separatedBy: ","),
                                 units: "fused: quaternion, euler (rad), gravity & userAcc in g, rot in rad/s, mag in uT"))
        }
        streams.append(.init(file: "location.csv", count: counts.location,
                             columns: LocationCapture.header.components(separatedBy: ","),
                             units: "deg, meters, m/s, degrees; accuracies in same unit (<0 = invalid)"))

        let manifest = SessionManifest(
            id: session.id.uuidString,
            name: session.name,
            startedAt: session.startedAt,
            endedAt: Date(),
            targetRateHz: config.targetRateHz,
            bootWallClockEpoch: bootWallClock.timeIntervalSince1970,
            timeReference: "t_mono = seconds since device boot; t_utc = bootWallClockEpoch + t_mono (unix epoch seconds)",
            streams: streams
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(manifest) {
            try? data.write(to: dir.appendingPathComponent("meta.json"))
        }
    }

    private func cleanupWriters() {
        accelWriter = nil
        gyroWriter = nil
        magWriter = nil
        deviceMotionWriter = nil
        locationWriter = nil
        gpx = nil
        directory = nil
        session = nil
    }
}
