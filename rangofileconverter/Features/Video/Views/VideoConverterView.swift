import SwiftUI

private enum VideoTab: String, CaseIterable {
    case tools = "Tools"
    case history = "History"
}

private struct VideoTool: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let isAvailable: Bool
}

private let videoTools: [VideoTool] = [
    VideoTool(id: "convert", title: "Format Conversion", icon: "arrow.triangle.2.circlepath", isAvailable: true),
    VideoTool(id: "extract_audio", title: "Extract Audio", icon: "music.note", isAvailable: true),
    VideoTool(id: "compress", title: "Video Compression", icon: "arrow.down.right.and.arrow.up.left", isAvailable: true),
    VideoTool(id: "speed", title: "Speed Change", icon: "gauge.with.dots.needle.33percent", isAvailable: true),
    VideoTool(id: "merge", title: "Merge Videos", icon: "square.stack.3d.up", isAvailable: true),
    VideoTool(id: "ratio", title: "Video Ratio", icon: "aspectratio", isAvailable: true),
    VideoTool(id: "gif", title: "Convert GIF", icon: "photo.stack", isAvailable: true),
    VideoTool(id: "time_clip", title: "Video Time Clip", icon: "timeline.selection", isAvailable: true),
]

struct VideoConverterView: View {
    @StateObject private var viewModel = VideoConverterViewModel()
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var selectedTab: VideoTab = .tools
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

    private var history: [ConversionRecord] {
        historyStore.records(for: "video")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                tabPicker

                switch selectedTab {
                case .tools:
                    toolsSection
                case .history:
                    historySection
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showVideoPicker) {
                VideoPickerView { thumbnail, fileName, url in
                    handleVideoSelected(thumbnail: thumbnail, fileName: fileName, url: url)
                }
            }
            .navigationDestination(isPresented: $showSpeedView) {
                if let thumbnail = speedThumbnail, let url = speedVideoURL {
                    VideoSpeedView(
                        thumbnail: thumbnail,
                        fileName: speedFileName,
                        fileURL: url
                    ) { speed in
                        Task {
                            await viewModel.changeSpeed(
                                inputURL: url,
                                fileName: speedFileName,
                                thumbnail: thumbnail,
                                speed: speed
                            )
                        }
                        DispatchQueue.main.async {
                            showSpeedView = false
                            showVideoPicker = false
                            selectedTab = .history
                        }
                    }
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
                        Task {
                            await viewModel.convertToGif(fps: fps, width: width)
                        }
                        DispatchQueue.main.async {
                            viewModel.showGifDetail = false
                            showVideoPicker = false
                            selectedTab = .history
                        }
                    }
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
                        Task {
                            await viewModel.convert(to: format)
                        }
                        DispatchQueue.main.async {
                            viewModel.showConversionDetail = false
                            showVideoPicker = false
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showTimeClipView) {
                if let url = timeClipVideoURL, let thumb = timeClipThumbnail {
                    VideoTimeClipView(
                        videoURL: url,
                        thumbnail: thumb,
                        fileName: timeClipFileName
                    ) { startTime, endTime in
                        Task {
                            await viewModel.clipVideo(
                                inputURL: url,
                                fileName: timeClipFileName,
                                thumbnail: thumb,
                                startTime: startTime,
                                endTime: endTime
                            )
                        }
                        DispatchQueue.main.async {
                            showTimeClipView = false
                            showVideoPicker = false
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showCompressView) {
                if let thumbnail = compressThumbnail, let url = compressFileURL {
                    VideoCompressView(
                        thumbnail: thumbnail,
                        fileName: compressFileName,
                        fileURL: url
                    ) { quality, resolutionHeight, preset, format in
                        Task {
                            await viewModel.compressVideo(
                                inputURL: url,
                                fileName: compressFileName,
                                thumbnail: thumbnail,
                                quality: quality,
                                resolutionHeight: resolutionHeight,
                                preset: preset,
                                outputFormat: format
                            )
                        }
                        DispatchQueue.main.async {
                            showCompressView = false
                            showVideoPicker = false
                            selectedTab = .history
                        }
                    }
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
                        Task {
                            await viewModel.extractAudio(to: format)
                        }
                        DispatchQueue.main.async {
                            viewModel.showExtractAudioDetail = false
                            showVideoPicker = false
                            selectedTab = .history
                        }
                    }
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
                        Task {
                            await viewModel.convertRatio(aspectRatio: aspectRatio, fitMode: fitMode, cropPosition: cropPosition, cropScale: cropScale)
                        }
                        DispatchQueue.main.async {
                            viewModel.showVideoRatio = false
                            showVideoPicker = false
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showMergePicker) {
                VideoMergePickerView { results in
                    mergeVideos = results.map { (thumbnail: $0.0, fileName: $0.1, url: $0.2) }
                    showMergeView = true
                }
            }
            .navigationDestination(isPresented: $showMergeView) {
                if !mergeVideos.isEmpty {
                    VideoMergeView(videos: mergeVideos) { outputExtension, thumbnail in
                        Task {
                            await viewModel.mergeVideos(
                                inputs: mergeVideos.map(\.url),
                                outputExtension: outputExtension,
                                thumbnail: thumbnail
                            )
                        }
                        DispatchQueue.main.async {
                            showMergeView = false
                            showMergePicker = false
                            selectedTab = .history
                        }
                    }
                }
            }

        }
    }

    private var header: some View {
        HStack {
            Text("Video")
                .font(.title.bold())
            Spacer()
            Button {
                // TODO: open settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(VideoTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var toolsSection: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(videoTools) { tool in
                    Button {
                        handleToolTap(tool)
                    } label: {
                        toolCard(tool)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func toolCard(_ tool: VideoTool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: tool.icon)
                .font(.title2)
            Text(tool.title)
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

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

    @ViewBuilder
    private var historySection: some View {
        if history.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No conversions yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            List {
                ForEach(history) { record in
                    HistoryRowView(record: record)
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    VideoConverterView()
        .environmentObject(HistoryStore.shared)
}
