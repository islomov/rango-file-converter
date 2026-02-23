import SwiftUI
import Photos
import UniformTypeIdentifiers
import AVFoundation

private enum VideoSource: String, CaseIterable {
    case gallery = "Gallery"
    case files = "Files"
}

struct VideoPickerView: View {
    var onVideoSelected: (UIImage, String, URL) -> Void

    @StateObject private var videoVM = VideoLibraryViewModel()
    @State private var selectedSource: VideoSource = .gallery
    @State private var showFilePicker = false
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        VStack(spacing: 0) {
            content
            sourceBar
        }
        .navigationTitle("Select Video")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            videoVM.requestAccessAndFetch()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.movie, UTType.video, UTType.mpeg4Movie, UTType.quickTimeMovie, UTType.avi],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Loading video...")
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
            selectAsset(asset)
        } label: {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
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
                    }

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
                    .padding(4)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .onAppear {
                videoVM.loadThumbnail(for: asset)
            }
        }
        .disabled(isLoading)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var sourceBar: some View {
        HStack(spacing: 0) {
            ForEach(VideoSource.allCases, id: \.self) { source in
                Button {
                    selectedSource = source
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: source == .gallery ? "photo.on.rectangle" : "folder")
                            .font(.title3)
                        Text(source.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(selectedSource == source ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.top, 4)
        .background(.bar)
    }

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

    // MARK: - Selection

    private func selectAsset(_ asset: PHAsset) {
        isLoading = true
        Task {
            if let (thumbnail, fileName, url) = await videoVM.loadFullVideo(for: asset) {
                isLoading = false
                onVideoSelected(thumbnail, fileName, url)
            } else {
                isLoading = false
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tempURL)
        guard (try? FileManager.default.copyItem(at: url, to: tempURL)) != nil else { return }

        let thumbnail = VideoLibraryViewModel.generateThumbnail(from: tempURL)
            ?? UIImage(systemName: "video")!

        onVideoSelected(thumbnail, url.lastPathComponent, tempURL)
    }
}
