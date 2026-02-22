import SwiftUI
import PhotosUI

@Observable
final class ImageConverterViewModel {
    var selectedImage: UIImage?
    var selectedFileName: String = ""
    var selectedFileURL: URL?
    var history: [ConversionRecord] = []
    var isConverting = false

    var showFilePicker = false
    var showConversionDetail = false

    var selectedPhotoItem: PhotosPickerItem? {
        didSet {
            if let item = selectedPhotoItem {
                Task {
                    await loadPhoto(from: item)
                }
            }
        }
    }

    private let coordinator = ConversionCoordinator()

    private func loadPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        // Write to temp file so FFmpeg can access it
        let fileName = "photo_\(UUID().uuidString.prefix(8)).jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)

        selectedImage = image
        selectedFileName = fileName
        selectedFileURL = tempURL
        showConversionDetail = true
    }

    func handleFileImport(result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        // Copy to temp directory so FFmpeg can access it after the security scope closes
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tempURL)
        guard (try? FileManager.default.copyItem(at: url, to: tempURL)) != nil else { return }

        guard let data = try? Data(contentsOf: tempURL),
              let image = UIImage(data: data) else { return }
        selectedImage = image
        selectedFileName = url.lastPathComponent
        selectedFileURL = tempURL
        showConversionDetail = true
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
