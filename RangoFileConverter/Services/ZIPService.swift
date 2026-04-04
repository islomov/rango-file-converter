import Foundation

enum ZIPServiceError: LocalizedError {
    case noFiles
    case compressionFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noFiles: return "No files selected for compression."
        case .compressionFailed: return "Failed to compress files into ZIP archive."
        case .writeFailed: return "Failed to write the ZIP archive."
        }
    }
}

struct ZIPService {

    /// Compresses an array of file URLs into a single .zip archive using NSFileCoordinator.
    /// Returns the URL of the created .zip file in the temp directory.
    static func compress(fileURLs: [URL], archiveName: String = "archive") throws -> URL {
        guard !fileURLs.isEmpty else { throw ZIPServiceError.noFiles }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create a staging directory with the files to zip
        let shortID = UUID().uuidString.prefix(8)
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_zip_staging_\(shortID)", isDirectory: true)
        try? FileManager.default.removeItem(at: stagingDir)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        // Copy all files into the staging directory
        for fileURL in fileURLs {
            let destURL = stagingDir.appendingPathComponent(fileURL.lastPathComponent)
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.copyItem(at: fileURL, to: destURL)
        }

        // Use NSFileCoordinator to create a ZIP from the staging directory
        let coordinator = NSFileCoordinator()
        let intent = NSFileAccessIntent.readingIntent(with: stagingDir, options: .forUploading)

        var zipURL: URL?
        var coordinatorError: NSError?
        var innerError: Error?

        // coordinate(with:queue:byAccessor:) is async via queue, use semaphore to wait
        let semaphore = DispatchSemaphore(value: 0)

        coordinator.coordinate(with: [intent], queue: OperationQueue()) { error in
            if let error = error {
                coordinatorError = error as NSError
                semaphore.signal()
                return
            }

            // intent.url points to a temporary .zip file
            let sourceZIP = intent.url
            let finalURL = tempDir.appendingPathComponent("\(archiveName)_\(shortID).zip")
            try? FileManager.default.removeItem(at: finalURL)

            do {
                try FileManager.default.copyItem(at: sourceZIP, to: finalURL)
                zipURL = finalURL
            } catch {
                innerError = error
            }

            semaphore.signal()
        }

        semaphore.wait()

        // Clean up staging directory
        try? FileManager.default.removeItem(at: stagingDir)

        if let error = coordinatorError {
            throw error
        }
        if let error = innerError {
            throw error
        }
        guard let resultURL = zipURL else {
            throw ZIPServiceError.compressionFailed
        }

        return resultURL
    }
}
