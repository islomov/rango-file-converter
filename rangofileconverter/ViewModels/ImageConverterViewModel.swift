import SwiftUI

@Observable
final class ImageConverterViewModel {
    var selectedImage: UIImage?
    var selectedFileName: String = ""
    var selectedFileURL: URL?
    var history: [ConversionRecord] = []
    var isConverting = false

    var showConversionDetail = false

    private let coordinator = ConversionCoordinator()

    func selectImage(_ image: UIImage, fileName: String, fileURL: URL) {
        selectedImage = image
        selectedFileName = fileName
        selectedFileURL = fileURL
        showConversionDetail = true
    }

    func addHistoryRecord(fileName: String, thumbnail: UIImage?, outputURL: URL) {
        let ext = fileName.components(separatedBy: ".").last ?? "png"
        let format = FormatRegistry.format(forExtension: ext)
            ?? FormatRegistry.imageFormats[2] // PNG fallback

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: ext.uppercased(),
            targetFormat: format,
            thumbnail: thumbnail?.preparingThumbnail(of: CGSize(width: 80, height: 80)),
            status: .converted,
            outputURL: outputURL
        )
        history.insert(record, at: 0)
    }

    func convert(to format: FormatDefinition) async {
        guard let inputURL = selectedFileURL else { return }

        isConverting = true

        let sourceExt = selectedFileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let thumbnail = selectedImage?.preparingThumbnail(of: CGSize(width: 80, height: 80))

        let record = ConversionRecord(
            sourceFileName: selectedFileName,
            sourceFormat: sourceExt,
            targetFormat: format,
            thumbnail: thumbnail,
            status: .converting
        )
        history.insert(record, at: 0)

        do {
            let job = ConversionJob(inputURL: inputURL, outputFormat: format)
            let result = try await coordinator.convert(job: job)

            history[0].status = .converted
            history[0].outputURL = result.outputURL
        } catch {
            history[0].status = .failed
            history[0].errorMessage = error.localizedDescription
        }

        isConverting = false
        selectedImage = nil
        selectedFileName = ""
        selectedFileURL = nil
    }
}
