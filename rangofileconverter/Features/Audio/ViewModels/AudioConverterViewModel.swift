import SwiftUI
import AVFoundation
import Combine

final class AudioConverterViewModel: ObservableObject {
    @Published var selectedFileName: String = ""
    @Published var selectedFileURL: URL?
    @Published var showConversionDetail = false
    @Published var isExtracting = false

    // Extract audio tool state
    @Published var showExtractAudioDetail = false
    @Published var extractThumbnail: UIImage?
    @Published var extractVideoURL: URL?
    @Published var extractFileName: String = ""

    private let coordinator = ConversionCoordinator()
    private let store = HistoryStore.shared
    private let taskManager = ConversionTaskManager.shared
    private var extractionTask: Task<Void, Never>?

    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "avi", "mkv", "wmv", "flv", "mpg", "mpeg",
        "m4v", "3gp", "3g2", "webm", "vob", "ts", "mxf", "f4v",
        "asf", "ogv", "rm", "amv", "swf"
    ]

    func selectAudio(fileName: String, fileURL: URL) {
        let ext = fileName.components(separatedBy: ".").last?.lowercased() ?? ""
        if Self.videoExtensions.contains(ext) {
            extractAudioFromVideo(fileName: fileName, fileURL: fileURL)
        } else {
            selectedFileName = fileName
            selectedFileURL = fileURL
            showConversionDetail = true
        }
    }

    private func extractAudioFromVideo(fileName: String, fileURL: URL) {
        isExtracting = true
        extractionTask?.cancel()
        extractionTask = Task { [weak self] in
            do {
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("rango_audio_extract", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                let baseName = fileURL.deletingPathExtension().lastPathComponent
                let shortID = UUID().uuidString.prefix(8)
                let outputURL = tempDir.appendingPathComponent("\(baseName)_\(shortID).wav")

                try await FFmpegWrapper.shared.convert(
                    input: fileURL,
                    output: outputURL,
                    extraArgs: ["-vn", "-acodec", "pcm_s16le"]
                )

                let audioFileName = "\(baseName).wav"
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    self.isExtracting = false
                    self.selectedFileName = audioFileName
                    self.selectedFileURL = outputURL
                    self.showConversionDetail = true
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.isExtracting = false
                }
            }
        }
    }

    func cancelExtraction() {
        extractionTask?.cancel()
        extractionTask = nil
    }

    func convert(inputURL: URL, fileName: String, to format: FormatDefinition) {
        let sourceExt = fileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: sourceExt,
            targetFormatID: format.id,
            thumbnailData: nil,
            status: .converting,
            toolType: "Convert",
            mediaCategory: "audio"
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

    // MARK: - Extract Audio

    func selectVideoForExtractAudio(thumbnail: UIImage, fileName: String, fileURL: URL) {
        extractThumbnail = thumbnail
        extractFileName = fileName
        extractVideoURL = fileURL
        showExtractAudioDetail = true
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
            toolType: "Extract Audio",
            mediaCategory: "audio"
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
