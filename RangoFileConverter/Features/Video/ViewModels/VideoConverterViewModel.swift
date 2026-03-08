import SwiftUI
import AVFoundation
import Combine

final class VideoConverterViewModel: ObservableObject {
    @Published var selectedThumbnail: UIImage?
    @Published var selectedFileName: String = ""
    @Published var selectedVideoURL: URL?
    @Published var showConversionDetail = false
    @Published var showGifDetail = false
    @Published var showExtractAudioDetail = false
    @Published var showVideoRatio = false

    private let coordinator = ConversionCoordinator()
    private let store = HistoryStore.shared
    private let taskManager = ConversionTaskManager.shared

    func selectVideo(thumbnail: UIImage, fileName: String, fileURL: URL) {
        selectedThumbnail = thumbnail
        selectedFileName = fileName
        selectedVideoURL = fileURL
        showConversionDetail = true
    }

    func selectVideoForGif(thumbnail: UIImage, fileName: String, fileURL: URL) {
        selectedThumbnail = thumbnail
        selectedFileName = fileName
        selectedVideoURL = fileURL
        showGifDetail = true
    }

    func selectVideoForExtractAudio(thumbnail: UIImage, fileName: String, fileURL: URL) {
        selectedThumbnail = thumbnail
        selectedFileName = fileName
        selectedVideoURL = fileURL
        showExtractAudioDetail = true
    }

    func selectVideoForRatio(thumbnail: UIImage, fileName: String, fileURL: URL) {
        selectedThumbnail = thumbnail
        selectedFileName = fileName
        selectedVideoURL = fileURL
        showVideoRatio = true
    }

    func addHistoryRecord(fileName: String, thumbnail: UIImage?, outputURL: URL, toolType: String = ToolType.convert.rawValue) {
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

        store.add(record)
    }

    func compressVideo(
        inputURL: URL,
        fileName: String,
        thumbnail: UIImage?,
        quality: Int,
        resolutionHeight: Int?,
        preset: String,
        outputFormat: String
    ) {
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
            toolType: ToolType.compress.rawValue,
            mediaCategory: "video"
        )

        store.add(record)

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            let totalDurationUs: Double = await {
                let asset = AVAsset(url: inputURL)
                if let cmDuration = try? await asset.load(.duration) {
                    return CMTimeGetSeconds(cmDuration) * 1_000_000
                }
                return 0
            }()

            var pollingTask: Task<Void, Never>?
            do {
                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }

                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("rango_conversions", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                let baseName = inputURL.deletingPathExtension().lastPathComponent
                let shortID = UUID().uuidString.prefix(8)
                let outputURL = tempDir.appendingPathComponent("\(baseName)_\(shortID).\(outputFormat)")

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

                pollingTask = self.startProgressPolling(
                    progressFile: progressFile,
                    totalDurationUs: totalDurationUs,
                    record: record
                )

                try await FFmpegWrapper.shared.convert(
                    input: inputURL,
                    output: outputURL,
                    extraArgs: args
                )

                pollingTask?.cancel()
                try? FileManager.default.removeItem(at: progressFile)

                let outputPath = ConversionRecord.persistOutput(from: outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                pollingTask?.cancel()
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    func convert(inputURL: URL, fileName: String, thumbnail: UIImage?, to format: FormatDefinition) {
        let sourceExt = fileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let thumbnailData = thumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: sourceExt,
            targetFormatID: format.id,
            thumbnailData: thumbnailData,
            status: .converting,
            mediaCategory: "video"
        )

        store.add(record)

        let coordinator = self.coordinator
        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            let totalDurationUs = await self.probeDurationUs(url: inputURL)

            var pollingTask: Task<Void, Never>?
            do {
                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }

                var job = ConversionJob(inputURL: inputURL, outputFormat: format)

                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("rango_conversions", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let shortID = UUID().uuidString.prefix(8)
                let progressFile = tempDir.appendingPathComponent("progress_\(shortID).txt")

                if totalDurationUs > 0 {
                    job.progressFilePath = progressFile.path
                    pollingTask = self.startProgressPolling(
                        progressFile: progressFile,
                        totalDurationUs: totalDurationUs,
                        record: record
                    )
                }

                let result = try await coordinator.convert(job: job)

                pollingTask?.cancel()
                try? FileManager.default.removeItem(at: progressFile)

                let outputPath = ConversionRecord.persistOutput(from: result.outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                pollingTask?.cancel()
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    func extractAudio(inputURL: URL, fileName: String, thumbnail: UIImage?, to format: FormatDefinition) {
        let sourceExt = fileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let thumbnailData = thumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: sourceExt,
            targetFormatID: format.id,
            thumbnailData: thumbnailData,
            status: .converting,
            toolType: ToolType.extractAudio.rawValue,
            mediaCategory: "video"
        )

        store.add(record)

        let coordinator = self.coordinator
        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            let totalDurationUs = await self.probeDurationUs(url: inputURL)

            var pollingTask: Task<Void, Never>?
            do {
                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }

                var job = ConversionJob(inputURL: inputURL, outputFormat: format)
                job.stripVideo = true

                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("rango_conversions", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let shortID = UUID().uuidString.prefix(8)
                let progressFile = tempDir.appendingPathComponent("progress_\(shortID).txt")

                if totalDurationUs > 0 {
                    job.progressFilePath = progressFile.path
                    pollingTask = self.startProgressPolling(
                        progressFile: progressFile,
                        totalDurationUs: totalDurationUs,
                        record: record
                    )
                }

                let result = try await coordinator.convert(job: job)

                pollingTask?.cancel()
                try? FileManager.default.removeItem(at: progressFile)

                let outputPath = ConversionRecord.persistOutput(from: result.outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                pollingTask?.cancel()
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    func changeSpeed(
        inputURL: URL,
        fileName: String,
        thumbnail: UIImage?,
        speed: Double
    ) {
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
            toolType: ToolType.speed.rawValue,
            mediaCategory: "video"
        )

        store.add(record)

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            let totalDurationUs = await self.probeDurationUs(url: inputURL)
            let outputDurationUs = totalDurationUs / speed

            var pollingTask: Task<Void, Never>?
            do {
                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }

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

                pollingTask = self.startProgressPolling(
                    progressFile: progressFile,
                    totalDurationUs: outputDurationUs,
                    record: record
                )

                try await FFmpegWrapper.shared.convert(
                    input: inputURL,
                    output: outputURL,
                    extraArgs: args
                )

                pollingTask?.cancel()
                try? FileManager.default.removeItem(at: progressFile)

                let outputPath = ConversionRecord.persistOutput(from: outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                pollingTask?.cancel()
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    func clipVideo(
        inputURL: URL,
        fileName: String,
        thumbnail: UIImage?,
        startTime: Double,
        endTime: Double
    ) {
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
            toolType: ToolType.timeClip.rawValue,
            mediaCategory: "video"
        )

        store.add(record)

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            do {
                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }

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
                await MainActor.run {
                    record.progress = 1.0
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

    func convertToGif(inputURL: URL, fileName: String, thumbnail: UIImage?, fps: Int, width: Int) {
        guard let gifFormat = FormatRegistry.format(forExtension: "gif") else { return }

        let sourceExt = fileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let thumbnailData = thumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: sourceExt,
            targetFormatID: gifFormat.id,
            thumbnailData: thumbnailData,
            status: .converting,
            toolType: ToolType.gif.rawValue,
            mediaCategory: "video"
        )

        store.add(record)

        let coordinator = self.coordinator
        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            let totalDurationUs = await self.probeDurationUs(url: inputURL)

            var pollingTask: Task<Void, Never>?
            do {
                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }

                var job = ConversionJob(inputURL: inputURL, outputFormat: gifFormat)
                job.fps = fps
                job.scale = CGSize(width: width, height: -1)

                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("rango_conversions", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let shortID = UUID().uuidString.prefix(8)
                let progressFile = tempDir.appendingPathComponent("progress_\(shortID).txt")

                if totalDurationUs > 0 {
                    job.progressFilePath = progressFile.path
                    pollingTask = self.startProgressPolling(
                        progressFile: progressFile,
                        totalDurationUs: totalDurationUs,
                        record: record
                    )
                }

                let result = try await coordinator.convert(job: job)

                pollingTask?.cancel()
                try? FileManager.default.removeItem(at: progressFile)

                let outputPath = ConversionRecord.persistOutput(from: result.outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                pollingTask?.cancel()
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    // MARK: - Merge Videos

    func mergeVideos(
        inputs: [URL],
        outputExtension: String,
        thumbnail: UIImage?
    ) {
        let thumbnailData = thumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: "merged.\(outputExtension)",
            sourceFormat: outputExtension.uppercased(),
            targetFormatID: outputExtension.lowercased(),
            thumbnailData: thumbnailData,
            status: .converting,
            toolType: ToolType.merge.rawValue,
            mediaCategory: "video"
        )

        store.add(record)

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            // Sum durations across all inputs for progress tracking
            var totalDurationUs: Double = 0
            for url in inputs {
                totalDurationUs += await self.probeDurationUs(url: url)
            }

            var pollingTask: Task<Void, Never>?
            do {
                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }

                let mergeEngine = FFmpegMergeEngine()
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("rango_conversions", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let shortID = UUID().uuidString.prefix(8)
                let progressFile = tempDir.appendingPathComponent("progress_\(shortID).txt")

                if totalDurationUs > 0 {
                    pollingTask = self.startProgressPolling(
                        progressFile: progressFile,
                        totalDurationUs: totalDurationUs,
                        record: record
                    )
                }

                let outputURL = try await mergeEngine.merge(
                    inputs: inputs,
                    outputExtension: outputExtension,
                    progressFilePath: progressFile.path
                )

                pollingTask?.cancel()
                try? FileManager.default.removeItem(at: progressFile)

                let outputPath = ConversionRecord.persistOutput(from: outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                pollingTask?.cancel()
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    func convertRatio(
        inputURL: URL,
        fileName: String,
        thumbnail: UIImage?,
        aspectRatio: (width: Int, height: Int),
        fitMode: RatioFitMode,
        cropPosition: CGPoint? = nil,
        cropScale: CGFloat? = nil
    ) {
        let sourceExt = fileName.components(separatedBy: ".").last?.lowercased() ?? "mp4"
        let outputFormat = FormatRegistry.format(forExtension: sourceExt)
            ?? FormatRegistry.videoFormats.first(where: { $0.id == "mp4" })!

        let sourceExtUpper = sourceExt.uppercased()
        let thumbnailData = thumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: sourceExtUpper,
            targetFormatID: outputFormat.id,
            thumbnailData: thumbnailData,
            status: .converting,
            toolType: ToolType.ratio.rawValue,
            mediaCategory: "video"
        )

        store.add(record)

        let coordinator = self.coordinator
        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            let totalDurationUs = await self.probeDurationUs(url: inputURL)

            var pollingTask: Task<Void, Never>?
            do {
                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }

                var job = ConversionJob(inputURL: inputURL, outputFormat: outputFormat)
                job.aspectRatio = aspectRatio
                job.ratioFitMode = fitMode
                job.cropPosition = cropPosition
                job.cropScale = cropScale

                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("rango_conversions", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let shortID = UUID().uuidString.prefix(8)
                let progressFile = tempDir.appendingPathComponent("progress_\(shortID).txt")

                if totalDurationUs > 0 {
                    job.progressFilePath = progressFile.path
                    pollingTask = self.startProgressPolling(
                        progressFile: progressFile,
                        totalDurationUs: totalDurationUs,
                        record: record
                    )
                }

                let result = try await coordinator.convert(job: job)

                pollingTask?.cancel()
                try? FileManager.default.removeItem(at: progressFile)

                let outputPath = ConversionRecord.persistOutput(from: result.outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                pollingTask?.cancel()
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    // MARK: - Helpers

    private func failRecord(_ record: ConversionRecord, error: String) {
        record.status = .failed
        record.errorMessage = error
        store.save()
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
        record: ConversionRecord
    ) -> Task<Void, Never> {
        let store = self.store
        return Task.detached { [weak record] in
            guard totalDurationUs > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { break }

                let progress = Self.parseProgress(from: progressFile, totalDurationUs: totalDurationUs)
                await MainActor.run {
                    record?.progress = progress
                    store.save()
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

    private static func parseProgress(from fileURL: URL, totalDurationUs: Double) -> Double {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return 0 }

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
}
