import SwiftUI
import Photos
import Combine

/// Shared thumbnail cache backed by NSCache (thread-safe, no @Published overhead).
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()
    private let imageManager = PHCachingImageManager()
    let thumbnailSize = CGSize(width: 200, height: 200)

    private init() {
        cache.countLimit = 300
    }

    func image(for identifier: String) -> UIImage? {
        cache.object(forKey: identifier as NSString)
    }

    func store(_ image: UIImage, for identifier: String) {
        cache.setObject(image, forKey: identifier as NSString)
    }

    func requestThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
}

/// Per-cell ObservableObject that loads a single thumbnail.
/// Only this cell re-renders when its thumbnail arrives.
final class ThumbnailLoader: ObservableObject {
    @Published var image: UIImage?
    private let asset: PHAsset

    init(asset: PHAsset) {
        self.asset = asset
        // Check cache immediately
        if let cached = ThumbnailCache.shared.image(for: asset.localIdentifier) {
            self.image = cached
        }
    }

    func loadIfNeeded() {
        guard image == nil else { return }

        // Double-check cache (may have been populated since init)
        if let cached = ThumbnailCache.shared.image(for: asset.localIdentifier) {
            self.image = cached
            return
        }

        ThumbnailCache.shared.requestThumbnail(for: asset) { [weak self] loadedImage in
            guard let self, let loadedImage else { return }
            ThumbnailCache.shared.store(loadedImage, for: self.asset.localIdentifier)
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
}

/// Standalone thumbnail cell for photo assets.
/// Uses its own @StateObject so only this cell re-renders on thumbnail load.
struct AssetThumbnailCell: View {
    let asset: PHAsset
    let isMultiSelect: Bool
    let isSelected: Bool
    let selectionIndex: Int?
    let isDisabled: Bool
    let onTap: () -> Void

    @StateObject private var loader: ThumbnailLoader

    init(
        asset: PHAsset,
        isMultiSelect: Bool = false,
        isSelected: Bool = false,
        selectionIndex: Int? = nil,
        isDisabled: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.asset = asset
        self.isMultiSelect = isMultiSelect
        self.isSelected = isSelected
        self.selectionIndex = selectionIndex
        self.isDisabled = isDisabled
        self.onTap = onTap
        _loader = StateObject(wrappedValue: ThumbnailLoader(asset: asset))
    }

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geo in
                ZStack(alignment: .topTrailing) {
                    if let thumbnail = loader.image {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(AppColors.placeholder)
                            .frame(width: geo.size.width, height: geo.size.width)
                    }

                    if isMultiSelect {
                        ZStack {
                            Circle()
                                .fill(isSelected ? AppColors.accent : Color.black.opacity(0.3))
                                .frame(width: 26, height: 26)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 26, height: 26)
                            if isSelected, let selectionIndex {
                                Text("\(selectionIndex)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(isDisabled)
        .onAppear {
            loader.loadIfNeeded()
        }
    }
}

/// Standalone thumbnail cell for video assets (includes duration overlay).
struct VideoThumbnailCell: View {
    let asset: PHAsset
    let isMultiSelect: Bool
    let isSelected: Bool
    let selectionIndex: Int?
    let isDisabled: Bool
    let onTap: () -> Void

    @StateObject private var loader: ThumbnailLoader

    init(
        asset: PHAsset,
        isMultiSelect: Bool = false,
        isSelected: Bool = false,
        selectionIndex: Int? = nil,
        isDisabled: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.asset = asset
        self.isMultiSelect = isMultiSelect
        self.isSelected = isSelected
        self.selectionIndex = selectionIndex
        self.isDisabled = isDisabled
        self.onTap = onTap
        _loader = StateObject(wrappedValue: ThumbnailLoader(asset: asset))
    }

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geo in
                ZStack {
                    if let thumbnail = loader.image {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(AppColors.placeholder)
                            .frame(width: geo.size.width, height: geo.size.width)
                    }

                    // Duration badge (bottom-leading)
                    VStack {
                        Spacer()
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 8))
                                Text(formattedDuration(asset.duration))
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.6), in: Capsule())
                            Spacer()
                        }
                        .padding(4)
                    }

                    // Selection indicator (top-trailing)
                    if isMultiSelect {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? AppColors.accent : Color.black.opacity(0.3))
                                        .frame(width: 26, height: 26)
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 26, height: 26)
                                    if isSelected, let selectionIndex {
                                        Text("\(selectionIndex)")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(isDisabled)
        .onAppear {
            loader.loadIfNeeded()
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
