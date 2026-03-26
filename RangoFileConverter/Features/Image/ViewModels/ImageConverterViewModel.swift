import SwiftUI
import Combine
import ImageIO
import UniformTypeIdentifiers
import webp
import AppTrackingTransparency
import PencilKit

final class ImageConverterViewModel: ObservableObject {
    @Published var selectedFileName: String = ""
    @Published var selectedFileURL: URL?
    @Published var showConversionDetail = false
    @Published var navigateToHistoryTrigger = 0

    private let coordinator = ConversionCoordinator()
    private let store = HistoryStore.shared
    private let taskManager = ConversionTaskManager.shared

    func selectImage(_ image: UIImage, fileName: String, fileURL: URL) {
        selectedFileName = fileName
        selectedFileURL = fileURL
        showConversionDetail = true
    }

    func convert(inputURL: URL, fileName: String, to format: FormatDefinition) {
        let sourceExt = fileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let thumbnailData = Self.loadThumbnail(from: inputURL)?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: sourceExt,
            targetFormatID: format.id,
            thumbnailData: thumbnailData,
            status: .converting
        )

        let coordinator = self.coordinator
        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            do {
                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }
                let job = ConversionJob(inputURL: inputURL, outputFormat: format)
                let result = try await coordinator.convert(job: job)

                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }
                let outputPath = ConversionRecord.persistOutput(from: result.outputURL)
                await MainActor.run {
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    // MARK: - Image Loading Helpers

    /// Load a downsampled image from URL for display purposes (capped at maxPixelSize)
    static func loadPreviewImage(from url: URL, maxPixelSize: CGFloat = 1200) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Load full-resolution image from URL for processing
    static func loadFullImage(from url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Get image dimensions from URL without loading the full image
    static func imageDimensions(from url: URL) -> CGSize? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        return CGSize(width: width, height: height)
    }

    /// Generate a small thumbnail from URL for history records
    static func loadThumbnail(from url: URL) -> UIImage? {
        loadPreviewImage(from: url, maxPixelSize: 80)
    }

    // MARK: - Fire-and-Forget Processing Methods

    private func makeRecord(fileName: String, fileURL: URL, toolType: String) -> ConversionRecord {
        let ext = fileName.components(separatedBy: ".").last ?? "png"
        let formatDef = FormatRegistry.format(forExtension: ext)
        let thumbnailData = Self.loadThumbnail(from: fileURL)?
            .jpegData(compressionQuality: 0.8)

        return ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: ext.uppercased(),
            targetFormatID: formatDef?.id ?? ext.lowercased(),
            thumbnailData: thumbnailData,
            status: .converting,
            toolType: toolType
        )
    }

    private func completeRecord(_ record: ConversionRecord, outputURL: URL) {
        let outputPath = ConversionRecord.persistOutput(from: outputURL)
        record.status = .converted
        record.outputPath = outputPath
        store.save()
    }

    private func failRecord(_ record: ConversionRecord, error: String) {
        record.status = .failed
        record.errorMessage = error
        store.save()
    }

    // MARK: Rotate

    func processRotation(fileURL: URL, fileName: String, rotation: Double, flipH: Bool, flipV: Bool) {
        let record = makeRecord(fileName: fileName, fileURL: fileURL, toolType: ToolType.rotate.rawValue)

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            guard let image = Self.loadFullImage(from: fileURL) else {
                await MainActor.run { self.failRecord(record, error: "Failed to load image") }
                return
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            if let (_, url) = Self.renderRotatedImage(image: image, fileName: fileName, rotation: rotation, flipH: flipH, flipV: flipV) {
                await MainActor.run { self.completeRecord(record, outputURL: url) }
            } else {
                await MainActor.run { self.failRecord(record, error: "Failed to render rotated image") }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    static func renderRotatedImage(image: UIImage, fileName: String, rotation: Double, flipH: Bool, flipV: Bool) -> (UIImage, URL)? {
        guard let cgImage = image.cgImage else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let radians = rotation * .pi / 180

        let rotatedRect = CGRect(x: 0, y: 0, width: width, height: height)
            .applying(CGAffineTransform(rotationAngle: radians))
        let newWidth = abs(rotatedRect.width)
        let newHeight = abs(rotatedRect.height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
                  data: nil,
                  width: Int(newWidth),
                  height: Int(newHeight),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: bitmapInfo
              ) else { return nil }

        context.translateBy(x: newWidth / 2, y: newHeight / 2)
        context.rotate(by: radians)
        context.scaleBy(x: flipH ? -1 : 1, y: flipV ? -1 : 1)
        context.draw(cgImage, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))

        guard let outputCG = context.makeImage() else { return nil }
        let outputImage = UIImage(cgImage: outputCG)

        let ext = fileName.components(separatedBy: ".").last ?? "png"
        let outputName = "rotated_\(UUID().uuidString.prefix(8)).\(ext)"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let data = outputImage.pngData() {
            try? data.write(to: outputURL)
            return (outputImage, outputURL)
        }

        return nil
    }

    // MARK: Crop

    func processCrop(fileURL: URL, fileName: String, cropRect: CGRect) {
        let record = makeRecord(fileName: fileName, fileURL: fileURL, toolType: ToolType.crop.rawValue)

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            guard let image = Self.loadFullImage(from: fileURL) else {
                await MainActor.run { self.failRecord(record, error: "Failed to load image") }
                return
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            if let (_, url) = Self.renderCroppedImage(image: image, fileName: fileName, cropRect: cropRect) {
                await MainActor.run { self.completeRecord(record, outputURL: url) }
            } else {
                await MainActor.run { self.failRecord(record, error: "Failed to render cropped image") }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    static func renderCroppedImage(image: UIImage, fileName: String, cropRect: CGRect) -> (UIImage, URL)? {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let normalized = renderer.image { _ in image.draw(at: .zero) }
        guard let cgImage = normalized.cgImage else { return nil }

        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)

        let pixelRect = CGRect(
            x: (cropRect.minX * imgW).rounded(),
            y: (cropRect.minY * imgH).rounded(),
            width: (cropRect.width * imgW).rounded(),
            height: (cropRect.height * imgH).rounded()
        )

        guard let croppedCG = cgImage.cropping(to: pixelRect) else { return nil }
        let croppedImage = UIImage(cgImage: croppedCG)

        let ext = fileName.components(separatedBy: ".").last ?? "png"
        let outputName = "cropped_\(UUID().uuidString.prefix(8)).\(ext)"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let data = croppedImage.pngData() {
            try? data.write(to: outputURL)
            return (croppedImage, outputURL)
        }

        return nil
    }

    // MARK: Resize

    func processResize(fileURL: URL, fileName: String, width: Int, height: Int) {
        let record = makeRecord(fileName: fileName, fileURL: fileURL, toolType: ToolType.resize.rawValue)

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            guard let image = Self.loadFullImage(from: fileURL) else {
                await MainActor.run { self.failRecord(record, error: "Failed to load image") }
                return
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            if let (_, url) = Self.renderResizedImage(image: image, fileName: fileName, width: width, height: height) {
                await MainActor.run { self.completeRecord(record, outputURL: url) }
            } else {
                await MainActor.run { self.failRecord(record, error: "Failed to render resized image") }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    static func renderResizedImage(image: UIImage, fileName: String, width: Int, height: Int) -> (UIImage, URL)? {
        let newSize = CGSize(width: width, height: height)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        let ext = fileName.components(separatedBy: ".").last ?? "png"
        let outputName = "resized_\(UUID().uuidString.prefix(8)).\(ext)"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let data = resized.pngData() {
            try? data.write(to: outputURL)
            return (resized, outputURL)
        }

        return nil
    }

    // MARK: Compress

    func processCompress(fileURL: URL, fileName: String, formatExtension: String, quality: Double) {
        let outputFileName = "compressed_\(UUID().uuidString.prefix(8)).\(formatExtension)"
        let record = makeRecord(fileName: outputFileName, fileURL: fileURL, toolType: ToolType.compress.rawValue)

        let coordinator = self.coordinator
        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            let usesFFmpeg = (formatExtension == "jp2" || formatExtension == "tiff")

            if usesFFmpeg {
                guard let formatDef = FormatRegistry.format(forExtension: formatExtension) else {
                    await MainActor.run { self.failRecord(record, error: "Unknown format: \(formatExtension)") }
                    return
                }
                var job = ConversionJob(inputURL: fileURL, outputFormat: formatDef)
                let isLossy = !(formatExtension == "png" || formatExtension == "tiff")
                if isLossy {
                    job.quality = Int(quality)
                }
                do {
                    let result = try await coordinator.convert(job: job)
                    await MainActor.run { self.completeRecord(record, outputURL: result.outputURL) }
                } catch {
                    await MainActor.run { self.failRecord(record, error: error.localizedDescription) }
                }
            } else {
                guard let image = Self.loadFullImage(from: fileURL) else {
                    await MainActor.run { self.failRecord(record, error: "Failed to load image") }
                    return
                }
                if let (_, url) = Self.renderCompressedNative(image: image, formatExtension: formatExtension, quality: quality, outputFileName: outputFileName) {
                    await MainActor.run { self.completeRecord(record, outputURL: url) }
                } else {
                    await MainActor.run { self.failRecord(record, error: "Failed to compress image") }
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    static func renderCompressedNative(image: UIImage, formatExtension: String, quality: Double, outputFileName: String) -> (UIImage, URL)? {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputFileName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data: Data?
        switch formatExtension {
        case "jpg":
            data = normalized.jpegData(compressionQuality: quality / 100)
        case "png":
            data = normalized.pngData()
        case "heic":
            data = encodeHEICData(from: normalized, quality: quality / 100)
        case "webp":
            data = try? encodeWebPData(from: normalized, quality: quality / 100)
        default:
            data = nil
        }

        guard let outputData = data else { return nil }

        do {
            try outputData.write(to: outputURL)
            return (normalized, outputURL)
        } catch {
            return nil
        }
    }

    private static func encodeHEICData(from image: UIImage, quality: Double) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else { return nil }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func encodeWebPData(from image: UIImage, quality: Double) throws -> Data {
        try WebPEncoder().encode(image, config: .preset(.picture, quality: Float(quality * 100)))
    }

    // MARK: GIF

    func processGif(fileURLs: [URL], fileNames: [String], frameDelay: Double, loopForever: Bool, maxWidth: CGFloat = 800) {
        let thumbnailData = Self.loadThumbnail(from: fileURLs[0])?
            .jpegData(compressionQuality: 0.8)
        let record = ConversionRecord(
            sourceFileName: "animated.gif",
            sourceFormat: "GIF",
            targetFormatID: "gif",
            thumbnailData: thumbnailData,
            status: .converting,
            toolType: ToolType.gif.rawValue
        )
        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            if let url = Self.renderGIF(fileURLs: fileURLs, frameDelay: frameDelay, loopForever: loopForever, maxWidth: maxWidth) {
                await MainActor.run { self.completeRecord(record, outputURL: url) }
            } else {
                await MainActor.run { self.failRecord(record, error: "Failed to create GIF") }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    static func renderGIF(fileURLs: [URL], frameDelay: Double, loopForever: Bool, maxWidth: CGFloat = 800) -> URL? {
        let outputName = "animated_\(UUID().uuidString.prefix(8)).gif"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            fileURLs.count,
            nil
        ) else { return nil }

        let gifFileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: loopForever ? 0 : 1
            ]
        ]
        CGImageDestinationSetProperties(destination, gifFileProperties as CFDictionary)

        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay
            ]
        ]

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxWidth
        ]

        for url in fileURLs {
            autoreleasepool {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else { return }
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            }
        }

        guard CGImageDestinationFinalize(destination) else { return nil }
        return outputURL
    }

    // MARK: Stitch

    func processStitch(fileURLs: [URL], layout: String, background: String, gap: CGFloat) {
        let thumbnailData = Self.loadThumbnail(from: fileURLs[0])?
            .jpegData(compressionQuality: 0.8)
        let record = ConversionRecord(
            sourceFileName: "stitched.png",
            sourceFormat: "PNG",
            targetFormatID: "png",
            thumbnailData: thumbnailData,
            status: .converting,
            toolType: ToolType.stitch.rawValue
        )
        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            if let url = Self.renderStitch(fileURLs: fileURLs, layout: layout, background: background, gap: gap) {
                await MainActor.run { self.completeRecord(record, outputURL: url) }
            } else {
                await MainActor.run { self.failRecord(record, error: "Failed to stitch images") }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    static func renderStitch(fileURLs: [URL], layout: String, background: String, gap: CGFloat) -> URL? {
        guard !fileURLs.isEmpty else { return nil }

        let bgColor: UIColor
        switch background {
        case "Black": bgColor = .black
        case "Clear": bgColor = .clear
        default: bgColor = .white
        }

        // Get image sizes without loading full images
        let imageSizes: [CGSize] = fileURLs.compactMap { imageDimensions(from: $0) }
        guard imageSizes.count == fileURLs.count else { return nil }

        // Compute layout from sizes
        var canvasSize: CGSize
        var drawRects: [CGRect]

        switch layout {
        case "Vertical":
            (canvasSize, drawRects) = layoutVertical(sizes: imageSizes, gap: gap)
        case "Grid":
            (canvasSize, drawRects) = layoutGrid(sizes: imageSizes, gap: gap)
        default:
            (canvasSize, drawRects) = layoutHorizontal(sizes: imageSizes, gap: gap)
        }

        // Cap canvas to ~100MB (25 megapixels at 4 bytes/pixel)
        let maxCanvasPixels: CGFloat = 5000 * 5000
        let canvasPixels = canvasSize.width * canvasSize.height
        let canvasScale: CGFloat = canvasPixels > maxCanvasPixels ? sqrt(maxCanvasPixels / canvasPixels) : 1.0

        if canvasScale < 1.0 {
            canvasSize = CGSize(
                width: round(canvasSize.width * canvasScale),
                height: round(canvasSize.height * canvasScale)
            )
            drawRects = drawRects.map { rect in
                CGRect(
                    x: round(rect.origin.x * canvasScale),
                    y: round(rect.origin.y * canvasScale),
                    width: round(rect.width * canvasScale),
                    height: round(rect.height * canvasScale)
                )
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = background != "Clear"

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let result = renderer.image { ctx in
            bgColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            for (i, rect) in drawRects.enumerated() where i < fileURLs.count {
                autoreleasepool {
                    guard let img = loadFullImage(from: fileURLs[i]) else { return }
                    let fitted = aspectFitRect(imageSize: img.size, in: rect)
                    img.draw(in: fitted)
                }
            }
        }

        let outputName = "stitch_\(UUID().uuidString.prefix(8)).png"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard let data = result.pngData() else { return nil }
        do {
            try data.write(to: outputURL)
        } catch {
            return nil
        }

        return outputURL
    }

    // MARK: Draw

    func processDraw(fileURL: URL, fileName: String, drawing: PKDrawing, canvasDisplaySize: CGSize) {
        let record = makeRecord(fileName: fileName, fileURL: fileURL, toolType: ToolType.draw.rawValue)

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            guard let image = Self.loadFullImage(from: fileURL) else {
                await MainActor.run { self.failRecord(record, error: "Failed to load image") }
                return
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.failRecord(record, error: "Cancelled") }
                return
            }

            if let url = Self.renderDrawing(image: image, fileName: fileName, drawing: drawing, canvasDisplaySize: canvasDisplaySize) {
                await MainActor.run { self.completeRecord(record, outputURL: url) }
            } else {
                await MainActor.run { self.failRecord(record, error: "Failed to render drawing") }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    static func renderDrawing(image: UIImage, fileName: String, drawing: PKDrawing, canvasDisplaySize: CGSize) -> URL? {
        let imageSize = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        // Scale drawing from canvas display coordinates to full image pixel coordinates
        let scaleX = imageSize.width / canvasDisplaySize.width
        let scaleY = imageSize.height / canvasDisplaySize.height
        let scaledDrawing = drawing.transformed(using: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        let result = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: imageSize))

            let drawingImage = scaledDrawing.image(from: CGRect(origin: .zero, size: imageSize), scale: 1.0)
            drawingImage.draw(in: CGRect(origin: .zero, size: imageSize))
        }

        let ext = fileName.components(separatedBy: ".").last ?? "png"
        let outputName = "drawn_\(UUID().uuidString.prefix(8)).\(ext)"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let data = result.pngData() {
            try? data.write(to: outputURL)
            return outputURL
        }

        return nil
    }

    // MARK: - Stitch Layout Helpers (size-based, no UIImage needed)

    private static func layoutHorizontal(sizes: [CGSize], gap: CGFloat) -> (CGSize, [CGRect]) {
        let maxHeight = sizes.map(\.height).max() ?? 0
        var rects: [CGRect] = []
        var x: CGFloat = 0

        for size in sizes {
            let scale = maxHeight / size.height
            let w = size.width * scale
            rects.append(CGRect(x: x, y: 0, width: w, height: maxHeight))
            x += w + gap
        }

        let totalWidth = x - (sizes.isEmpty ? 0 : gap)
        return (CGSize(width: totalWidth, height: maxHeight), rects)
    }

    private static func layoutVertical(sizes: [CGSize], gap: CGFloat) -> (CGSize, [CGRect]) {
        let maxWidth = sizes.map(\.width).max() ?? 0
        var rects: [CGRect] = []
        var y: CGFloat = 0

        for size in sizes {
            let scale = maxWidth / size.width
            let h = size.height * scale
            rects.append(CGRect(x: 0, y: y, width: maxWidth, height: h))
            y += h + gap
        }

        let totalHeight = y - (sizes.isEmpty ? 0 : gap)
        return (CGSize(width: maxWidth, height: totalHeight), rects)
    }

    private static func layoutGrid(sizes: [CGSize], gap: CGFloat) -> (CGSize, [CGRect]) {
        let count = sizes.count
        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))

        let maxW = sizes.map(\.width).max() ?? 0
        let maxH = sizes.map(\.height).max() ?? 0

        let totalWidth = CGFloat(cols) * maxW + CGFloat(cols - 1) * gap
        let totalHeight = CGFloat(rows) * maxH + CGFloat(rows - 1) * gap

        var rects: [CGRect] = []
        for i in 0..<count {
            let col = i % cols
            let row = i / cols
            let x = CGFloat(col) * (maxW + gap)
            let y = CGFloat(row) * (maxH + gap)
            rects.append(CGRect(x: x, y: y, width: maxW, height: maxH))
        }

        return (CGSize(width: totalWidth, height: totalHeight), rects)
    }

    private static func aspectFitRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
        let widthRatio = rect.width / imageSize.width
        let heightRatio = rect.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        let fittedWidth = imageSize.width * scale
        let fittedHeight = imageSize.height * scale
        let x = rect.origin.x + (rect.width - fittedWidth) / 2
        let y = rect.origin.y + (rect.height - fittedHeight) / 2
        return CGRect(x: x, y: y, width: fittedWidth, height: fittedHeight)
    }
}
