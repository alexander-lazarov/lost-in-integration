//
//  SessionDetailView.swift
//  Lost in Integration
//
//  On-device analysis for one session: the GPS track on a map, plus per-stream
//  charts (decimated) with effective sample rate, largest time gap, and basic
//  per-axis statistics. Data is parsed off the main actor.
//

import SwiftUI
import Charts
import MapKit

struct SessionDetailView: View {
    let session: RecordingSession

    @State private var phase: Phase = .loading
    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    enum Phase {
        case loading
        case loaded(streams: [LoadedStream], track: [CLLocationCoordinate2D])
        case failed(String)
    }

    var body: some View {
        List {
            overviewSection

            switch phase {
            case .loading:
                Section { HStack { ProgressView(); Text("Analyzing…").foregroundStyle(.secondary) } }
            case .failed(let message):
                Section { Text(message).foregroundStyle(.secondary) }
            case .loaded(let streams, let track):
                if !track.isEmpty { mapSection(track) }
                ForEach(streams, id: \.file) { stream in
                    streamSection(stream)
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { export() } label: { Image(systemName: "square.and.arrow.up") }
            }
        }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url) }
        .alert("Export failed",
               isPresented: .constant(exportError != nil),
               actions: { Button("OK") { exportError = nil } },
               message: { Text(exportError ?? "") })
        .task(id: session.id) { await load() }
    }

    // MARK: Sections

    private var overviewSection: some View {
        Section("Overview") {
            LabeledContent("Started", value: session.startedAt.formatted())
            LabeledContent("Duration", value: String(format: "%.0f s", session.duration))
            LabeledContent("Target rate", value: "\(Int(session.targetRateHz)) Hz")
        }
    }

    private func mapSection(_ track: [CLLocationCoordinate2D]) -> some View {
        Section("GPS track (\(track.count) fixes)") {
            Map(initialPosition: .automatic) {
                MapPolyline(coordinates: track)
                    .stroke(.blue, lineWidth: 3)
                if let first = track.first {
                    Marker("Start", systemImage: "flag", coordinate: first).tint(.green)
                }
                if let last = track.last {
                    Marker("End", systemImage: "flag.checkered", coordinate: last).tint(.red)
                }
            }
            .frame(height: 260)
            .listRowInsets(EdgeInsets())
        }
    }

    private func streamSection(_ stream: LoadedStream) -> some View {
        Section(title(for: stream.file)) {
            if !stream.chartPoints.isEmpty {
                Chart(stream.chartPoints) { point in
                    LineMark(
                        x: .value("t (s)", point.t),
                        y: .value("value", point.value)
                    )
                    .foregroundStyle(by: .value("series", point.series))
                    .interpolationMethod(.linear)
                }
                .chartLegend(position: .bottom)
                .frame(height: 200)
                .padding(.vertical, 4)
            }

            LabeledContent("Samples", value: "\(stream.rowCount)")
            LabeledContent("Effective rate", value: String(format: "%.1f Hz", stream.effectiveHz))
            LabeledContent("Largest gap", value: String(format: "%.3f s", stream.maxGapSeconds))

            DisclosureGroup("Per-axis statistics") {
                ForEach(stream.stats) { stat in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.name).font(.subheadline.bold())
                        Text("min \(fmt(stat.min))   max \(fmt(stat.max))   mean \(fmt(stat.mean))   σ \(fmt(stat.std))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    // MARK: Loading

    private func load() async {
        let dir = SessionStore.url(forRelativeDir: session.relativeDir)
        let specs = streamSpecs()

        let result = await Task.detached { () -> Phase in
            var streams: [LoadedStream] = []
            for spec in specs {
                let url = dir.appendingPathComponent(spec.file)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                if let loaded = try? StreamCSV.load(url: url, chartColumns: spec.chart) {
                    streams.append(loaded)
                }
            }
            let locURL = dir.appendingPathComponent("location.csv")
            let coords: [CLLocationCoordinate2D]
            if FileManager.default.fileExists(atPath: locURL.path),
               let pairs = try? StreamCSV.loadTrack(url: locURL) {
                coords = pairs.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            } else {
                coords = []
            }
            return .loaded(streams: streams, track: coords)
        }.value

        phase = result
    }

    private struct StreamSpec { let file: String; let chart: [String] }

    private func streamSpecs() -> [StreamSpec] {
        var specs: [StreamSpec] = []
        if session.recordAccel { specs.append(.init(file: "accel_raw.csv", chart: ["ax", "ay", "az"])) }
        if session.recordGyro { specs.append(.init(file: "gyro_raw.csv", chart: ["gx", "gy", "gz"])) }
        if session.recordMagnetometer { specs.append(.init(file: "mag_raw.csv", chart: ["mx", "my", "mz"])) }
        if session.recordDeviceMotion {
            // userAcceleration is the fused, gravity-removed signal — the one
            // you'd integrate for dead reckoning.
            specs.append(.init(file: "devicemotion.csv", chart: ["userAccX", "userAccY", "userAccZ"]))
        }
        return specs
    }

    private func title(for file: String) -> String {
        switch file {
        case "accel_raw.csv": "Accelerometer (raw, g)"
        case "gyro_raw.csv": "Gyroscope (raw, rad/s)"
        case "mag_raw.csv": "Magnetometer (raw, µT)"
        case "devicemotion.csv": "Device motion — userAcceleration (fused, g)"
        default: file
        }
    }

    private func fmt(_ v: Double) -> String { String(format: "%.4g", v) }

    private func export() {
        let dir = SessionStore.url(forRelativeDir: session.relativeDir)
        do {
            shareItem = ShareItem(url: try SessionExporter.makeZip(sessionDir: dir, suggestedName: session.name))
        } catch {
            exportError = error.localizedDescription
        }
    }
}
