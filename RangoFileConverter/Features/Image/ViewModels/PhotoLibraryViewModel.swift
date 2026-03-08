import SwiftUI
import Combine
import Photos

final class PhotoLibraryViewModel: ObservableObject {
    @Published private(set) var fetchResult: PHFetchResult<PHAsset>?
    @Published var assetCount: Int = 0
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var isLoading = false

    private let imageManager = PHCachingImageManager()

    func asset(at index: Int) -> PHAsset? {
        guard let fetchResult, index < fetchResult.count else { return nil }
        return fetchResult.object(at: index)
    }

    deinit {
        imageManager.stopCachingImagesForAllAssets()
    }

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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

            let result = PHAsset.fetchAssets(with: options)
            DispatchQueue.main.async {
                self?.fetchResult = result
                self?.assetCount = result.count
                self?.isLoading = false
            }
        }
    }

    func loadFullImage(for asset: PHAsset) async -> (UIImage, String, URL)? {
        let rawData: (Data, String?)? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, _ in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (data, uti))
            }
        }
        guard let (imageData, uti) = rawData else { return nil }

        return await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: imageData) else { return nil }
            let ext = Self.fileExtension(for: uti) ?? "jpg"
            let fileName = "photo_\(UUID().uuidString.prefix(8)).\(ext)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try? imageData.write(to: tempURL)
            return (image, fileName, tempURL)
        }.value
    }

    func loadFullImages(for assets: [PHAsset]) async -> [(UIImage, String, URL)] {
        await withTaskGroup(of: (Int, UIImage, String, URL)?.self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    guard let (image, name, url) = await self.loadFullImage(for: asset) else { return nil }
                    return (index, image, name, url)
                }
            }
            var results: [(Int, UIImage, String, URL)] = []
            for await result in group {
                if let r = result { results.append(r) }
            }
            return results.sorted { $0.0 < $1.0 }.map { ($0.1, $0.2, $0.3) }
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
