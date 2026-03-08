import AVFoundation
import lame

/// Native iOS audio engine for formats that FFmpeg's pre-built binary doesn't support well.
/// Uses AVAssetExportSession for M4A and LAME library for MP3 encoding.
final class NativeAudioEngine: ConversionEngine {

    let supportedMediaTypes: Set<MediaType> = [.audio]

    /// Output format IDs this engine handles natively.
    private static let nativeFormats: Set<String> = ["m4a", "mp3"]

    func canConvert(from inputExtension: String, to outputFormat: FormatDefinition) -> Bool {
        guard Self.nativeFormats.contains(outputFormat.id) else { return false }
        // Accept both audio and video inputs (for audio extraction)
        guard let inputFormat = FormatRegistry.format(forExtension: inputExtension) else { return false }
        return inputFormat.mediaType == .audio || inputFormat.mediaType == .video
    }

    func canHandle(job: ConversionJob) -> Bool {
        // Speed changes require atempo filter — let FFmpeg handle those
        if let speed = job.speedMultiplier, speed != 1.0 { return false }
        return true
    }

    func convert(job: ConversionJob) async throws -> ConversionResult {
        let startTime = Date()
        let outputURL = makeOutputURL(for: job)

        switch job.outputFormat.id {
        case "m4a":
            try await exportM4A(job: job, to: outputURL)
        case "mp3":
            try await encodeMP3(job: job, to: outputURL)
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

    // MARK: - M4A via AVAssetExportSession

    private func exportM4A(job: ConversionJob, to outputURL: URL) async throws {
        let asset = AVAsset(url: job.inputURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw NativeAudioError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        if let trim = job.trimRange {
            let start = CMTime(seconds: trim.lowerBound, preferredTimescale: 600)
            let end = CMTime(seconds: trim.upperBound, preferredTimescale: 600)
            exportSession.timeRange = CMTimeRange(start: start, end: end)
        }

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            break
        case .failed:
            throw exportSession.error ?? NativeAudioError.exportFailed
        case .cancelled:
            throw NativeAudioError.exportCancelled
        default:
            throw NativeAudioError.exportFailed
        }
    }

    // MARK: - MP3 via LAME

    private func encodeMP3(job: ConversionJob, to outputURL: URL) async throws {
        // Step 1: Decode input audio to PCM using AVAudioFile
        let pcmURL = try await decodeToPCM(job: job)
        defer { try? FileManager.default.removeItem(at: pcmURL) }

        // Step 2: Encode PCM to MP3 using LAME
        let audioFile = try AVAudioFile(forReading: pcmURL)
        let format = audioFile.processingFormat
        let sampleRate = Int32(format.sampleRate)
        let channels = format.channelCount

        guard let lameEncoder = lame_init() else {
            throw NativeAudioError.lameInitFailed
        }
        defer { lame_close(lameEncoder) }

        lame_set_in_samplerate(lameEncoder, sampleRate)
        lame_set_num_channels(lameEncoder, Int32(channels))
        lame_set_out_samplerate(lameEncoder, sampleRate)

        // Use VBR with quality 2 (high quality, ~190 kbps)
        if let quality = job.quality {
            // Job quality is bitrate in kbps for audio
            lame_set_VBR(lameEncoder, vbr_off)
            lame_set_brate(lameEncoder, Int32(quality))
        } else {
            lame_set_VBR(lameEncoder, vbr_default)
            lame_set_VBR_q(lameEncoder, 2)
        }

        if channels == 1 {
            lame_set_mode(lameEncoder, MONO)
        } else {
            lame_set_mode(lameEncoder, JOINT_STEREO)
        }

        guard lame_init_params(lameEncoder) == 0 else {
            throw NativeAudioError.lameInitFailed
        }

        // Read PCM and encode
        let frameCapacity: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            throw NativeAudioError.encodingFailed
        }

        let mp3BufSize = Int(1.25 * Double(frameCapacity) + 7200)
        var mp3Buffer = [UInt8](repeating: 0, count: mp3BufSize)

        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        guard let fileHandle = FileHandle(forWritingAtPath: outputURL.path) else {
            throw NativeAudioError.encodingFailed
        }
        defer { fileHandle.closeFile() }

        while true {
            do {
                try audioFile.read(into: buffer)
            } catch {
                break
            }

            guard buffer.frameLength > 0 else { break }

            let frameCount = Int32(buffer.frameLength)
            let bytesWritten: Int32

            if channels == 1 {
                guard let samples = buffer.floatChannelData?[0] else {
                    throw NativeAudioError.encodingFailed
                }
                bytesWritten = lame_encode_buffer_ieee_float(
                    lameEncoder,
                    samples,
                    nil,
                    frameCount,
                    &mp3Buffer,
                    Int32(mp3BufSize)
                )
            } else {
                guard let leftChannel = buffer.floatChannelData?[0],
                      let rightChannel = buffer.floatChannelData?[1] else {
                    throw NativeAudioError.encodingFailed
                }
                bytesWritten = lame_encode_buffer_ieee_float(
                    lameEncoder,
                    leftChannel,
                    rightChannel,
                    frameCount,
                    &mp3Buffer,
                    Int32(mp3BufSize)
                )
            }

            if bytesWritten < 0 {
                throw NativeAudioError.encodingFailed
            }

            if bytesWritten > 0 {
                fileHandle.write(Data(bytes: mp3Buffer, count: Int(bytesWritten)))
            }
        }

        // Flush remaining MP3 data
        let flushed = lame_encode_flush(lameEncoder, &mp3Buffer, Int32(mp3BufSize))
        if flushed > 0 {
            fileHandle.write(Data(bytes: mp3Buffer, count: Int(flushed)))
        }
    }

    /// Decodes any audio/video input to a temporary WAV file using AVAssetExportSession + AVAssetReader.
    private func decodeToPCM(job: ConversionJob) async throws -> URL {
        let asset = AVAsset(url: job.inputURL)

        // Check if input is already a WAV/PCM file we can read directly
        let inputExt = job.inputURL.pathExtension.lowercased()
        let directReadFormats: Set<String> = ["wav", "aiff", "aif", "caf"]
        if directReadFormats.contains(inputExt) && job.trimRange == nil {
            return job.inputURL
        }

        // For other formats, export to M4A first then decode
        // (AVAudioFile can read M4A/AAC natively)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_audio_decode", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let shortID = UUID().uuidString.prefix(8)
        let tempM4A = tempDir.appendingPathComponent("decode_\(shortID).m4a")
        let tempWAV = tempDir.appendingPathComponent("decode_\(shortID).wav")

        // Export to M4A (handles any input format + trim)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw NativeAudioError.exportSessionCreationFailed
        }

        exportSession.outputURL = tempM4A
        exportSession.outputFileType = .m4a

        if let trim = job.trimRange {
            let start = CMTime(seconds: trim.lowerBound, preferredTimescale: 600)
            let end = CMTime(seconds: trim.upperBound, preferredTimescale: 600)
            exportSession.timeRange = CMTimeRange(start: start, end: end)
        }

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw exportSession.error ?? NativeAudioError.exportFailed
        }

        // Convert M4A to WAV for LAME (needs PCM input)
        let sourceFile = try AVAudioFile(forReading: tempM4A)
        let pcmFormat = sourceFile.processingFormat
        let frameCount = AVAudioFrameCount(sourceFile.length)

        guard let wavSettings = pcmFormat.settings as? [String: Any] else {
            throw NativeAudioError.encodingFailed
        }

        let wavFile = try AVAudioFile(
            forWriting: tempWAV,
            settings: wavSettings,
            commonFormat: pcmFormat.commonFormat,
            interleaved: pcmFormat.isInterleaved
        )

        let bufferSize: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: bufferSize) else {
            throw NativeAudioError.encodingFailed
        }

        while sourceFile.framePosition < sourceFile.length {
            try sourceFile.read(into: buffer)
            try wavFile.write(from: buffer)
        }

        // Clean up temp M4A
        try? FileManager.default.removeItem(at: tempM4A)

        return tempWAV
    }

    // MARK: - Helpers

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

enum NativeAudioError: Error, LocalizedError {
    case exportSessionCreationFailed
    case exportFailed
    case exportCancelled
    case lameInitFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Failed to create audio export session"
        case .exportFailed:
            return "Audio export failed"
        case .exportCancelled:
            return "Audio export was cancelled"
        case .lameInitFailed:
            return "Failed to initialize MP3 encoder"
        case .encodingFailed:
            return "MP3 encoding failed"
        }
    }
}
