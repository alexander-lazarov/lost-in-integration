//
//  RecordingView.swift
//  Lost in Integration
//
//  Start/stop a recording session with live feedback: elapsed time, per-stream
//  sample counts and effective sample rate, and the latest GPS status.
//

import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recorder = SessionRecorder()
    @State private var sessionName = ""

    @AppStorage(CaptureDefaults.targetRateHz) private var targetRateHz = 100.0
    @AppStorage(CaptureDefaults.recordAccel) private var recordAccel = true
    @AppStorage(CaptureDefaults.recordGyro) private var recordGyro = true
    @AppStorage(CaptureDefaults.recordMagnetometer) private var recordMagnetometer = true
    @AppStorage(CaptureDefaults.recordDeviceMotion) private var recordDeviceMotion = true

    private var config: SessionConfig {
        SessionConfig(targetRateHz: targetRateHz,
                      recordAccel: recordAccel,
                      recordGyro: recordGyro,
                      recordMagnetometer: recordMagnetometer,
                      recordDeviceMotion: recordDeviceMotion)
    }

    var body: some View {
        VStack(spacing: 24) {
            if recorder.isRecording {
                // Re-read live state once per second while recording.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    liveStats
                }
            } else {
                idleControls
            }

            Spacer()

            recordButton
        }
        .padding()
        .navigationTitle("Record")
        .alert("Recording error",
               isPresented: .constant(recorder.lastError != nil),
               actions: { Button("OK") { recorder.clearError() } },
               message: { Text(recorder.lastError ?? "") })
    }

    private var idleControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Session name (optional)", text: $sessionName)
                .textFieldStyle(.roundedBorder)

            GroupBox("Streams") {
                Toggle("Accelerometer (raw)", isOn: $recordAccel)
                Toggle("Gyroscope (raw)", isOn: $recordGyro)
                Toggle("Magnetometer (raw)", isOn: $recordMagnetometer)
                Toggle("Device motion (fused)", isOn: $recordDeviceMotion)
            }

            GroupBox("Target rate") {
                HStack {
                    Text("\(Int(targetRateHz)) Hz")
                        .monospacedDigit()
                    Slider(value: $targetRateHz, in: 10...100, step: 10)
                }
            }

            Text("Tip: an active GPS session keeps recording alive when the screen locks.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var liveStats: some View {
        let counts = recorder.liveCounts
        let elapsed = recorder.elapsed
        return VStack(spacing: 16) {
            Text(timeString(elapsed))
                .font(.system(size: 48, weight: .semibold, design: .monospaced))

            VStack(spacing: 8) {
                if config.recordAccel { streamRow("Accel", counts.accel, elapsed) }
                if config.recordGyro { streamRow("Gyro", counts.gyro, elapsed) }
                if config.recordMagnetometer { streamRow("Mag", counts.mag, elapsed) }
                if config.recordDeviceMotion { streamRow("Fused", counts.deviceMotion, elapsed) }
                streamRow("GPS", counts.location, elapsed)
            }
            .font(.body.monospacedDigit())
        }
    }

    private func streamRow(_ label: String, _ count: Int, _ elapsed: TimeInterval) -> some View {
        let hz = elapsed > 0.5 ? Double(count) / elapsed : 0
        return HStack {
            Text(label).frame(width: 60, alignment: .leading)
            Spacer()
            Text("\(count)").frame(width: 90, alignment: .trailing)
            Text(String(format: "%.1f Hz", hz))
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
    }

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                recorder.stop()
            } else {
                let name = sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
                recorder.start(config: config,
                               name: name.isEmpty ? defaultName() : name,
                               context: modelContext)
            }
        } label: {
            Text(recorder.isRecording ? "Stop" : "Record")
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(recorder.isRecording ? Color.red : Color.accentColor,
                            in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private func defaultName() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "Session \(df.string(from: Date()))"
    }
}

#Preview {
    NavigationStack {
        RecordingView()
    }
    .modelContainer(for: RecordingSession.self, inMemory: true)
}
