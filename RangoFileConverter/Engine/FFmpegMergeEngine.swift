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
                return "Merge failed: \(reason)"
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

        // Attempt 2: re-encode using concat filter (handles different codecs/resolutions)
        // Try with video + audio first
        do {
            try await mergeWithConcatFilter(
                inputs: inputs,
                outputURL: outputURL,
                includeAudio: true,
                progressFilePath: progressFilePath
            )
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
        }

        // Attempt 3: video-only (some inputs may lack audio streams)
        try await mergeWithConcatFilter(
            inputs: inputs,
            outputURL: outputURL,
            includeAudio: false,
            progressFilePath: progressFilePath
        )
        return outputURL
    }

    /// Re-encode and merge using the concat filter, which handles different codecs, resolutions, and stream layouts.
    private func mergeWithConcatFilter(
        inputs: [URL],
        outputURL: URL,
        includeAudio: Bool,
        progressFilePath: String?
    ) async throws {
        let n = inputs.count
        var args = ["ffmpeg", "-y"]
        if let progressPath = progressFilePath {
            args += ["-progress", progressPath]
        }
        for input in inputs {
            args += ["-i", input.path]
        }

        // Build filter: scale each video to 1280x720, then concat
        var filters: [String] = []
        for i in 0..<n {
            filters.append("[\(i):v]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1[\(i)v]")
        }
        if includeAudio {
            for i in 0..<n {
                filters.append("[\(i):a]aresample=44100[\(i)a]")
            }
            let concatInputs = (0..<n).map { "[\($0)v][\($0)a]" }.joined()
            filters.append("\(concatInputs)concat=n=\(n):v=1:a=1[outv][outa]")
            let filterComplex = filters.joined(separator: ";")
            args += [
                "-filter_complex", filterComplex,
                "-map", "[outv]", "-map", "[outa]",
                "-c:v", "mpeg4",
                "-c:a", "aac", "-b:a", "128k",
                outputURL.path
            ]
        } else {
            let concatInputs = (0..<n).map { "[\($0)v]" }.joined()
            filters.append("\(concatInputs)concat=n=\(n):v=1:a=0[outv]")
            let filterComplex = filters.joined(separator: ";")
            args += [
                "-filter_complex", filterComplex,
                "-map", "[outv]",
                "-c:v", "mpeg4",
                outputURL.path
            ]
        }

        try await wrapper.execute(args)
    }

    /// Merge multiple audio files into a single output using FFmpeg concat demuxer.
    /// First attempts stream copy (fast, lossless). If that fails, falls back to re-encoding audio only.
    func mergeAudio(
        inputs: [URL],
        outputExtension: String,
        progressFilePath: String? = nil
    ) async throws -> URL {
        guard !inputs.isEmpty else { throw MergeError.noInputFiles }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let listURL = tempDir.appendingPathComponent("concat_\(UUID().uuidString.prefix(8)).txt")
        let listContent = inputs.map { "file '\($0.path)'" }.joined(separator: "\n")
        try listContent.write(to: listURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: listURL) }

        let outputName = "merged_\(UUID().uuidString.prefix(8)).\(outputExtension)"
        let outputURL = tempDir.appendingPathComponent(outputName)
        try? FileManager.default.removeItem(at: outputURL)

        // Attempt 1: stream copy (fast — works when all inputs share the same codec)
        do {
            var args = ["ffmpeg", "-y"]
            if let progressPath = progressFilePath {
                args += ["-progress", progressPath]
            }
            args += [
                "-f", "concat",
                "-safe", "0",
                "-i", listURL.path,
                "-vn",
                "-c:a", "copy",
                outputURL.path
            ]
            try await wrapper.execute(args)
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
        }

        // Attempt 2: re-encode audio with consistent settings
        var args = ["ffmpeg", "-y"]
        if let progressPath = progressFilePath {
            args += ["-progress", progressPath]
        }
        args += [
            "-f", "concat",
            "-safe", "0",
            "-i", listURL.path,
            "-vn",
            "-c:a", "aac",
            "-b:a", "192k",
            outputURL.path
        ]
        try await wrapper.execute(args)

        return outputURL
    }
}
