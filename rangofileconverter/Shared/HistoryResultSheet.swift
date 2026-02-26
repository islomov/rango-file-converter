import SwiftUI
import Photos
import AVFoundation
import AVKit
import Combine
import QuickLook

struct HistoryResultSheet: View {
    @ObservedObject var record: ConversionRecord
    @EnvironmentObject private var historyStore: HistoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveSuccess = false
    @State private var saveError: String?
    @State private var audioPlayer: AVPlayer?
    @State private var isPlayingAudio = false
    @State private var outputImage: UIImage?
    @State private var previewTooLarge = false
    @State private var fileSize: String?
    @State private var fileDimensions: String?
    @State private var fileDuration: String?
    @State private var fileInfoTask: Task<Void, Never>?
    @State private var imageLoadTask: Task<Void, Never>?
    @State private var quickLookURL: URL?

    var body: some View {
        VStack(spacing: 20) {
            grabHandle

            headerSection

            Divider()

            switch record.status {
            case .pending, .converting:
                convertingContent
            case .converted:
                convertedContent
            case .failed:
                failedContent
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .presentationDetents([.medium, .large])
        .quickLookPreview($quickLookURL)
        .onDisappear {
            audioPlayer?.pause()
            audioPlayer = nil
            fileInfoTask?.cancel()
            fileInfoTask = nil
            imageLoadTask?.cancel()
            imageLoadTask = nil
        }
        .alert("Saved", isPresented: $showSaveSuccess) {
            Button("OK") { }
        } message: {
            Text("File saved to Photos successfully.")
        }
        .alert("Save Failed", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError ?? "Unknown error")
        }
    }

    // MARK: - Header

    private var grabHandle: some View {
        Capsule()
            .fill(.quaternary)
            .frame(width: 36, height: 5)
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            if let thumbnail = record.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: headerPlaceholderIcon)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.sourceFileName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(record.toolType)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(toolColor, in: Capsule())

                    Text("\(record.sourceFormat) → \(record.targetFormat.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Converting

    private var convertingContent: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: record.progress)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: record.progress)

                if record.progress > 0 {
                    Text("\(Int(record.progress * 100))%")
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(.blue)
                } else {
                    ProgressView()
                }
            }

            Text(record.progress > 0 ? "Converting..." : "Starting...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                ConversionTaskManager.shared.cancel(id: record.id)
                record.status = .failed
                record.errorMessage = "Cancelled by user"
                historyStore.save()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Converted

    private var convertedContent: some View {
        VStack(spacing: 16) {
            if let outputURL = record.outputURL {
                assetPreview(url: outputURL)

                fileInfoSection(url: outputURL)

                HStack(spacing: 12) {
                    if isDocumentOutput(url: outputURL) {
                        Button {
                            openWithSystemApp(url: outputURL)
                        } label: {
                            actionButton(title: "Open", icon: "arrow.up.forward.app", color: .blue)
                        }
                    } else {
                        Button {
                            saveToPhotos(url: outputURL)
                        } label: {
                            actionButton(title: "Save", icon: "square.and.arrow.down", color: .blue)
                        }
                    }

                    ShareLink(item: outputURL) {
                        actionButton(title: "Share", icon: "square.and.arrow.up", color: .orange)
                    }

                    Button(role: .destructive) {
                        historyStore.remove(record)
                        dismiss()
                    } label: {
                        actionButton(title: "Delete", icon: "trash", color: .red)
                    }
                }
            }
        }
        .onAppear { loadFileInfo() }
    }

    // MARK: - File Info

    private func fileInfoSection(url: URL) -> some View {
        VStack(spacing: 0) {
            infoRow(label: "Name", value: url.lastPathComponent)
            Divider()
            infoRow(label: "Format", value: record.targetFormat.displayName)
            if let fileSize = fileSize {
                Divider()
                infoRow(label: "Size", value: fileSize)
            }
            if let fileDimensions = fileDimensions {
                Divider()
                infoRow(label: "Resolution", value: fileDimensions)
            }
            if let fileDuration = fileDuration {
                Divider()
                infoRow(label: "Duration", value: fileDuration)
            }
            Divider()
            infoRow(label: "Location", value: url.deletingLastPathComponent().lastPathComponent + "/")
        }
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func loadFileInfo() {
        guard let outputURL = record.outputURL else { return }

        // Dimensions & duration from AVAsset (works for video and audio)
        let asset = AVAsset(url: outputURL)
        fileInfoTask = Task.detached(priority: .userInitiated) {
            // File size (moved off main thread)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
               let bytes = attrs[.size] as? Int64 {
                let formatted = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                await MainActor.run { fileSize = formatted }
            }
            guard !Task.isCancelled else { return }
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                guard !Task.isCancelled else { return }
                if let size = try? await track.load(.naturalSize) {
                    let w = Int(abs(size.width))
                    let h = Int(abs(size.height))
                    await MainActor.run { fileDimensions = "\(w) x \(h)" }
                }
            }
            guard !Task.isCancelled else { return }
            if let duration = try? await asset.load(.duration) {
                let seconds = CMTimeGetSeconds(duration)
                if seconds.isFinite && seconds > 0 {
                    let mins = Int(seconds) / 60
                    let secs = Int(seconds) % 60
                    await MainActor.run {
                        fileDuration = String(format: "%d:%02d", mins, secs)
                    }
                }
            }
        }
    }

    // MARK: - Asset Preview

    @ViewBuilder
    private func assetPreview(url: URL) -> some View {
        switch outputMediaType(for: url) {
        case .video:
            videoPreview(url: url)
        case .image:
            imagePreview(url: url)
        case .audio:
            audioPreview(url: url)
        case .document:
            documentPreview(url: url)
        }
    }

    @ViewBuilder
    private func videoPreview(url: URL) -> some View {
        if isAVPlayerCompatible(url) {
            VideoPlayerView(url: url)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            unsupportedPreview(icon: "video.fill", format: url.pathExtension.uppercased())
        }
    }

    @ViewBuilder
    private func imagePreview(url: URL) -> some View {
        if url.pathExtension.lowercased() == "gif" {
            AnimatedGIFView(url: url)
                .frame(maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if previewTooLarge {
            tooLargePreview(url: url)
        } else {
            Group {
                if let image = outputImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .frame(height: 180)
                        .overlay { ProgressView() }
                }
            }
            .onAppear { loadImage(url: url) }
        }
    }

    private func tooLargePreview(url: URL) -> some View {
        VStack(spacing: 8) {
            if let thumbnail = record.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            Text("File too large to preview")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func audioPreview(url: URL) -> some View {
        if isAVPlayerCompatible(url) {
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Button {
                    toggleAudioPlayback(url: url)
                } label: {
                    Label(isPlayingAudio ? "Pause" : "Play Audio", systemImage: isPlayingAudio ? "pause.fill" : "play.fill")
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.blue.opacity(0.1), in: Capsule())
                }
            }
            .padding(.vertical, 8)
            .onReceive(
                NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
                    .filter { [weak audioPlayer] notification in
                        guard let item = notification.object as? AVPlayerItem else { return false }
                        return item === audioPlayer?.currentItem
                    }
            ) { _ in
                isPlayingAudio = false
            }
        } else {
            unsupportedPreview(icon: "waveform", format: url.pathExtension.uppercased())
        }
    }

    // MARK: - Document Preview

    private func documentPreview(url: URL) -> some View {
        VStack(spacing: 12) {
            Image(systemName: documentIcon(for: url.pathExtension))
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text(url.pathExtension.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func documentIcon(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "html": return "globe"
        case "rtf": return "doc.text.fill"
        case "txt": return "doc.plaintext"
        case "odt": return "doc.text"
        default: return "doc"
        }
    }

    // MARK: - Audio Session

    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Audio Playback

    private func toggleAudioPlayback(url: URL) {
        activateAudioSession()
        if audioPlayer == nil {
            audioPlayer = AVPlayer(url: url)
        }
        guard let audioPlayer = audioPlayer else { return }

        if isPlayingAudio {
            audioPlayer.pause()
        } else {
            if let currentItem = audioPlayer.currentItem,
               currentItem.duration.isValid,
               CMTimeCompare(audioPlayer.currentTime(), currentItem.duration) >= 0 {
                audioPlayer.seek(to: .zero)
            }
            audioPlayer.play()
        }
        isPlayingAudio.toggle()
    }

    /// Max file size for preview (50 MB)
    private static let maxPreviewFileSize: Int64 = 50 * 1024 * 1024
    /// Max pixel area for preview (100 megapixels)
    private static let maxPreviewPixels: CGFloat = 100_000_000

    private func loadImage(url: URL) {
        imageLoadTask?.cancel()
        imageLoadTask = Task.detached(priority: .userInitiated) {
            // Check file size
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let bytes = attrs[.size] as? Int64,
               bytes > Self.maxPreviewFileSize {
                await MainActor.run { previewTooLarge = true }
                return
            }
            guard !Task.isCancelled else { return }

            // Check pixel dimensions
            let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else { return }

            if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
               let h = props[kCGImagePropertyPixelHeight] as? CGFloat,
               w * h > Self.maxPreviewPixels {
                await MainActor.run { previewTooLarge = true }
                return
            }
            guard !Task.isCancelled else { return }

            // Use ImageIO to downsample for preview, avoiding GPU memory limits
            let maxPixelSize: CGFloat = 1920
            let downsampleOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else { return }
            let image = UIImage(cgImage: cgImage)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                outputImage = image
            }
        }
    }

    private func isAVPlayerCompatible(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let supportedVideo: Set<String> = ["mp4", "mov", "m4v", "mpg", "mpeg", "3gp", "3g2", "ts"]
        let supportedAudio: Set<String> = ["mp3", "wav", "m4a", "aac", "aiff", "flac", "caf", "au", "mp2"]
        return supportedVideo.contains(ext) || supportedAudio.contains(ext)
    }

    private func unsupportedPreview(icon: String, format: String) -> some View {
        VStack(spacing: 8) {
            if let thumbnail = record.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            Text("Preview not available for \(format)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private enum OutputMediaType {
        case video, image, audio, document
    }

    private func outputMediaType(for url: URL) -> OutputMediaType {
        let ext = url.pathExtension.lowercased()
        let audioExtensions = Set(["mp3", "wav", "flac", "m4a", "aac", "ogg", "ac3", "wma", "amr",
                                    "opus", "aiff", "mp2", "gsm", "dts", "au", "caf", "wv", "oga",
                                    "w64", "voc", "snd", "spx", "ircam"])
        let imageExtensions = Set(["heic", "jpeg", "jpg", "png", "webp", "bmp", "tiff", "gif",
                                    "tga", "jp2", "pbm", "pgm", "exr", "pam", "pfm"])
        let documentExtensions = Set(["doc", "docx", "pdf", "html", "odt", "rtf", "txt"])

        if record.mediaCategory == "document" || documentExtensions.contains(ext) {
            return .document
        } else if audioExtensions.contains(ext) || record.toolType == "Extract Audio" {
            return .audio
        } else if imageExtensions.contains(ext) {
            return .image
        } else {
            return .video
        }
    }

    // MARK: - Failed

    private var failedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)

            Text("Conversion Failed")
                .font(.subheadline.weight(.medium))

            if let errorMessage = record.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                dismiss()
            } label: {
                Text("Dismiss")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Helpers

    private func actionButton(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
            Text(title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func isDocumentOutput(url: URL) -> Bool {
        outputMediaType(for: url) == .document
    }

    private func openWithSystemApp(url: URL) {
        quickLookURL = url
    }

    private func saveToPhotos(url: URL) {
        let ext = url.pathExtension.lowercased()
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "mpg", "mpeg", "3gp", "webm", "ts", "vob", "ogv"]
        let imageExtensions = ["heic", "jpeg", "jpg", "png", "webp", "bmp", "tiff", "gif"]

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    saveError = "Photo library access denied. Please allow access in Settings."
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                if videoExtensions.contains(ext) {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } else if imageExtensions.contains(ext) {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        showSaveSuccess = true
                    } else {
                        saveError = error?.localizedDescription ?? "Failed to save"
                    }
                }
            }
        }
    }

    private var headerPlaceholderIcon: String {
        switch record.mediaCategory {
        case "document": return "doc.text"
        case "video": return "video"
        case "audio": return "waveform"
        default: return "photo"
        }
    }

    private var toolColor: Color {
        switch record.toolType {
        case "Rotate": return .blue
        case "Compress": return .purple
        case "Resize": return .orange
        case "Crop": return .teal
        case "GIF": return .pink
        case "Stitch": return .mint
        case "Convert": return .blue
        case "Merge": return .indigo
        case "Split": return .teal
        case "Reorder": return .orange
        case "Protect": return .purple
        default: return .green
        }
    }
}

// MARK: - Video Player (AVPlayerViewController wrapper)

private struct VideoPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        controller.player = player
        controller.allowsPictureInPicturePlayback = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player?.pause()
        controller.player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Animated GIF View

private struct AnimatedGIFView: UIViewRepresentable {
    let url: URL

    private static let maxFrames = 150

    class Coordinator {
        var loadTask: Task<Void, Never>?
        weak var imageView: UIImageView?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.imageView = imageView
        let maxFrames = Self.maxFrames

        context.coordinator.loadTask = Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url),
                  let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }

            let count = min(CGImageSourceGetCount(source), maxFrames)
            var images: [UIImage] = []
            var totalDuration: Double = 0

            for i in 0..<count {
                guard !Task.isCancelled else { return }
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
                images.append(UIImage(cgImage: cgImage))

                if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
                   let gifProps = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                    let delay = (gifProps[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                        ?? (gifProps[kCGImagePropertyGIFDelayTime] as? Double)
                        ?? 0.1
                    totalDuration += delay
                } else {
                    totalDuration += 0.1
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run { [weak imageView] in
                imageView?.animationImages = images
                imageView?.animationDuration = totalDuration
                imageView?.animationRepeatCount = 0
                imageView?.startAnimating()
            }
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.loadTask?.cancel()
        coordinator.loadTask = nil
        coordinator.imageView?.stopAnimating()
        coordinator.imageView?.animationImages = nil
    }
}
