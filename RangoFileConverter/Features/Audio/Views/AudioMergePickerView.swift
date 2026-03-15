import SwiftUI
import Photos
import UniformTypeIdentifiers
import AVFoundation

private enum AudioMergeSource: String, CaseIterable {
    case gallery = "Gallery"
    case files = "Files"
}

struct AudioMergePickerView: View {
    var onAudiosSelected: ([(fileName: String, url: URL)]) -> Void

    @StateObject private var videoVM = VideoLibraryViewModel()
    @State private var selectedSource: AudioMergeSource = .gallery
    @State private var showFilePicker = false
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAssetIDs: Set<String> = []
    @State private var selectionOrderList: [String] = []

    private let minCount = 2

    private static let fileAllowedTypes: [UTType] = [
        .audio, .mp3, .wav, .aiff, .mpeg4Audio,
        .movie, .video, .mpeg4Movie, .quickTimeMovie, .avi
    ]

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
            allowedContentTypes: Self.fileAllowedTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Loading \(selectedAssetIDs.count) files...")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
    }

    // MARK: - Navigation Bar

    private var navBar: some View {
        ZStack {
            Text("Select Audios")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
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
            ForEach(AudioMergeSource.allCases, id: \.self) { source in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSource = source
                    }
                } label: {
                    Text(LocalizedStringKey(source.rawValue))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedSource == source ? .white : AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .contentShape(Rectangle())
                        .background(
                            Group {
                                if selectedSource == source {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppColors.accent)
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
                onAudiosSelected(results.map { (fileName: $0.1, url: $0.2) })
            }
        }
    }

    // MARK: - Files

    private var filesPlaceholder: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.10))
                        .frame(width: 80, height: 80)
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }

                VStack(spacing: 8) {
                    Text("Browse audio or video files to merge")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .multilineTextAlignment(.center)

                    Text("Video files will have their audio extracted automatically")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Button {
                showFilePicker = true
            } label: {
                Text("Open File Browser")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .padding(16)
                    .frame(width: 200)
                    .background(
                        LinearGradient(
                            colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Spacer()
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, urls.count >= minCount else { return }

        isLoading = true
        let min = minCount

        Task.detached(priority: .userInitiated) {
            var results: [(fileName: String, url: URL)] = []
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("rango_audio_merge_import", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                guard (try? FileManager.default.copyItem(at: url, to: tempURL)) != nil else { continue }

                results.append((fileName: url.lastPathComponent, url: tempURL))
            }
            await MainActor.run {
                isLoading = false
                if results.count >= min {
                    onAudiosSelected(results)
                }
            }
        }
    }
}
