import Foundation

final class FFmpegMergeEngine {

    enum MergeError: Error, LocalizedError {
        case noInputFiles
        case concatFailed(String)

        var errorDescription: String? {
            switch self {
            case .noInputFiles:
                return "No input files provided for merging."
            case .concatFailed(let reason):
                return "Video merge failed: \(reason)"
            }
        }
    }

    private let wrapper = FFmpegWrapper.shared

    /// Merge multiple video files into a single output using FFmpeg concat demuxer.
    /// First attempts stream copy (fast, lossless). If that fails, falls back to re-encoding.
    func merge(
        inputs: [URL],
        outputExtension: String,
        progressFilePath: String? = nil
    ) async throws -> URL {
        guard !inputs.isEmpty else { throw MergeError.noInputFiles }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Write concat list file
        let listURL = tempDir.appendingPathComponent("concat_\(UUID().uuidString.prefix(8)).txt")
        let listContent = inputs.map { "file '\($0.path)'" }.joined(separator: "\n")
        try listContent.write(to: listURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: listURL) }

        let outputName = "merged_\(UUID().uuidString.prefix(8)).\(outputExtension)"
        let outputURL = tempDir.appendingPathComponent(outputName)
        try? FileManager.default.removeItem(at: outputURL)

        // Attempt 1: stream copy (fast)
        do {
            var args = ["ffmpeg", "-y"]
            if let progressPath = progressFilePath {
                args += ["-progress", progressPath]
            }
            args += [
                "-f", "concat",
                "-safe", "0",
                "-i", listURL.path,
                "-c", "copy",
                outputURL.path
            ]
            try await wrapper.execute(args)
            return outputURL
        } catch {
            // Stream copy failed — likely different codecs/resolutions
            try? FileManager.default.removeItem(at: outputURL)
        }

        // Attempt 2: re-encode with consistent settings
        var args = ["ffmpeg", "-y"]
        if let progressPath = progressFilePath {
            args += ["-progress", progressPath]
        }
        args += [
            "-f", "concat",
            "-safe", "0",
            "-i", listURL.path,
            "-c:v", "mpeg4",
            "-c:a", "aac",
            "-b:a", "128k",
            outputURL.path
        ]
        try await wrapper.execute(args)

        return outputURL
    }
}
