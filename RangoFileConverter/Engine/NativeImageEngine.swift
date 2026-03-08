import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import UIKit
import webp

/// Native iOS image engine for formats that FFmpeg's pre-built binary doesn't support.
/// Uses CGImageDestination for HEIC, and webp.swift library for WebP encoding.
final class NativeImageEngine: ConversionEngine {

    let supportedMediaTypes: Set<MediaType> = [.image]

    /// Format IDs handled by this engine.
    private static let nativeFormats: Set<String> = ["heic", "webp"]

    func canConvert(from inputExtension: String, to outputFormat: FormatDefinition) -> Bool {
        guard outputFormat.mediaType == .image else { return false }
        return Self.nativeFormats.contains(outputFormat.id)
    }

    func convert(job: ConversionJob) async throws -> ConversionResult {
        let startTime = Date()

        // Load source image
        guard let imageSource = CGImageSourceCreateWithURL(job.inputURL as CFURL, nil),
              var cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw NativeImageError.failedToLoadImage(job.inputURL.path)
        }

        // Apply crop
        if let cropRect = job.cropRect {
            guard let cropped = cgImage.cropping(to: cropRect) else {
                throw NativeImageError.cropFailed
            }
            cgImage = cropped
        }

        // Apply scale
        if let targetSize = job.scale {
            cgImage = try scaleImage(cgImage, to: targetSize)
        }

        let outputURL = makeOutputURL(for: job)
        let quality = job.quality.map { Double($0) / 100.0 } ?? 0.8

        // Route to the correct encoder
        switch job.outputFormat.id {
        case "heic":
            try encodeHEIC(cgImage, to: outputURL, quality: quality)
        case "webp":
            try encodeWebP(cgImage, to: outputURL, quality: quality)
        default:
            throw ConversionError.unsupportedFormat(job.outputFormat.displayName)
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attrs[.size] as? Int64 ?? 0

        return ConversionResult(
            job: job,
            outputURL: outputURL,
            duration: Date().timeIntervalSince(startTime),
            outputFileSize: fileSize
        )
    }

    // MARK: - Encoders

    private func encodeHEIC(_ image: CGImage, to url: URL, quality: Double) throws {
        let data = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw NativeImageError.failedToCreateDestination("HEIC")
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw NativeImageError.finalizeFailed("HEIC")
        }

        try (data as Data).write(to: url)
    }

    private func encodeWebP(_ image: CGImage, to url: URL, quality: Double) throws {
        let uiImage = UIImage(cgImage: image)
        let webpQuality = Int(quality * 100)
        let encoded = try WebPEncoder().encode(uiImage, config: .preset(.picture, quality: Float(webpQuality)))
        try encoded.write(to: url)
    }

    // MARK: - Helpers

    private func scaleImage(_ image: CGImage, to targetSize: CGSize) throws -> CGImage {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
        ) else {
            throw NativeImageError.scaleFailed
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let scaled = context.makeImage() else {
            throw NativeImageError.scaleFailed
        }

        return scaled
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
}

enum NativeImageError: Error, LocalizedError {
    case failedToLoadImage(String)
    case failedToCreateDestination(String)
    case finalizeFailed(String)
    case cropFailed
    case scaleFailed

    var errorDescription: String? {
        switch self {
        case .failedToLoadImage(let path):
            return "Failed to load image: \(path)"
        case .failedToCreateDestination(let format):
            return "Failed to create \(format) encoder"
        case .finalizeFailed(let format):
            return "Failed to write \(format) output"
        case .cropFailed:
            return "Failed to crop image"
        case .scaleFailed:
            return "Failed to scale image"
        }
    }
}
