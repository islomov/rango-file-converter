import SwiftUI
import SwiftData

@Observable
final class ImageConverterViewModel {
    var selectedImage: UIImage?
    var selectedFileName: String = ""
    var selectedFileURL: URL?
    var isConverting = false

    var showConversionDetail = false

    private let coordinator = ConversionCoordinator()

    func selectImage(_ image: UIImage, fileName: String, fileURL: URL) {
        selectedImage = image
        selectedFileName = fileName
        selectedFileURL = fileURL
        showConversionDetail = true
    }

    func addHistoryRecord(fileName: String, thumbnail: UIImage?, outputURL: URL, toolType: String = "Convert", context: ModelContext) {
        print("[History] addHistoryRecord called — fileName: \(fileName), toolType: \(toolType)")
        print("[History] outputURL: \(outputURL)")

        let ext = fileName.components(separatedBy: ".").last ?? "png"
        let formatDef = FormatRegistry.format(forExtension: ext)

        let outputPath = ConversionRecord.persistOutput(from: outputURL)
        print("[History] persistOutput returned: \(String(describing: outputPath))")

        let thumbnailData = thumbnail?
            .preparingThumbnail(of: CGSize(width: 80, height: 80))?
            .jpegData(compressionQuality: 0.8)
        print("[History] thumbnailData size: \(thumbnailData?.count ?? 0)")

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: ext.uppercased(),
            targetFormatID: formatDef?.id ?? ext.lowercased(),
            thumbnailData: thumbnailData,
            status: .converted,
            outputPath: outputPath,
            toolType: toolType
        )

        context.insert(record)
        print("[History] record inserted into context")

        do {
            try context.save()
            print("[History] context.save() succeeded")

            // Verify: fetch all records to confirm it's queryable
            let descriptor = FetchDescriptor<ConversionRecord>()
            let allRecords = try context.fetch(descriptor)
            print("[History] Total records in store after save: \(allRecords.count)")
            for r in allRecords {
                print("[History]   - \(r.sourceFileName) | \(r.toolType) | \(r.statusRaw)")
            }
        } catch {
            print("[History] context.save() FAILED: \(error)")
        }
    }

    func convert(to format: FormatDefinition, context: ModelContext) async {
        guard let inputURL = selectedFileURL else { return }

        isConverting = true

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
        selectedImage = nil
        selectedFileName = ""
        selectedFileURL = nil
    }
}
