import SwiftUI
import Photos
import UniformTypeIdentifiers
import AVFoundation

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
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        VStack(spacing: 0) {
            content
            bottomBar
        }
        .navigationTitle("Select Audios")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
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
                } else if videoVM.assets.isEmpty {
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
                        Text("Select videos to extract and merge their audio")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)

                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(videoVM.assets, id: \.localIdentifier) { asset in
                                thumbnailCell(for: asset)
                            }
                        }
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
        Button {
            toggleSelection(asset)
        } label: {
            GeometryReader { geo in
                ZStack {
                    if let thumbnail = videoVM.thumbnails[asset.localIdentifier] {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(width: geo.size.width, height: geo.size.width)
                            .onAppear {
                                videoVM.loadThumbnail(for: asset)
                            }
                    }

                    // Duration badge
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

                    // Selection indicator
                    VStack {
                        HStack {
                            Spacer()
                            let isSelected = selectedAssetIDs.contains(asset.localIdentifier)
                            let idx = selectionOrder(for: asset)
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.mint : Color.black.opacity(0.3))
                                    .frame(width: 26, height: 26)
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 26, height: 26)
                                if isSelected, let idx {
                                    Text("\(idx)")
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
            .aspectRatio(1, contentMode: .fit)
        }
        .disabled(isLoading)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                HStack(spacing: 16) {
                    Button {
                        selectedSource = .gallery
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.body)
                            Text("Gallery")
                                .font(.caption2)
                        }
                        .foregroundStyle(selectedSource == .gallery ? .primary : .secondary)
                    }

                    Button {
                        selectedSource = .files
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "folder")
                                .font(.body)
                            Text("Files")
                                .font(.caption2)
                        }
                        .foregroundStyle(selectedSource == .files ? .primary : .secondary)
                    }
                }

                Spacer()

                Text("\(selectedAssetIDs.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Done") {
                    loadSelectedAndFinish()
                }
                .font(.headline)
                .disabled(selectedAssetIDs.count < minCount || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func loadSelectedAndFinish() {
        let orderedAssets = selectionOrderList.compactMap { id in
            videoVM.assets.first { $0.localIdentifier == id }
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
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Browse audio or video files to merge")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Video files will have their audio extracted automatically")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open File Browser") {
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, urls.count >= minCount else { return }

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
        if results.count >= minCount {
            onAudiosSelected(results)
        }
    }
}

private enum AudioMergeSource: String, CaseIterable {
    case gallery = "Gallery"
    case files = "Files"
}
