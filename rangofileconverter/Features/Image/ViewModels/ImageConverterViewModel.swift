import SwiftUI
import Combine

final class ImageConverterViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var selectedFileName: String = ""
    @Published var selectedFileURL: URL?
    @Published var isConverting = false
    @Published var showConversionDetail = false

    private let coordinator = ConversionCoordinator()
    private let store = HistoryStore.shared

    func selectImage(_ image: UIImage, fileName: String, fileURL: URL) {
        selectedImage = image
        selectedFileName = fileName
        selectedFileURL = fileURL
        showConversionDetail = true
    }

    func addHistoryRecord(fileName: String, thumbnail: UIImage?, outputURL: URL, toolType: String = "Convert") {
        let ext = fileName.components(separatedBy: ".").last ?? "png"
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
            toolType: toolType
        )

        store.add(record)
    }

    func convert(to format: FormatDefinition) async {
        guard let inputURL = selectedFileURL else { return }

        await MainActor.run { isConverting = true }

        let sourceExt = selectedFileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let thumbnailData = selectedImage?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)

        let record = ConversionRecord(
            sourceFileName: selectedFileName,
            sourceFormat: sourceExt,
            targetFormatID: format.id,
            thumbnailData: thumbnailData,
            status: .converting
        )

        await MainActor.run { store.add(record) }

        do {
            let job = ConversionJob(inputURL: inputURL, outputFormat: format)
            let result = try await coordinator.convert(job: job)

            let outputPath = ConversionRecord.persistOutput(from: result.outputURL)
            await MainActor.run {
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
            selectedImage = nil
            selectedFileName = ""
            selectedFileURL = nil
        }
    }
}
