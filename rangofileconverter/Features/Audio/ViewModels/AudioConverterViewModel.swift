import SwiftUI
import AVFoundation
import Combine

final class AudioConverterViewModel: ObservableObject {
    @Published var selectedFileName: String = ""
    @Published var selectedFileURL: URL?
    @Published var isConverting = false
    @Published var showConversionDetail = false
    @Published var isExtracting = false

    private let coordinator = ConversionCoordinator()
    private let store = HistoryStore.shared

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
        Task {
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
                await MainActor.run {
                    isExtracting = false
                    selectedFileName = audioFileName
                    selectedFileURL = outputURL
                    showConversionDetail = true
                }
            } catch {
                await MainActor.run {
                    isExtracting = false
                }
            }
        }
    }

    func convert(to format: FormatDefinition) async {
        guard let inputURL = selectedFileURL else { return }

        await MainActor.run { isConverting = true }

        let sourceExt = selectedFileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"

        let record = ConversionRecord(
            sourceFileName: selectedFileName,
            sourceFormat: sourceExt,
            targetFormatID: format.id,
            thumbnailData: nil,
            status: .converting,
            toolType: "Convert",
            mediaCategory: "audio"
        )

        await MainActor.run { store.add(record) }

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
                store.save()
            }
        } catch {
            await MainActor.run {
                record.status = .failed
                record.errorMessage = error.localizedDescription
                store.save()
            }
        }

        await MainActor.run {
            isConverting = false
            selectedFileName = ""
            selectedFileURL = nil
        }
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
