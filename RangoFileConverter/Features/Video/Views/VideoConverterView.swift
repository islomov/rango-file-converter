import SwiftUI

private struct VideoTool: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let isAvailable: Bool

    init(id: String, title: String, icon: String, isAvailable: Bool = true) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isAvailable = isAvailable
    }
}

private let videoTools: [VideoTool] = [
    VideoTool(id: "convert", title: "Convert", icon: "icon_convert"),
    VideoTool(id: "extract_audio", title: "Extract audio", icon: "icon_extract_audio"),
    VideoTool(id: "compress", title: "Compress", icon: "icon_compress"),
    VideoTool(id: "speed", title: "Speed change", icon: "icon_speed"),
    VideoTool(id: "merge", title: "Merge videos", icon: "icon_merge"),
    VideoTool(id: "ratio", title: "Video ratio", icon: "icon_ratio"),
    VideoTool(id: "gif", title: "Make GIF", icon: "icon_gif"),
    VideoTool(id: "time_clip", title: "Video time clip", icon: "icon_clip"),
]

struct VideoConverterView: View {
    var onBack: (() -> Void)?
    var onNavigateToHistory: (() -> Void)?

    @StateObject private var viewModel = VideoConverterViewModel()
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var showVideoPicker = false
    @State private var activeTool: String = "convert"
    @State private var showTimeClipView = false
    @State private var timeClipVideoURL: URL?
    @State private var timeClipThumbnail: UIImage?
    @State private var timeClipFileName: String = ""

    // Speed tool state
    @State private var showSpeedView = false
    @State private var speedThumbnail: UIImage?
    @State private var speedFileName: String = ""
    @State private var speedVideoURL: URL?

    // Compress tool state
    @State private var showCompressView = false
    @State private var compressThumbnail: UIImage?
    @State private var compressFileName: String = ""
    @State private var compressFileURL: URL?

    // Merge tool state
    @State private var showMergePicker = false
    @State private var showMergeView = false
    @State private var mergeVideos: [(thumbnail: UIImage, fileName: String, url: URL)] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    toolsGrid
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showVideoPicker) {
                VideoPickerView { thumbnail, fileName, url in
                    handleVideoSelected(thumbnail: thumbnail, fileName: fileName, url: url)
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $showSpeedView) {
                if let thumbnail = speedThumbnail, let url = speedVideoURL {
                    VideoSpeedView(
                        thumbnail: thumbnail,
                        fileName: speedFileName,
                        fileURL: url
                    ) { speed in
                        viewModel.changeSpeed(
                            inputURL: url,
                            fileName: speedFileName,
                            thumbnail: thumbnail,
                            speed: speed
                        )
                        showSpeedView = false
                        showVideoPicker = false
                        onNavigateToHistory?()
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $viewModel.showGifDetail) {
                if let thumbnail = viewModel.selectedThumbnail,
                   let fileURL = viewModel.selectedVideoURL {
                    VideoToGifView(
                        thumbnail: thumbnail,
                        fileName: viewModel.selectedFileName,
                        fileURL: fileURL
                    ) { fps, width in
                        viewModel.convertToGif(
                            inputURL: fileURL,
                            fileName: viewModel.selectedFileName,
                            thumbnail: thumbnail,
                            fps: fps,
                            width: width
                        )
                        viewModel.showGifDetail = false
                        showVideoPicker = false
                        onNavigateToHistory?()
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $viewModel.showConversionDetail) {
                if let thumbnail = viewModel.selectedThumbnail,
                   let fileURL = viewModel.selectedVideoURL {
                    VideoDetailView(
                        thumbnail: thumbnail,
                        fileName: viewModel.selectedFileName,
                        fileURL: fileURL
                    ) { format in
                        viewModel.convert(
                            inputURL: fileURL,
                            fileName: viewModel.selectedFileName,
                            thumbnail: thumbnail,
                            to: format
                        )
                        viewModel.showConversionDetail = false
                        showVideoPicker = false
                        onNavigateToHistory?()
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $showTimeClipView) {
                if let url = timeClipVideoURL, let thumb = timeClipThumbnail {
                    VideoTimeClipView(
                        videoURL: url,
                        thumbnail: thumb,
                        fileName: timeClipFileName
                    ) { startTime, endTime in
                        viewModel.clipVideo(
                            inputURL: url,
                            fileName: timeClipFileName,
                            thumbnail: thumb,
                            startTime: startTime,
                            endTime: endTime
                        )
                        showTimeClipView = false
                        showVideoPicker = false
                        onNavigateToHistory?()
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $showCompressView) {
                if let thumbnail = compressThumbnail, let url = compressFileURL {
                    VideoCompressView(
                        thumbnail: thumbnail,
                        fileName: compressFileName,
                        fileURL: url
                    ) { quality, resolutionHeight, preset, format in
                        viewModel.compressVideo(
                            inputURL: url,
                            fileName: compressFileName,
                            thumbnail: thumbnail,
                            quality: quality,
                            resolutionHeight: resolutionHeight,
                            preset: preset,
                            outputFormat: format
                        )
                        showCompressView = false
                        showVideoPicker = false
                        onNavigateToHistory?()
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $viewModel.showExtractAudioDetail) {
                if let thumbnail = viewModel.selectedThumbnail,
                   let fileURL = viewModel.selectedVideoURL {
                    ExtractAudioDetailView(
                        thumbnail: thumbnail,
                        fileName: viewModel.selectedFileName,
                        fileURL: fileURL
                    ) { format in
                        viewModel.extractAudio(
                            inputURL: fileURL,
                            fileName: viewModel.selectedFileName,
                            thumbnail: thumbnail,
                            to: format
                        )
                        viewModel.showExtractAudioDetail = false
                        showVideoPicker = false
                        onNavigateToHistory?()
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $viewModel.showVideoRatio) {
                if let thumbnail = viewModel.selectedThumbnail,
                   let fileURL = viewModel.selectedVideoURL {
                    VideoRatioView(
                        thumbnail: thumbnail,
                        fileName: viewModel.selectedFileName,
                        fileURL: fileURL
                    ) { aspectRatio, fitMode, cropPosition, cropScale in
                        viewModel.convertRatio(
                            inputURL: fileURL,
                            fileName: viewModel.selectedFileName,
                            thumbnail: thumbnail,
                            aspectRatio: aspectRatio,
                            fitMode: fitMode,
                            cropPosition: cropPosition,
                            cropScale: cropScale
                        )
                        viewModel.showVideoRatio = false
                        showVideoPicker = false
                        onNavigateToHistory?()
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $showMergePicker) {
                VideoMergePickerView { results in
                    mergeVideos = results.map { (thumbnail: $0.0, fileName: $0.1, url: $0.2) }
                    showMergeView = true
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $showMergeView) {
                if !mergeVideos.isEmpty {
                    VideoMergeView(videos: mergeVideos) { outputExtension, thumbnail in
                        viewModel.mergeVideos(
                            inputs: mergeVideos.map(\.url),
                            outputExtension: outputExtension,
                            thumbnail: thumbnail
                        )
                        showMergeView = false
                        showMergePicker = false
                        onNavigateToHistory?()
                    }
                    .hidesFloatingTabBar()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Video")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Button {
                    onBack?()
                } label: {
                    Image("icon_arrow_left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - Tools Grid

    private var toolsGrid: some View {
        ScrollView {
            let twoColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

            LazyVGrid(columns: twoColumns, spacing: 12) {
                ForEach(videoTools) { tool in
                    Button {
                        handleToolTap(tool)
                    } label: {
                        toolCard(tool)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    private func toolCard(_ tool: VideoTool) -> some View {
        VStack(spacing: 8) {
            Image(tool.icon)
                .resizable()
                .frame(width: 28, height: 28)

            Text(tool.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 106)
        .background(AppColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Tool Actions

    private func handleToolTap(_ tool: VideoTool) {
        activeTool = tool.id
        switch tool.id {
        case "convert", "time_clip", "speed", "compress", "gif", "extract_audio", "ratio":
            showVideoPicker = true
        case "merge":
            showMergePicker = true
        default:
            break
        }
    }

    private func handleVideoSelected(thumbnail: UIImage, fileName: String, url: URL) {
        switch activeTool {
        case "convert":
            viewModel.selectVideo(thumbnail: thumbnail, fileName: fileName, fileURL: url)
        case "gif":
            viewModel.selectVideoForGif(thumbnail: thumbnail, fileName: fileName, fileURL: url)
        case "extract_audio":
            viewModel.selectVideoForExtractAudio(thumbnail: thumbnail, fileName: fileName, fileURL: url)
        case "ratio":
            viewModel.selectVideoForRatio(thumbnail: thumbnail, fileName: fileName, fileURL: url)
        case "time_clip":
            timeClipThumbnail = thumbnail
            timeClipFileName = fileName
            timeClipVideoURL = url
            showTimeClipView = true
        case "speed":
            speedThumbnail = thumbnail
            speedFileName = fileName
            speedVideoURL = url
            showSpeedView = true
        case "compress":
            compressThumbnail = thumbnail
            compressFileName = fileName
            compressFileURL = url
            showCompressView = true
        default:
            break
        }
    }
}

#Preview {
    VideoConverterView()
        .environmentObject(HistoryStore.shared)
}
