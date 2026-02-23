import Foundation

/// Describes a conversion job with all parameters.
struct ConversionJob: Identifiable {
    let id = UUID()
    let inputURL: URL
    let outputFormat: FormatDefinition

    // Optional transformations
    var scale: CGSize?
    var cropRect: CGRect?
    var trimRange: ClosedRange<TimeInterval>?
    var quality: Int?
    var progressFilePath: String?
    var fps: Int?
}

/// Result of a completed conversion.
struct ConversionResult {
    let job: ConversionJob
    let outputURL: URL
    let duration: TimeInterval
    let outputFileSize: Int64
}

/// Protocol that conversion engines conform to.
protocol ConversionEngine {
    var supportedMediaTypes: Set<MediaType> { get }
    func canConvert(from inputExtension: String, to outputFormat: FormatDefinition) -> Bool
    func convert(job: ConversionJob) async throws -> ConversionResult
}
