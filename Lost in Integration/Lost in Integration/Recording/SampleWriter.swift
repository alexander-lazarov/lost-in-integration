//
//  SampleWriter.swift
//  Lost in Integration
//
//  Append-only, buffered CSV writer for a single sensor stream. All file I/O
//  runs on a private serial queue, so `append(_:)` is safe to call directly
//  from high-frequency CoreMotion callbacks on any queue without blocking them.
//

import Foundation

nonisolated final class SampleWriter: @unchecked Sendable {
    private let fileHandle: FileHandle
    private let queue: DispatchQueue
    private var buffer = Data()
    private let flushThreshold: Int
    private var _count = 0

    /// - Parameters:
    ///   - url: destination file (created/truncated on init).
    ///   - header: CSV header line (written immediately, without a trailing newline).
    ///   - flushThreshold: buffer size in bytes before a write to disk.
    init(url: URL, header: String, flushThreshold: Int = 16 * 1024) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        self.fileHandle = try FileHandle(forWritingTo: url)
        self.queue = DispatchQueue(label: "sample-writer.\(url.lastPathComponent)", qos: .utility)
        self.flushThreshold = flushThreshold
        if let data = (header + "\n").data(using: .utf8) {
            try fileHandle.write(contentsOf: data)
        }
    }

    /// Rows appended so far (excludes the header). Reads block on the queue.
    var count: Int { queue.sync { _count } }

    /// Enqueue one CSV row (without trailing newline). Non-blocking.
    func append(_ row: String) {
        queue.async { [self] in
            guard let data = (row + "\n").data(using: .utf8) else { return }
            buffer.append(data)
            _count += 1
            if buffer.count >= flushThreshold {
                writeBuffer()
            }
        }
    }

    /// Force any buffered rows to disk. Blocks until written.
    func flush() {
        queue.sync { writeBuffer() }
    }

    /// Flush remaining rows and close the file handle.
    func close() {
        queue.sync {
            writeBuffer()
            try? fileHandle.close()
        }
    }

    /// Must be called on `queue`.
    private func writeBuffer() {
        guard !buffer.isEmpty else { return }
        try? fileHandle.write(contentsOf: buffer)
        buffer.removeAll(keepingCapacity: true)
    }
}
