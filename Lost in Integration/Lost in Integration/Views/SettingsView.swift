//
//  SettingsView.swift
//  Lost in Integration
//
//  Default capture configuration, shared with RecordingView via @AppStorage.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(CaptureDefaults.targetRateHz) private var targetRateHz = 100.0
    @AppStorage(CaptureDefaults.recordAccel) private var recordAccel = true
    @AppStorage(CaptureDefaults.recordGyro) private var recordGyro = true
    @AppStorage(CaptureDefaults.recordMagnetometer) private var recordMagnetometer = true
    @AppStorage(CaptureDefaults.recordDeviceMotion) private var recordDeviceMotion = true

    var body: some View {
        List {
            Section {
                Toggle("Accelerometer (raw)", isOn: $recordAccel)
                Toggle("Gyroscope (raw)", isOn: $recordGyro)
                Toggle("Magnetometer (raw)", isOn: $recordMagnetometer)
                Toggle("Device motion (fused)", isOn: $recordDeviceMotion)
            } header: {
                Text("Default streams")
            } footer: {
                Text("Raw streams keep the sensors' own samples; device motion is Core Motion's fused output (attitude, gravity, userAcceleration).")
            }

            Section {
                HStack {
                    Text("Target rate")
                    Spacer()
                    Text("\(Int(targetRateHz)) Hz").foregroundStyle(.secondary).monospacedDigit()
                }
                Slider(value: $targetRateHz, in: 10...100, step: 10)
            } footer: {
                Text("Raw sensors on iPhone deliver up to ~100 Hz via Core Motion. The effective rate per session is shown in its detail view.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
