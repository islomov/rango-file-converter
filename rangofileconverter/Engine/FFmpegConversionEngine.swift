import Foundation
import CoreGraphics

/// FFmpeg-based conversion engine for image, video, and audio formats.
final class FFmpegConversionEngine: ConversionEngine {

    let supportedMediaTypes: Set<MediaType> = [.image, .video, .audio]

    /// Formats handled by NativeImageEngine instead of FFmpeg.
    private static let nativeOnlyFormats: Set<String> = ["webp", "heic"]

    /// Formats that require external libraries not included in this FFmpeg build.
    private static let unsupportedFormats: Set<String> = ["webm", "ogv", "swf", "amv"]

    private let wrapper = FFmpegWrapper.shared

    func canConvert(from inputExtension: String, to outputFormat: FormatDefinition) -> Bool {
        guard supportedMediaTypes.contains(outputFormat.mediaType) else { return false }
        guard !Self.nativeOnlyFormats.contains(outputFormat.id) else { return false }
        guard !Self.unsupportedFormats.contains(outputFormat.id) else { return false }
        return FormatRegistry.format(forExtension: inputExtension) != nil
    }

    func convert(job: ConversionJob) async throws -> ConversionResult {

        let startTime = Date()

        let outputURL = makeOutputURL(for: job)
        let extraArgs = buildFFmpegArgs(for: job)

        try await wrapper.convert(
            input: job.inputURL,
            output: outputURL,
            extraArgs: extraArgs
        )

        let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attrs[.size] as? Int64 ?? 0

        return ConversionResult(
            job: job,
            outputURL: outputURL,
            duration: Date().timeIntervalSince(startTime),
            outputFileSize: fileSize
        )
    }

    // MARK: - Argument Building

    private func buildFFmpegArgs(for job: ConversionJob) -> [String] {
        var args: [String] = []

        // Progress file for external polling
        if let progressPath = job.progressFilePath {
            args += ["-progress", progressPath]
        }

        // Strip video stream (used for audio extraction from video)
        if job.stripVideo {
            args += ["-vn"]
        }

        // Trim: -ss (start) and -t (duration)
        if let trim = job.trimRange {
            args += ["-ss", formatTime(trim.lowerBound)]
            args += ["-t", formatTime(trim.upperBound - trim.lowerBound)]
        }

        // GIF output uses filter_complex for palette optimization
        if job.outputFormat.id == "gif" {
            args += buildGifArgs(for: job)
            return args
        }

        // Build video/image filter chain
        var videoFilters: [String] = []

        if let crop = job.cropRect {
            videoFilters.append("crop=\(Int(crop.width)):\(Int(crop.height)):\(Int(crop.origin.x)):\(Int(crop.origin.y))")
        }

        if let scale = job.scale {
            videoFilters.append("scale=\(Int(scale.width)):\(Int(scale.height))")
        }

        if let ratio = job.aspectRatio {
            let w = ratio.width
            let h = ratio.height
            switch job.ratioFitMode {
            case .crop:
                // Crop to fill: pick the largest centered rectangle matching the target ratio
                videoFilters.append("crop='min(iw,ih*\(w)/\(h))':'min(ih,iw*\(h)/\(w))'")
            case .pad:
                // Pad (letterbox/pillarbox): scale down to fit, then pad with black
                videoFilters.append("scale='if(gt(iw/ih,\(w)/\(h)),iw,ih*\(w)/\(h))':'if(gt(iw/ih,\(w)/\(h)),iw*\(h)/\(w),ih)':force_original_aspect_ratio=decrease")
                videoFilters.append("pad='if(gt(iw/ih,\(w)/\(h)),iw,ih*\(w)/\(h))':'if(gt(iw/ih,\(w)/\(h)),iw*\(h)/\(w),ih)':(ow-iw)/2:(oh-ih)/2:black")
            }
        }

        if !videoFilters.isEmpty {
            args += ["-vf", videoFilters.joined(separator: ",")]
        }

        // For still image outputs, take only the first frame.
        // This prevents the image2 muxer from failing on multi-frame inputs (GIF, APNG).
        if job.outputFormat.mediaType == .image && job.outputFormat.id != "gif" {
            args += ["-frames:v", "1", "-update", "1"]
        }

        // Format-specific arguments
        args += formatSpecificArgs(for: job.outputFormat)

        // Quality
        if let quality = job.quality {
            switch job.outputFormat.mediaType {
            case .video:
                args += ["-q:v", String(quality)]
            case .audio:
                args += ["-b:a", "\(quality)k"]
            case .image:
                args += ["-q:v", String(quality)]
            default:
                break
            }
        }

        return args
    }

    /// Builds FFmpeg args for high-quality GIF output using single-pass palette optimization.
    private func buildGifArgs(for job: ConversionJob) -> [String] {
        let fps = job.fps ?? 10
        var filters = "fps=\(fps)"

        if let scale = job.scale {
            filters += ",scale=\(Int(scale.width)):-1:flags=lanczos"
        }

        let filterComplex = "[0:v] \(filters),split [a][b]; [a] palettegen [p]; [b][p] paletteuse"
        return ["-filter_complex", filterComplex, "-loop", "0"]
    }

    /// Returns format-specific FFmpeg flags needed for certain output formats.
    private func formatSpecificArgs(for format: FormatDefinition) -> [String] {
        switch format.id {
        case "jpeg", "jpg":
            return ["-c:v", "mjpeg"]
        case "bmp":
            return ["-c:v", "bmp"]
        case "tiff":
            return ["-c:v", "tiff"]
        case "tga":
            return ["-c:v", "targa"]
        case "jp2":
            return ["-c:v", "jpeg2000"]
        case "gif":
            return ["-c:v", "gif"]
        case "exr":
            return ["-c:v", "exr"]
        case "pbm":
            return ["-c:v", "pbm"]
        case "pgm":
            return ["-c:v", "pgm"]
        case "pam":
            return ["-c:v", "pam"]
        case "pfm":
            return ["-c:v", "pfm"]
        case "sgi", "rgb":
            return ["-c:v", "sgi"]
        case "xwd":
            return ["-c:v", "xwd"]
        case "sunvbm":
            return ["-c:v", "sunrast"]
        case "yuv":
            return ["-c:v", "rawvideo", "-pix_fmt", "yuv420p"]

        // MARK: Video formats
        case "amv":
            return ["-f", "avi", "-c:v", "amv", "-c:a", "adpcm_ima_amv",
                    "-s", "160x120", "-r", "16", "-pix_fmt", "yuvj420p",
                    "-ac", "1", "-ar", "22050"]
        case "flv":
            return ["-c:v", "flv1", "-c:a", "aac", "-ar", "44100"]
        case "rm":
            return ["-f", "rm", "-c:v", "rv20", "-c:a", "real_144"]
        case "3gp":
            return ["-f", "3gp", "-c:v", "mpeg4", "-c:a", "aac"]
        case "3g2":
            return ["-f", "3g2", "-c:v", "mpeg4", "-c:a", "aac"]
        default:
            return []
        }
    }

    private func makeOutputURL(for job: ConversionJob) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let baseName = job.inputURL.deletingPathExtension().lastPathComponent
        let shortID = job.id.uuidString.prefix(8)
        let outputName = "\(baseName)_\(shortID).\(job.outputFormat.fileExtension)"
        return tempDir.appendingPathComponent(outputName)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%02d:%06.3f", hrs, mins, secs)
    }
}

enum ConversionError: Error, LocalizedError {
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let name):
            return "\(name) output is not supported in this build. A custom FFmpeg build with additional libraries is needed."
        }
    }
}
