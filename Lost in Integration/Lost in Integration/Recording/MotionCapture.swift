//
//  MotionCapture.swift
//  Lost in Integration
//
//  Drives one CMMotionManager for the raw sensor streams (accelerometer,
//  gyroscope, magnetometer) and CoreMotion's fused device-motion stream. Each
//  update is formatted and appended to its SampleWriter on a private queue, so
//  callbacks never touch the main thread.
//
//  Every row carries two timestamps:
//    t_mono  — CMLogItem.timestamp, seconds since boot (monotonic, precise)
//    t_utc   — bootEpoch + t_mono, Unix epoch seconds (alignable across streams)
//

import Foundation
import CoreMotion

nonisolated final class MotionCapture: @unchecked Sendable {
    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "motion-capture"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInitiated
        return q
    }()

    static let accelHeader = "t_mono,t_utc,ax,ay,az"
    static let gyroHeader = "t_mono,t_utc,gx,gy,gz"
    static let magHeader = "t_mono,t_utc,mx,my,mz"
    static let deviceMotionHeader =
        "t_mono,t_utc,qw,qx,qy,qz,roll,pitch,yaw,gravX,gravY,gravZ," +
        "userAccX,userAccY,userAccZ,rotX,rotY,rotZ,magX,magY,magZ,magAccuracy"

    /// Start whichever streams have a non-nil writer.
    func start(
        config: SessionConfig,
        bootEpoch: Double,
        accel: SampleWriter?,
        gyro: SampleWriter?,
        mag: SampleWriter?,
        deviceMotion: SampleWriter?
    ) {
        let interval = 1.0 / config.targetRateHz

        if let accel, manager.isAccelerometerAvailable {
            manager.accelerometerUpdateInterval = interval
            manager.startAccelerometerUpdates(to: queue) { data, _ in
                guard let d = data else { return }
                let t = d.timestamp
                let a = d.acceleration
                accel.append("\(f(t)),\(f(bootEpoch + t)),\(f(a.x)),\(f(a.y)),\(f(a.z))")
            }
        }

        if let gyro, manager.isGyroAvailable {
            manager.gyroUpdateInterval = interval
            manager.startGyroUpdates(to: queue) { data, _ in
                guard let d = data else { return }
                let t = d.timestamp
                let r = d.rotationRate
                gyro.append("\(f(t)),\(f(bootEpoch + t)),\(f(r.x)),\(f(r.y)),\(f(r.z))")
            }
        }

        if let mag, manager.isMagnetometerAvailable {
            manager.magnetometerUpdateInterval = interval
            manager.startMagnetometerUpdates(to: queue) { data, _ in
                guard let d = data else { return }
                let t = d.timestamp
                let m = d.magneticField
                mag.append("\(f(t)),\(f(bootEpoch + t)),\(f(m.x)),\(f(m.y)),\(f(m.z))")
            }
        }

        if let deviceMotion, manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { data, _ in
                guard let d = data else { return }
                let t = d.timestamp
                let q = d.attitude.quaternion
                let a = d.attitude
                let g = d.gravity
                let u = d.userAcceleration
                let r = d.rotationRate
                let mf = d.magneticField
                let row = [
                    f(t), f(bootEpoch + t),
                    f(q.w), f(q.x), f(q.y), f(q.z),
                    f(a.roll), f(a.pitch), f(a.yaw),
                    f(g.x), f(g.y), f(g.z),
                    f(u.x), f(u.y), f(u.z),
                    f(r.x), f(r.y), f(r.z),
                    f(mf.field.x), f(mf.field.y), f(mf.field.z),
                    "\(mf.accuracy.rawValue)"
                ].joined(separator: ",")
                deviceMotion.append(row)
            }
        }
    }

    func stop() {
        manager.stopAccelerometerUpdates()
        manager.stopGyroUpdates()
        manager.stopMagnetometerUpdates()
        manager.stopDeviceMotionUpdates()
    }
}

/// Compact, locale-independent decimal formatting (always '.' separator).
private func f(_ value: Double) -> String {
    String(format: "%.6f", value)
}
