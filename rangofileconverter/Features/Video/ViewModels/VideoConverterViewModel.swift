import SwiftUI
import SwiftData
import AVFoundation

@Observable
final class VideoConverterViewModel {
    var selectedThumbnail: UIImage?
    var selectedFileName: String = ""
    var selectedVideoURL: URL?
    var isConverting = false
    var showConversionDetail = false

    private let coordinator = ConversionCoordinator()

    func selectVideo(thumbnail: UIImage, fileName: String, fileURL: URL) {
        selectedThumbnail = thumbnail
        selectedFileName = fileName
        selectedVideoURL = fileURL
        showConversionDetail = true
    }

    func addHistoryRecord(fileName: String, thumbnail: UIImage?, outputURL: URL, toolType: String = "Convert", context: ModelContext) {
        let ext = fileName.components(separatedBy: ".").last ?? "mp4"
        let formatDef = FormatRegistry.format(forExtension: ext)

        let outputPath = ConversionRecord.persistOutput(from: outputURL)

        let thumbnailData = thumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: ext.uppercased(),
            targetFormatID: formatDef?.id ?? ext.lowercased(),
            thumbnailData: thumbnailData,
            status: .converted,
            outputPath: outputPath,
            toolType: toolType,
            mediaCategory: "video"
        )

        context.insert(record)
        try? context.save()
    }

    func compressVideo(
        inputURL: URL,
        fileName: String,
        thumbnail: UIImage?,
        quality: Int,
        resolutionHeight: Int?,
        preset: String,
        outputFormat: String,
        context: ModelContext
    ) async {
        isConverting = true

        let sourceExt = fileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let thumbnailData = thumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: sourceExt,
            targetFormatID: outputFormat,
            thumbnailData: thumbnailData,
            status: .converting,
            toolType: "Compress",
            mediaCategory: "video"
        )

        context.insert(record)
        try? context.save()

        // Probe input duration for progress tracking
        let totalDurationUs: Double = await {
            let asset = AVAsset(url: inputURL)
            if let cmDuration = try? await asset.load(.duration) {
                return CMTimeGetSeconds(cmDuration) * 1_000_000
            }
            return 0
        }()

        do {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("rango_conversions", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let baseName = inputURL.deletingPathExtension().lastPathComponent
            let shortID = UUID().uuidString.prefix(8)
            let outputURL = tempDir.appendingPathComponent("\(baseName)_\(shortID).\(outputFormat)")

            // Progress file for FFmpeg to write to
            let progressFile = tempDir.appendingPathComponent("progress_\(shortID).txt")

            var args: [String] = []
            args += ["-progress", progressFile.path]
            args += ["-c:v", "mpeg4"]
            args += ["-q:v", String(quality)]

            switch preset {
            case "ultrafast": args += ["-g", "300", "-bf", "0"]
            case "fast": args += ["-g", "250", "-bf", "0"]
            case "medium": args += ["-g", "150", "-bf", "2"]
            case "slow": args += ["-g", "100", "-bf", "2", "-trellis", "2"]
            default: break
            }

            if let height = resolutionHeight {
                args += ["-vf", "scale=-2:\(height)"]
            }

            args += ["-c:a", "aac", "-b:a", "128k"]

            // Start polling progress file
            let pollingTask = Task.detached { [weak record] in
                guard totalDurationUs > 0 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { break }

                    let progress = Self.parseProgress(from: progressFile, totalDurationUs: totalDurationUs)
                    await MainActor.run {
                        record?.progress = progress
                        try? context.save()
                    }
                }
            }

            try await FFmpegWrapper.shared.convert(
                input: inputURL,
                output: outputURL,
                extraArgs: args
            )

            pollingTask.cancel()
            try? FileManager.default.removeItem(at: progressFile)

            let outputPath = ConversionRecord.persistOutput(from: outputURL)
            record.progress = 1.0
            record.status = .converted
            record.outputPath = outputPath
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
        }

        try? context.save()
        isConverting = false
    }

    private static func parseProgress(from fileURL: URL, totalDurationUs: Double) -> Double {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return 0 }

        // FFmpeg writes multiple progress blocks. Find the last out_time_us value.
        var lastOutTimeUs: Double = 0
        for line in content.components(separatedBy: "\n").reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("out_time_us=") {
                let value = trimmed.dropFirst("out_time_us=".count)
                if let us = Double(value), us > 0 {
                    lastOutTimeUs = us
                    break
                }
            }
        }

        guard lastOutTimeUs > 0, totalDurationUs > 0 else { return 0 }
        return min(lastOutTimeUs / totalDurationUs, 0.99)
    }

    func convert(to format: FormatDefinition, context: ModelContext) async {
        guard let inputURL = selectedVideoURL else { return }

        isConverting = true

        let sourceExt = selectedFileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let thumbnailData = selectedThumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: selectedFileName,
            sourceFormat: sourceExt,
            targetFormatID: format.id,
            thumbnailData: thumbnailData,
            status: .converting,
            mediaCategory: "video"
        )

        context.insert(record)
        try? context.save()

        let totalDurationUs = await probeDurationUs(url: inputURL)

        do {
            var job = ConversionJob(inputURL: inputURL, outputFormat: format)

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("rango_conversions", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let shortID = UUID().uuidString.prefix(8)
            let progressFile = tempDir.appendingPathComponent("progress_\(shortID).txt")

            var pollingTask: Task<Void, Never>?
            if totalDurationUs > 0 {
                job.progressFilePath = progressFile.path
                pollingTask = startProgressPolling(
                    progressFile: progressFile,
                    totalDurationUs: totalDurationUs,
                    record: record,
                    context: context
                )
            }

            let result = try await coordinator.convert(job: job)

            pollingTask?.cancel()
            try? FileManager.default.removeItem(at: progressFile)

            let outputPath = ConversionRecord.persistOutput(from: result.outputURL)
            record.progress = 1.0
            record.status = .converted
            record.outputPath = outputPath
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
        }

        try? context.save()

        isConverting = false
        selectedThumbnail = nil
        selectedFileName = ""
        selectedVideoURL = nil
    }

    func changeSpeed(
        inputURL: URL,
        fileName: String,
        thumbnail: UIImage?,
        speed: Double,
        context: ModelContext
    ) async {
        isConverting = true

        let sourceExt = fileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let ext = fileName.components(separatedBy: ".").last?.lowercased() ?? "mp4"
        let outputExt = (ext.isEmpty || ext == "mov") ? "mp4" : ext
        let thumbnailData = thumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: sourceExt,
            targetFormatID: outputExt,
            thumbnailData: thumbnailData,
            status: .converting,
            toolType: "Speed",
            mediaCategory: "video"
        )

        context.insert(record)
        try? context.save()

        let totalDurationUs = await probeDurationUs(url: inputURL)
        // Output duration changes with speed
        let outputDurationUs = totalDurationUs / speed

        do {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("rango_conversions", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let shortID = UUID().uuidString.prefix(8)
            let outputURL = tempDir.appendingPathComponent("speed_\(shortID).\(outputExt)")
            let progressFile = tempDir.appendingPathComponent("progress_\(shortID).txt")

            let videoFilter = "setpts=PTS/\(speed)"
            let audioFilter = Self.buildAtempoFilter(for: speed)

            var args: [String] = []
            args += ["-progress", progressFile.path]
            args += ["-filter:v", videoFilter, "-filter:a", audioFilter]

            let pollingTask = startProgressPolling(
                progressFile: progressFile,
                totalDurationUs: outputDurationUs,
                record: record,
                context: context
            )

            try await FFmpegWrapper.shared.convert(
                input: inputURL,
                output: outputURL,
                extraArgs: args
            )

            pollingTask.cancel()
            try? FileManager.default.removeItem(at: progressFile)

            let outputPath = ConversionRecord.persistOutput(from: outputURL)
            record.progress = 1.0
            record.status = .converted
            record.outputPath = outputPath
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
        }

        try? context.save()
        isConverting = false
    }

    func clipVideo(
        inputURL: URL,
        fileName: String,
        thumbnail: UIImage?,
        startTime: Double,
        endTime: Double,
        context: ModelContext
    ) async {
        isConverting = true

        let sourceExt = fileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let ext = fileName.components(separatedBy: ".").last?.lowercased() ?? "mp4"
        let thumbnailData = thumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: sourceExt,
            targetFormatID: ext,
            thumbnailData: thumbnailData,
            status: .converting,
            toolType: "Time Clip",
            mediaCategory: "video"
        )

        context.insert(record)
        try? context.save()

        // Time clip uses -c copy (stream copy), so it's fast — no meaningful progress to track
        // but we still set up the pattern for consistency
        do {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("rango_conversions", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let shortID = UUID().uuidString.prefix(8)
            let outputURL = tempDir.appendingPathComponent("clip_\(shortID).\(ext)")

            try await FFmpegWrapper.shared.convert(
                input: inputURL,
                output: outputURL,
                extraArgs: [
                    "-ss", String(format: "%.3f", startTime),
                    "-to", String(format: "%.3f", endTime),
                    "-c", "copy"
                ]
            )

            let outputPath = ConversionRecord.persistOutput(from: outputURL)
            record.progress = 1.0
            record.status = .converted
            record.outputPath = outputPath
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
        }

        try? context.save()
        isConverting = false
    }

    // MARK: - Progress Helpers

    private func probeDurationUs(url: URL) async -> Double {
        let asset = AVAsset(url: url)
        if let cmDuration = try? await asset.load(.duration) {
            return CMTimeGetSeconds(cmDuration) * 1_000_000
        }
        return 0
    }

    private func startProgressPolling(
        progressFile: URL,
        totalDurationUs: Double,
        record: ConversionRecord,
        context: ModelContext
    ) -> Task<Void, Never> {
        Task.detached { [weak record] in
            guard totalDurationUs > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { break }

                let progress = Self.parseProgress(from: progressFile, totalDurationUs: totalDurationUs)
                await MainActor.run {
                    record?.progress = progress
                    try? context.save()
                }
            }
        }
    }

    private static func buildAtempoFilter(for speed: Double) -> String {
        var remaining = speed
        var filters: [String] = []

        while remaining > 2.0 {
            filters.append("atempo=2.0")
            remaining /= 2.0
        }
        while remaining < 0.5 {
            filters.append("atempo=0.5")
            remaining /= 0.5
        }

        if abs(remaining - 1.0) > 0.001 {
            filters.append("atempo=\(remaining)")
        }

        return filters.isEmpty ? "atempo=1.0" : filters.joined(separator: ",")
    }

}
