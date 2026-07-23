//
//  SessionExporter.swift
//  Lost in Integration
//
//  Zips a session folder into a single .zip using NSFileCoordinator's
//  `.forUploading` option — no third-party dependency. The coordinated zip is
//  temporary and only valid inside the accessor block, so we copy it to a
//  stable temp location the share sheet can hand off.
//

import Foundation

nonisolated enum SessionExporter {
    enum ExportError: LocalizedError {
        case missingDirectory
        case zipFailed

        var errorDescription: String? {
            switch self {
            case .missingDirectory: "The session files could not be found on disk."
            case .zipFailed: "The session could not be packaged for export."
            }
        }
    }

    /// Produce a `.zip` of the session directory and return its URL.
    static func makeZip(sessionDir: URL, suggestedName: String) throws -> URL {
        guard FileManager.default.fileExists(atPath: sessionDir.path) else {
            throw ExportError.missingDirectory
        }

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: URL?
        var copyError: Error?

        coordinator.coordinate(readingItemAt: sessionDir,
                               options: [.forUploading],
                               error: &coordinationError) { zippedURL in
            let safeName = sanitize(suggestedName)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(safeName).zip")
            do {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: zippedURL, to: dest)
                result = dest
            } catch {
                copyError = error
            }
        }

        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
        guard let result else { throw ExportError.zipFailed }
        return result
    }

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = String(name.unicodeScalars.filter { allowed.contains($0) })
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "session" : cleaned
    }
}
