import Foundation

enum RatioFitMode: String, CaseIterable {
    case crop = "Crop"
    case pad = "Pad"
}

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
    var stripVideo: Bool = false
    var aspectRatio: (width: Int, height: Int)?
    var ratioFitMode: RatioFitMode = .crop
    /// Normalized crop position (0...1). 0.5,0.5 = centered. Only used with aspectRatio + crop mode.
    var cropPosition: CGPoint?
    /// Crop scale factor (0...1). 1.0 = maximum crop size. Only used with aspectRatio + crop mode.
    var cropScale: CGFloat?
    /// Audio speed multiplier (e.g. 0.5 = half speed, 2.0 = double speed). Uses atempo filter.
    var speedMultiplier: Double?
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
    /// Check if the engine can handle this specific job's parameters (speed, trim, etc.).
    /// Default returns true. Override to decline jobs with unsupported parameters.
    func canHandle(job: ConversionJob) -> Bool
    func convert(job: ConversionJob) async throws -> ConversionResult
}

extension ConversionEngine {
    func canHandle(job: ConversionJob) -> Bool { true }
}
