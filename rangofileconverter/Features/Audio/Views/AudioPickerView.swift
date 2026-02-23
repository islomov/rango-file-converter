import SwiftUI
import Photos
import UniformTypeIdentifiers
import AVFoundation

private enum AudioPickerSource: String, CaseIterable {
    case gallery = "Gallery"
    case files = "Files"
}

struct AudioPickerView: View {
    let onAudioSelected: (String, URL) -> Void

    @StateObject private var videoVM = VideoLibraryViewModel()
    @State private var selectedSource: AudioPickerSource = .gallery
    @State private var showFilePicker = false
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

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
            sourceBar
        }
        .navigationTitle("Select Audio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            videoVM.requestAccessAndFetch()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: Self.fileAllowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Loading...")
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
                        Text("Select a video to extract its audio")
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
            ForEach(AudioPickerSource.allCases, id: \.self) { source in
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
            Image(systemName: "waveform.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Browse audio or video files")
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

    // MARK: - Selection

    private func selectAsset(_ asset: PHAsset) {
        isLoading = true
        Task {
            if let (_, fileName, url) = await videoVM.loadFullVideo(for: asset) {
                isLoading = false
                onAudioSelected(fileName, url)
            } else {
                isLoading = false
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let sourceURL = urls.first else { return }
        guard sourceURL.startAccessingSecurityScopedResource() else { return }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let fileName = sourceURL.lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_audio_import", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destURL = tempDir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destURL)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            onAudioSelected(fileName, destURL)
        } catch {
            // File copy failed
        }
    }
}
