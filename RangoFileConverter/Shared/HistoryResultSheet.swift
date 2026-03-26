import SwiftUI
import Photos
import AVFoundation
import AVKit
import Combine
import QuickLook
import PDFKit

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
    @State private var videoReady = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var pdfThumbnail: UIImage?
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.quaternaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            switch record.status {
            case .pending, .converting:
                convertingContent
            case .converted:
                convertedContent
            case .failed:
                failedContent
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColors.surface)
        .presentationDetents([.medium, .large])
        .presentationBackground(AppColors.surface)
        .presentationDragIndicator(.hidden)
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
            Text(LocalizedStringKey(saveError ?? "Unknown error"))
        }
        .alert("Rename File", isPresented: $showRenameAlert) {
            TextField("File name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Rename") { renameFile() }
        } message: {
            Text("Enter a new name for this file.")
        }
    }

    // MARK: - Header (matches HistoryRowView style)

    private var headerSection: some View {
        HStack(spacing: 12) {
            if let thumbnail = record.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.placeholder)
                    .frame(width: 56, height: 56)
                    .overlay(placeholderIcon)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.sourceFileName)
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    toolBadge

                    HStack(spacing: 4) {
                        Text(record.sourceFormat.uppercased())
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundColor(AppColors.textPrimary)

                        Image(systemName: "arrow.forward")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)

                        Text(record.targetFormat.displayName)
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                statusBadge

                Text(formattedDate)
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    // MARK: - Tool Badge

    @ViewBuilder
    private var toolBadge: some View {
        Text(toolLabel)
            .font(.custom("Montserrat-SemiBold", size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(toolBadgeBackground)
            .clipShape(Capsule())
    }

    private var toolLabel: LocalizedStringKey {
        switch record.tool {
        case .convert: return "Convert:"
        case .compress: return "Compress:"
        case .rotate: return "Rotate:"
        case .resize: return "Resize:"
        case .crop: return "Crop:"
        case .gif: return "GIF"
        case .stitch: return "Stitch"
        case .merge: return "Merge:"
        case .speed: return "Speed:"
        case .timeClip: return "Time Clip:"
        case .extractAudio: return "Extract Audio:"
        case .ratio: return "Ratio:"
        case .mergePDF: return "Merge PDF:"
        case .splitPDF: return "Split PDF:"
        case .reorderPDF: return "Reorder PDF:"
        case .protectPDF: return "Protect PDF:"
        case .imageToPDF: return "Image to PDF:"
        case .draw: return "Draw:"
        }
    }

    @ViewBuilder
    private var toolBadgeBackground: some View {
        switch record.tool {
        case .convert:
            LinearGradient(
                colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case .compress:
            Color(hex: "43CF18")
        case .rotate:
            Color(hex: "1D1D1D")
        case .resize:
            Color(hex: "196EDD")
        case .crop:
            Color(hex: "14C5A2")
        case .stitch:
            Color(hex: "E5A800")
        case .gif:
            AppColors.error
        case .speed:
            Color(hex: "9B59B6")
        case .timeClip:
            Color(hex: "E67E22")
        case .extractAudio:
            AppColors.info
        case .ratio:
            AppColors.success
        case .merge:
            Color(hex: "E74C3C")
        case .mergePDF:
            Color(hex: "8E44AD")
        case .splitPDF:
            Color(hex: "2980B9")
        case .reorderPDF:
            Color(hex: "27AE60")
        case .protectPDF:
            Color(hex: "C0392B")
        case .imageToPDF:
            Color(hex: "3498DB")
        case .draw:
            Color(hex: "FF6B9D")
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        switch record.status {
        case .pending:
            HStack(spacing: 4) {
                Text("Pending")
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundColor(AppColors.accent)
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.accent)
            }
        case .converting:
            HStack(spacing: 4) {
                Text("\(Int(record.progress * 100))%")
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                ProgressView()
                    .controlSize(.mini)
                    .tint(AppColors.accent)
            }
        case .converted:
            HStack(spacing: 4) {
                Text("Done")
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "22C713"))
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "22C713"))
            }
        case .failed:
            HStack(spacing: 4) {
                Text("Fail")
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundColor(AppColors.destructive)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.destructive)
            }
        }
    }

    // MARK: - Date Formatting

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: record.date)
    }

    // MARK: - Placeholder Icon

    @ViewBuilder
    private var placeholderIcon: some View {
        switch record.mediaCategory {
        case "video":
            Image(systemName: "video.fill")
                .font(.system(size: 18))
                .foregroundColor(AppColors.textTertiary)
        case "audio":
            Image(systemName: "music.note")
                .font(.system(size: 18))
                .foregroundColor(AppColors.textTertiary)
        case "document":
            Image(systemName: "doc.fill")
                .font(.system(size: 18))
                .foregroundColor(AppColors.textTertiary)
        default:
            Image(systemName: "photo.fill")
                .font(.system(size: 18))
                .foregroundColor(AppColors.textTertiary)
        }
    }

    // MARK: - Converting

    private var convertingContent: some View {
        VStack(spacing: 16) {
            headerSection

            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: record.progress)
                    .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: record.progress)

                if record.progress > 0 {
                    Text("\(Int(record.progress * 100))%")
                        .font(.custom("Montserrat-Bold", size: 22).monospacedDigit())
                        .foregroundColor(AppColors.accent)
                } else {
                    ProgressView()
                        .tint(AppColors.accent)
                }
            }
            .padding(.top, 8)

            Group {
                if record.progress > 0 {
                    Text("Converting...")
                } else {
                    Text("Starting...")
                }
            }
                .font(.custom("Montserrat-SemiBold", size: 14))
                .foregroundColor(AppColors.textSecondary)

            Button(role: .destructive) {
                ConversionTaskManager.shared.cancel(id: record.id)
                record.status = .failed
                record.errorMessage = String(localized: "Cancelled by user")
                historyStore.save()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.custom("Montserrat-SemiBold", size: 14))
                    .foregroundColor(AppColors.destructive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.destructive.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
    }

    // MARK: - Converted

    private var convertedContent: some View {
        VStack(spacing: 16) {
            headerSection

            if let outputURL = record.outputURL {
                compactPreview(url: outputURL)

                fileInfoSection(url: outputURL)

                actionButtonsRow(url: outputURL)
            }

            Spacer()
        }
        .onAppear { loadFileInfo() }
    }

    // MARK: - Compact Preview (centered thumbnail per Figma)

    @ViewBuilder
    private func compactPreview(url: URL) -> some View {
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

    // MARK: - File Info (Figma style: gray card, no dividers)

    private func fileInfoSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            infoRow(label: "Name:", value: url.lastPathComponent)
            infoRow(label: "Format:", value: record.targetFormat.displayName)
            if let fileSize = fileSize {
                infoRow(label: "Size:", value: fileSize)
            }
            if let fileDimensions = fileDimensions {
                infoRow(label: "Resolution:", value: fileDimensions)
            }
            if let fileDuration = fileDuration {
                infoRow(label: "Duration:", value: fileDuration)
            }
            infoRow(label: "Location:", value: url.deletingLastPathComponent().lastPathComponent + "/")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.textSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(label: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.custom("Montserrat-SemiBold", size: 12))
                .foregroundColor(AppColors.textPrimary)
            Text(value)
                .font(.custom("Montserrat-SemiBold", size: 12))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Action Buttons (Figma: Share | Save | Delete)

    private func actionButtonsRow(url: URL) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 11) {
                ShareLink(item: url) {
                    actionButton(
                        title: "Share",
                        icon: "square.and.arrow.up",
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: AppColors.textPrimary.opacity(0.08)
                    )
                }

                if outputMediaType(for: url) == .document {
                    Button {
                        quickLookURL = url
                    } label: {
                        actionButton(
                            title: "View",
                            icon: "eye",
                            foregroundColor: AppColors.accent,
                            backgroundColor: AppColors.accent.opacity(0.08)
                        )
                    }
                }

                if canSaveToPhotos(url: url) {
                    Button {
                        saveToPhotos(url: url)
                    } label: {
                        actionButton(
                            title: "Save",
                            icon: "square.and.arrow.down",
                            foregroundColor: AppColors.accent,
                            backgroundColor: AppColors.accent.opacity(0.08)
                        )
                    }
                }

                Button {
                    saveToFiles(url: url)
                } label: {
                    actionButton(
                        title: "Save to Files",
                        icon: "folder",
                        foregroundColor: AppColors.accent,
                        backgroundColor: AppColors.accent.opacity(0.08)
                    )
                }

                Button {
                    if let outputURL = record.outputURL {
                        renameText = outputURL.deletingPathExtension().lastPathComponent
                        showRenameAlert = true
                    }
                } label: {
                    actionButton(
                        title: "Rename",
                        icon: "pencil",
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: AppColors.textPrimary.opacity(0.08)
                    )
                }

                Button(role: .destructive) {
                    historyStore.remove(record)
                    dismiss()
                } label: {
                    actionButton(
                        title: "Delete",
                        icon: "trash",
                        foregroundColor: AppColors.destructive,
                        backgroundColor: AppColors.destructive.opacity(0.08)
                    )
                }
            }
        }
    }

    private func actionButton(title: LocalizedStringKey, icon: String, foregroundColor: Color, backgroundColor: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
            Text(title)
                .font(.custom("Montserrat-SemiBold", size: 14))
                .multilineTextAlignment(.center)
        }
        .foregroundColor(foregroundColor)
        .frame(minWidth: 90)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12))
    }

    private func loadFileInfo() {
        guard let outputURL = record.outputURL else { return }

        fileInfoTask = Task.detached(priority: .userInitiated) {
            // File size — lightweight FileManager call
            if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
               let bytes = attrs[.size] as? Int64 {
                let formatted = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                await MainActor.run { fileSize = formatted }
            }
            guard !Task.isCancelled else { return }

            // AVAsset created on background thread to avoid blocking UI
            let asset = AVAsset(url: outputURL)

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

    // MARK: - Asset Previews

    @ViewBuilder
    private func videoPreview(url: URL) -> some View {
        if isAVPlayerCompatible(url) {
            if videoReady {
                VideoPlayerView(url: url)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                mediaThumbnailPlaceholder(icon: "play.fill")
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .onAppear {
                        Task.detached(priority: .userInitiated) {
                            // Verify the asset has playable tracks before showing player
                            let asset = AVAsset(url: url)
                            let playable = (try? await asset.load(.isPlayable)) ?? false
                            await MainActor.run {
                                if playable { videoReady = true }
                            }
                        }
                    }
            }
        } else {
            unsupportedPreview(icon: "video.fill", format: url.pathExtension.uppercased())
        }
    }

    @ViewBuilder
    private func imagePreview(url: URL) -> some View {
        if url.pathExtension.lowercased() == "gif" {
            AnimatedGIFView(url: url)
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if previewTooLarge {
            tooLargePreview(url: url)
        } else {
            Group {
                if let image = outputImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    mediaThumbnailPlaceholder(icon: "photo.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    .frame(maxHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.textTertiary)
            }
            Text("File too large to preview")
                .font(.custom("Montserrat-SemiBold", size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func audioPreview(url: URL) -> some View {
        if isAVPlayerCompatible(url) {
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(AppColors.accent)

                Button {
                    toggleAudioPlayback(url: url)
                } label: {
                    Label(isPlayingAudio ? "Pause" : "Play Audio", systemImage: isPlayingAudio ? "pause.fill" : "play.fill")
                        .font(.custom("Montserrat-SemiBold", size: 14))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppColors.accent.opacity(0.08), in: Capsule())
                        .foregroundColor(AppColors.accent)
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

    private func documentPreview(url: URL) -> some View {
        Button {
            quickLookURL = url
        } label: {
            VStack(spacing: 8) {
                if let thumb = pdfThumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                } else {
                    Image(systemName: documentIcon(for: url.pathExtension))
                        .font(.system(size: 56))
                        .foregroundColor(AppColors.accent)
                }

                HStack(spacing: 4) {
                    Text(url.pathExtension.uppercased())
                        .font(.custom("Montserrat-SemiBold", size: 12))
                        .foregroundColor(AppColors.textSecondary)

                    Text("— Tap to view")
                        .font(.custom("Montserrat-SemiBold", size: 12))
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear { loadPDFThumbnail(url: url) }
    }

    private func loadPDFThumbnail(url: URL) {
        guard url.pathExtension.lowercased() == "pdf" else { return }
        Task.detached(priority: .userInitiated) {
            guard let pdfDoc = PDFDocument(url: url),
                  let page = pdfDoc.page(at: 0) else { return }
            let pageRect = page.bounds(for: .mediaBox)
            let thumbWidth: CGFloat = 200
            let thumbHeight = thumbWidth * pageRect.height / pageRect.width
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: thumbWidth, height: thumbHeight))
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
                ctx.cgContext.translateBy(x: 0, y: thumbHeight)
                ctx.cgContext.scaleBy(x: thumbWidth / pageRect.width,
                                      y: -thumbHeight / pageRect.height)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            await MainActor.run { pdfThumbnail = image }
        }
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

    private static let maxPreviewFileSize: Int64 = 50 * 1024 * 1024
    private static let maxPreviewPixels: CGFloat = 100_000_000

    private func loadImage(url: URL) {
        imageLoadTask?.cancel()
        imageLoadTask = Task.detached(priority: .userInitiated) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let bytes = attrs[.size] as? Int64,
               bytes > Self.maxPreviewFileSize {
                await MainActor.run { previewTooLarge = true }
                return
            }
            guard !Task.isCancelled else { return }

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
                    .frame(maxHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.textTertiary)
            }
            Text("Preview not available for \(format)")
                .font(.custom("Montserrat-SemiBold", size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 8)
    }

    private func mediaThumbnailPlaceholder(icon: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.placeholder)
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(AppColors.textTertiary)
        }
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
        } else if audioExtensions.contains(ext) || record.tool == .extractAudio {
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
            headerSection

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(AppColors.destructive)
                .padding(.top, 8)

            Text("Conversion Failed")
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(AppColors.textPrimary)

            if let errorMessage = record.errorMessage {
                Text(errorMessage)
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                dismiss()
            } label: {
                Text("Dismiss")
                    .font(.custom("Montserrat-SemiBold", size: 14))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.textPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func openWithSystemApp(url: URL) {
        quickLookURL = url
    }

    // Formats that PHAssetChangeRequest actually supports
    private static let gallerySaveableVideoExtensions = Set(["mp4", "mov", "m4v", "3gp"])
    private static let gallerySaveableImageExtensions = Set(["heic", "jpeg", "jpg", "png", "gif", "tiff", "bmp", "webp"])

    private func canSaveToPhotos(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let mediaType = outputMediaType(for: url)
        switch mediaType {
        case .video:
            return Self.gallerySaveableVideoExtensions.contains(ext)
        case .image:
            // Native formats or formats UIImage can load (will be saved as PNG)
            if Self.gallerySaveableImageExtensions.contains(ext) { return true }
            return UIImage(contentsOfFile: url.path) != nil
        case .audio, .document:
            return false
        }
    }

    private func saveToPhotos(url: URL) {
        AnalyticsService.log(AnalyticsService.Event.saveToPhotosTapped, parameters: [
            AnalyticsService.Param.mediaCategory: record.mediaCategory,
            AnalyticsService.Param.targetFormat: record.targetFormatID
        ])
        let ext = url.pathExtension.lowercased()
        let isVideo = Self.gallerySaveableVideoExtensions.contains(ext)

        // For image formats not natively supported by Photos, convert via UIImage
        var pngData: Data?
        if !isVideo && !Self.gallerySaveableImageExtensions.contains(ext) {
            if let image = UIImage(contentsOfFile: url.path) {
                pngData = image.pngData()
            }
            if pngData == nil {
                saveError = String(localized: "This image format is not supported for saving to the photo library.")
                return
            }
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.saveError = String(localized: "Photo library access denied. Please allow access in Settings.")
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                if isVideo {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } else if let data = pngData {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
                    try? data.write(to: tempURL)
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.showSaveSuccess = true
                    } else {
                        self.saveError = error?.localizedDescription ?? String(localized: "Failed to save")
                    }
                }
            }
        }
    }

    private func renameFile() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let outputURL = record.outputURL else { return }

        let ext = outputURL.pathExtension
        let newFileName = trimmed + "." + ext
        let newURL = outputURL.deletingLastPathComponent().appendingPathComponent(newFileName)

        // Don't rename if the name hasn't changed
        guard newURL != outputURL else { return }

        do {
            // If a file with the new name already exists, bail out
            if FileManager.default.fileExists(atPath: newURL.path) {
                saveError = String(localized: "A file with this name already exists.")
                return
            }
            try FileManager.default.moveItem(at: outputURL, to: newURL)
            // Update relative path stored in record
            let parentDir = outputURL.deletingLastPathComponent().lastPathComponent
            record.outputPath = parentDir + "/" + newFileName
            record.sourceFileName = trimmed
            historyStore.save()
        } catch {
            saveError = String(localized: "Failed to rename file.")
        }
    }

    private func saveToFiles(url: URL) {
        AnalyticsService.log(AnalyticsService.Event.saveToFilesTapped, parameters: [
            AnalyticsService.Param.mediaCategory: record.mediaCategory,
            AnalyticsService.Param.targetFormat: record.targetFormatID
        ])
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(picker, animated: true)
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

