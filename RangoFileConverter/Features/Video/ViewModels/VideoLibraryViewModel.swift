import SwiftUI
import Photos
import AVFoundation
import Combine

final class VideoLibraryViewModel: ObservableObject {
    @Published private(set) var fetchResult: PHFetchResult<PHAsset>?
    @Published var assetCount: Int = 0
    @Published var thumbnails: [String: UIImage] = [:]
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var isLoading = false

    private let imageManager = PHCachingImageManager()
    private let thumbnailSize = CGSize(width: 200, height: 200)
    private static let maxCachedThumbnails = 200

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
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)

            let result = PHAsset.fetchAssets(with: options)
            DispatchQueue.main.async {
                self?.fetchResult = result
                self?.assetCount = result.count
                self?.isLoading = false
            }
        }
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
                    guard let self else { return }
                    if self.thumbnails.count >= Self.maxCachedThumbnails {
                        self.thumbnails.removeAll(keepingCapacity: true)
                    }
                    self.thumbnails[id] = image
                }
            }
        }
    }

    func loadFullVideo(for asset: PHAsset) async -> (UIImage, String, URL)? {
        let fileInfo: (String, URL)? = await withCheckedContinuation { continuation in
            let resources = PHAssetResource.assetResources(for: asset)
            guard let videoResource = resources.first(where: { $0.type == .video })
                    ?? resources.first(where: { $0.type == .fullSizeVideo })
                    ?? resources.first else {
                continuation.resume(returning: nil)
                return
            }

            let ext = Self.fileExtension(for: videoResource.uniformTypeIdentifier)
                ?? videoResource.originalFilename.components(separatedBy: ".").last
                ?? "mp4"
            let fileName = "video_\(UUID().uuidString.prefix(8)).\(ext)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: tempURL)

            let writeOptions = PHAssetResourceRequestOptions()
            writeOptions.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().writeData(for: videoResource, toFile: tempURL, options: writeOptions) { error in
                if error != nil {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: (fileName, tempURL))
                }
            }
        }
        guard let (fileName, tempURL) = fileInfo else { return nil }

        let thumbnail = await Task.detached(priority: .userInitiated) {
            Self.generateThumbnail(from: tempURL) ?? UIImage(systemName: "video")!
        }.value

        return (thumbnail, fileName, tempURL)
    }

    static func generateThumbnail(from url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    func loadFullVideos(for assets: [PHAsset]) async -> [(UIImage, String, URL)] {
        await withTaskGroup(of: (Int, UIImage, String, URL)?.self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    guard let result = await self.loadFullVideo(for: asset) else { return nil }
                    return (index, result.0, result.1, result.2)
                }
            }

            var indexed: [(Int, UIImage, String, URL)] = []
            for await result in group {
                if let result { indexed.append(result) }
            }
            return indexed.sorted { $0.0 < $1.0 }.map { ($0.1, $0.2, $0.3) }
        }
    }

    private static func fileExtension(for uti: String?) -> String? {
        guard let uti else { return nil }
        switch uti {
        case "public.mpeg-4": return "mp4"
        case "com.apple.quicktime-movie": return "mov"
        case "public.avi": return "avi"
        case "public.mpeg": return "mpg"
        case "org.matroska.mkv": return "mkv"
        case "com.microsoft.windows-media-wmv": return "wmv"
        case "org.webmproject.webm": return "webm"
        case "public.3gpp": return "3gp"
        case "public.3gpp2": return "3g2"
        default: return nil
        }
    }
}
