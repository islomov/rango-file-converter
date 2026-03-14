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
            }
        }
        .navigationBarHidden(true)
        .task {
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

    // MARK: - Navigation Bar

    private var navBar: some View {
        ZStack {
            Text("Select Audio")
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
            ForEach(AudioPickerSource.allCases, id: \.self) { source in
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
                        Text("Select a video to extract its audio")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)

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
            isDisabled: isLoading
        ) {
            selectAsset(asset)
        }
    }

    // MARK: - Files Placeholder

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
                    Text("Browse audio or video files")
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

        isLoading = true
        let fileName = sourceURL.lastPathComponent

        Task.detached(priority: .userInitiated) {
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("rango_audio_import", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let destURL = tempDir.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: destURL)

            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                await MainActor.run {
                    isLoading = false
                    onAudioSelected(fileName, destURL)
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
