//
//  StreamCSV.swift
//  Lost in Integration
//
//  Reads a recorded stream CSV back for on-device analysis: computes per-column
//  stats (Welford), effective sample rate and largest time gap, and a decimated
//  series capped at `maxPoints` for charting. Runs off the main actor.
//

import Foundation

nonisolated struct ColumnStats: Sendable, Identifiable {
    var id: String { name }
    var name: String
    var count: Int
    var min: Double
    var max: Double
    var mean: Double
    var std: Double
}

nonisolated struct ChartPoint: Sendable, Identifiable {
    var id: Int
    var series: String
    var t: Double      // seconds relative to first sample
    var value: Double
}

nonisolated struct LoadedStream: Sendable {
    var file: String
    var valueColumns: [String]
    var rowCount: Int
    var durationSeconds: Double
    var effectiveHz: Double
    var maxGapSeconds: Double
    var stats: [ColumnStats]
    var chartPoints: [ChartPoint]        // decimated, only for `chartedColumns`
    var chartedColumns: [String]
}

nonisolated enum StreamCSV {
    /// Load and analyze a stream file. `chartColumns` picks which value columns
    /// are decimated into `chartPoints` (nil = all value columns).
    static func load(url: URL, chartColumns: [String]? = nil, maxPoints: Int = 1500) throws -> LoadedStream {
        let content = try String(contentsOf: url, encoding: .utf8)
        var lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else {
            return LoadedStream(file: url.lastPathComponent, valueColumns: [], rowCount: 0,
                                durationSeconds: 0, effectiveHz: 0, maxGapSeconds: 0,
                                stats: [], chartPoints: [], chartedColumns: [])
        }

        let header = lines.removeFirst().split(separator: ",").map(String.init)
        let timeIndex = header.firstIndex(of: "t_utc") ?? header.firstIndex(of: "t_mono") ?? 0
        let valueIndices = header.indices.filter { $0 != header.firstIndex(of: "t_utc")
            && $0 != header.firstIndex(of: "t_mono") }
        let valueNames = valueIndices.map { header[$0] }

        // Welford accumulators per value column.
        var n = [Int](repeating: 0, count: valueIndices.count)
        var mean = [Double](repeating: 0, count: valueIndices.count)
        var m2 = [Double](repeating: 0, count: valueIndices.count)
        var mins = [Double](repeating: .greatestFiniteMagnitude, count: valueIndices.count)
        var maxs = [Double](repeating: -.greatestFiniteMagnitude, count: valueIndices.count)

        let rowCount = lines.count
        let stride = Swift.max(1, rowCount / maxPoints)

        let chartSet = Set(chartColumns ?? valueNames)
        let chartedCols = valueNames.filter { chartSet.contains($0) }
        var chartPoints: [ChartPoint] = []
        chartPoints.reserveCapacity((rowCount / stride + 1) * chartedCols.count)

        var tFirst: Double?
        var tPrev: Double?
        var tLast: Double = 0
        var maxGap: Double = 0
        var pointID = 0

        for (row, line) in lines.enumerated() {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count == header.count else { continue }

            let t = Double(fields[timeIndex]) ?? 0
            if tFirst == nil { tFirst = t }
            if let p = tPrev { maxGap = Swift.max(maxGap, t - p) }
            tPrev = t
            tLast = t

            let sampleThisRow = (row % stride == 0)
            for (i, colIndex) in valueIndices.enumerated() {
                guard let v = Double(fields[colIndex]) else { continue }
                n[i] += 1
                let delta = v - mean[i]
                mean[i] += delta / Double(n[i])
                m2[i] += delta * (v - mean[i])
                if v < mins[i] { mins[i] = v }
                if v > maxs[i] { maxs[i] = v }

                if sampleThisRow, chartSet.contains(valueNames[i]) {
                    chartPoints.append(ChartPoint(id: pointID, series: valueNames[i],
                                                  t: t - (tFirst ?? t), value: v))
                    pointID += 1
                }
            }
        }

        let duration = (tFirst != nil) ? (tLast - tFirst!) : 0
        let effectiveHz = duration > 0 ? Double(rowCount) / duration : 0

        var stats: [ColumnStats] = []
        for i in valueIndices.indices {
            let std = n[i] > 1 ? (m2[i] / Double(n[i] - 1)).squareRoot() : 0
            stats.append(ColumnStats(
                name: valueNames[i],
                count: n[i],
                min: n[i] > 0 ? mins[i] : 0,
                max: n[i] > 0 ? maxs[i] : 0,
                mean: mean[i],
                std: std
            ))
        }

        return LoadedStream(
            file: url.lastPathComponent,
            valueColumns: valueNames,
            rowCount: rowCount,
            durationSeconds: duration,
            effectiveHz: effectiveHz,
            maxGapSeconds: maxGap,
            stats: stats,
            chartPoints: chartPoints,
            chartedColumns: chartedCols
        )
    }

    /// Read lat/lon pairs from location.csv for map display.
    static func loadTrack(url: URL) throws -> [(lat: Double, lon: Double)] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else { return [] }
        let header = lines.removeFirst().split(separator: ",").map(String.init)
        guard let latI = header.firstIndex(of: "lat"),
              let lonI = header.firstIndex(of: "lon") else { return [] }

        var out: [(Double, Double)] = []
        out.reserveCapacity(lines.count)
        for line in lines {
            let f = line.split(separator: ",", omittingEmptySubsequences: false)
            guard f.count == header.count,
                  let lat = Double(f[latI]), let lon = Double(f[lonI]) else { continue }
            out.append((lat, lon))
        }
        return out
    }
}
