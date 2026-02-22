import SwiftUI
import SwiftData

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

        do {
            let job = ConversionJob(inputURL: inputURL, outputFormat: format)
            let result = try await coordinator.convert(job: job)

            let outputPath = ConversionRecord.persistOutput(from: result.outputURL)
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
}
