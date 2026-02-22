import SwiftUI
import Photos

@Observable
final class PhotoLibraryViewModel {
    var assets: [PHAsset] = []
    var thumbnails: [String: UIImage] = [:]
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var isLoading = false

    private let imageManager = PHCachingImageManager()
    private let thumbnailSize = CGSize(width: 200, height: 200)

    func requestAccessAndFetch() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status

        if status == .authorized || status == .limited {
            fetchAssets()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                DispatchQueue.main.async {
                    self?.authorizationStatus = newStatus
                    if newStatus == .authorized || newStatus == .limited {
                        self?.fetchAssets()
                    }
                }
            }
        }
    }

    func fetchAssets() {
        isLoading = true
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            fetched.append(asset)
        }
        assets = fetched
        isLoading = false
    }

    func loadThumbnail(for asset: PHAsset) {
        let id = asset.localIdentifier
        guard thumbnails[id] == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            if let image {
                DispatchQueue.main.async {
                    self?.thumbnails[id] = image
                }
            }
        }
    }

    func loadFullImage(for asset: PHAsset) async -> (UIImage, String, URL)? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, _ in
                guard let data, let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }

                let ext = Self.fileExtension(for: uti) ?? "jpg"
                let fileName = "photo_\(UUID().uuidString.prefix(8)).\(ext)"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try? data.write(to: tempURL)

                continuation.resume(returning: (image, fileName, tempURL))
            }
        }
    }

    private static func fileExtension(for uti: String?) -> String? {
        guard let uti else { return nil }
        switch uti {
        case "public.jpeg": return "jpg"
        case "public.png": return "png"
        case "public.heic", "public.heif": return "heic"
        case "com.compuserve.gif": return "gif"
        case "public.tiff": return "tiff"
        case "com.microsoft.bmp": return "bmp"
        case "org.webmproject.webp": return "webp"
        default: return "jpg"
        }
    }
}
