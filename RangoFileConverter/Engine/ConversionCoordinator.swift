import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Routes conversion jobs to the appropriate engine based on format support.
/// Engines are checked in order — the first engine that can handle the job wins.
final class ConversionCoordinator {

    private let engines: [ConversionEngine]

    /// Input formats that FFmpeg cannot reliably decode — convert to JPEG first.
    private static let intermediateRequiredInputs: Set<String> = ["heic"]

    /// Output formats already handled natively — no intermediate step needed.
    private static let nativeOutputFormats: Set<String> = ["heic", "webp"]

    init() {
        self.engines = [
            NativeImageEngine(),       // HEIC, WEBP via iOS native APIs
            NativeAudioEngine(),       // M4A via AVAssetExportSession
            CloudConvertEngine(),      // Documents via CloudConvert API
            FFmpegConversionEngine(),  // Everything else via FFmpeg
        ]
    }

    func convert(job: ConversionJob) async throws -> ConversionResult {
        let inputExtension = job.inputURL.pathExtension.lowercased()

        // HEIC input going to a non-native output: convert to JPEG first so FFmpeg
        // gets a format it can reliably decode.
        let effectiveJob: ConversionJob
        if Self.intermediateRequiredInputs.contains(inputExtension),
           !Self.nativeOutputFormats.contains(job.outputFormat.id) {
            let jpegURL = try convertToJPEGIntermediate(from: job.inputURL)
            var intermediateJob = job
            intermediateJob.inputURL = jpegURL
            effectiveJob = intermediateJob
        } else {
            effectiveJob = job
        }

        let effectiveExtension = effectiveJob.inputURL.pathExtension

        for engine in engines {
            if engine.canConvert(from: effectiveExtension, to: effectiveJob.outputFormat),
               engine.canHandle(job: effectiveJob) {
                return try await engine.convert(job: effectiveJob)
            }
        }

        throw ConversionError.unsupportedFormat(job.outputFormat.displayName)
    }

    // MARK: - Intermediate HEIC → JPEG

    /// Decodes a HEIC file using native iOS APIs and writes a temporary JPEG.
    private func convertToJPEGIntermediate(from inputURL: URL) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw NativeImageError.failedToLoadImage(inputURL.path)
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let jpegURL = tempDir.appendingPathComponent("\(baseName)_intermediate.jpg")

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw NativeImageError.failedToCreateDestination("JPEG")
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 1.0
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw NativeImageError.finalizeFailed("JPEG")
        }

        try (data as Data).write(to: jpegURL)
        return jpegURL
    }
}
