import SwiftUI
import Photos
import UniformTypeIdentifiers
import AVFoundation

private enum VideoMergeSource: String, CaseIterable {
    case gallery = "Gallery"
    case files = "Files"
}

struct VideoMergePickerView: View {
    var onVideosSelected: ([(UIImage, String, URL)]) -> Void

    @StateObject private var videoVM = VideoLibraryViewModel()
    @State private var selectedSource: VideoMergeSource = .gallery
    @State private var showFilePicker = false
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    // Multi-select state
    @State private var selectedAssetIDs: Set<String> = []
    @State private var selectionOrderList: [String] = []

    private let minCount = 2

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                sourceToggle
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                content

                multiSelectBar
            }
        }
        .navigationBarHidden(true)
        .task {
            videoVM.requestAccessAndFetch()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.movie, UTType.video, UTType.mpeg4Movie, UTType.quickTimeMovie, UTType.avi],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Loading \(selectedAssetIDs.count) videos...")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
    }

    // MARK: - Navigation Bar

    private var navBar: some View {
        ZStack {
            Text("Select Videos")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                }

                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - Source Toggle

    private var sourceToggle: some View {
        HStack(spacing: 0) {
            ForEach(VideoMergeSource.allCases, id: \.self) { source in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSource = source
                    }
                } label: {
                    Text(LocalizedStringKey(source.rawValue))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Group {
                                if selectedSource == source {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppColors.surface)
                                        .shadow(color: AppColors.textPrimary.opacity(0.12), radius: 4, x: 0, y: 0)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedSource {
        case .gallery:
            galleryGrid
        case .files:
            filesPlaceholder
        }
    }

    private var galleryGrid: some View {
        Group {
            switch videoVM.authorizationStatus {
            case .authorized, .limited:
                if videoVM.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if videoVM.assetCount == 0 {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("No videos found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(0..<videoVM.assetCount, id: \.self) { index in
                                if let asset = videoVM.asset(at: index) {
                                    thumbnailCell(for: asset)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            case .denied, .restricted:
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Photo access denied")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            default:
                Spacer()
                ProgressView("Requesting access...")
                Spacer()
            }
        }
    }

    private func thumbnailCell(for asset: PHAsset) -> some View {
        VideoThumbnailCell(
            asset: asset,
            isMultiSelect: true,
            isSelected: selectedAssetIDs.contains(asset.localIdentifier),
            selectionIndex: selectionOrder(for: asset),
            isDisabled: isLoading
        ) {
            toggleSelection(asset)
        }
    }

    // MARK: - Multi-select

    private func toggleSelection(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
            selectionOrderList.removeAll { $0 == id }
        } else {
            selectedAssetIDs.insert(id)
            selectionOrderList.append(id)
        }
    }

    private func selectionOrder(for asset: PHAsset) -> Int? {
        guard let idx = selectionOrderList.firstIndex(of: asset.localIdentifier) else { return nil }
        return idx + 1
    }

    // MARK: - Multi-select Bar

    private var multiSelectBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)
            HStack {
                Text("\(selectedAssetIDs.count) selected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                Spacer()

                Button {
                    loadSelectedAndFinish()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: selectedAssetIDs.count >= minCount
                                    ? [AppColors.buttonGradientStart, AppColors.buttonGradientEnd]
                                    : [AppColors.buttonDisabledStart, AppColors.buttonDisabledMid, AppColors.buttonDisabledStart],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedAssetIDs.count < minCount || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(AppColors.surface)
        }
    }

    private func loadSelectedAndFinish() {
        let orderedAssets: [PHAsset] = selectionOrderList.compactMap { id in
            let opts = PHFetchOptions()
            opts.predicate = NSPredicate(format: "localIdentifier == %@", id)
            return PHAsset.fetchAssets(with: opts).firstObject
        }
        guard orderedAssets.count >= minCount else { return }

        isLoading = true
        Task {
            let results = await videoVM.loadFullVideos(for: orderedAssets)
            isLoading = false
            if results.count >= minCount {
                onVideosSelected(results)
            }
        }
    }

    // MARK: - Files

    private var filesPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Browse video files on your device")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Open File Browser") {
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, urls.count >= minCount else { return }

        isLoading = true
        let min = minCount

        Task.detached(priority: .userInitiated) {
            var results: [(UIImage, String, URL)] = []
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                guard (try? FileManager.default.copyItem(at: url, to: tempURL)) != nil else { continue }

                let thumbnail = VideoLibraryViewModel.generateThumbnail(from: tempURL)
                    ?? UIImage(systemName: "video")!
                results.append((thumbnail, url.lastPathComponent, tempURL))
            }
            await MainActor.run {
                isLoading = false
                if results.count >= min {
                    onVideosSelected(results)
                }
            }
        }
    }
}
