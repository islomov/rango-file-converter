import SwiftUI
import PhotosUI

@Observable
final class ImageConverterViewModel {
    var selectedImage: UIImage?
    var selectedFileName: String = ""
    var history: [ConversionRecord] = []

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

    private func loadPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        selectedImage = image
        selectedFileName = "Photo Library Image"
        showConversionDetail = true
    }

    func handleFileImport(result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return }
        selectedImage = image
        selectedFileName = url.lastPathComponent
        showConversionDetail = true
    }

    func addToHistory(targetFormat: ImageFormat) {
        guard let image = selectedImage else { return }

        let sourceExt = selectedFileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"
        let thumbnail = image.preparingThumbnail(of: CGSize(width: 80, height: 80))

        let record = ConversionRecord(
            sourceFileName: selectedFileName,
            sourceFormat: sourceExt,
            targetFormat: targetFormat,
            thumbnail: thumbnail,
            status: .pending
        )

        history.insert(record, at: 0)
        selectedImage = nil
        selectedFileName = ""
    }
}
