import Foundation

/// Routes conversion jobs to the appropriate engine based on format support.
/// Engines are checked in order — the first engine that can handle the job wins.
final class ConversionCoordinator {

    private let engines: [ConversionEngine]

    init() {
        self.engines = [
            NativeImageEngine(),       // HEIC, WEBP via iOS native APIs
            FFmpegConversionEngine(),  // Everything else via FFmpeg
        ]
    }

    func convert(job: ConversionJob) async throws -> ConversionResult {
        let inputExtension = job.inputURL.pathExtension

        for engine in engines {
            if engine.canConvert(from: inputExtension, to: job.outputFormat) {
                return try await engine.convert(job: job)
            }
        }

        throw ConversionError.unsupportedFormat(job.outputFormat.displayName)
    }
}
