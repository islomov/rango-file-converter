import SwiftUI
import SwiftData

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
    VideoTool(id: "extract_audio", title: "Extract Audio", icon: "music.note", isAvailable: false),
    VideoTool(id: "compress", title: "Video Compression", icon: "arrow.down.right.and.arrow.up.left", isAvailable: false),
    VideoTool(id: "speed", title: "Speed Change", icon: "gauge.with.dots.needle.33percent", isAvailable: true),
    VideoTool(id: "merge", title: "Merge Videos", icon: "square.stack.3d.up", isAvailable: false),
    VideoTool(id: "ratio", title: "Video Ratio", icon: "aspectratio", isAvailable: false),
    VideoTool(id: "clip", title: "Video Clipping", icon: "scissors", isAvailable: false),
    VideoTool(id: "gif", title: "Convert GIF", icon: "photo.stack", isAvailable: false),
    VideoTool(id: "time_clip", title: "Video Time Clip", icon: "timeline.selection", isAvailable: true),
]

struct VideoConverterView: View {
    @State private var viewModel = VideoConverterViewModel()
    @State private var selectedTab: VideoTab = .tools
    @State private var showComingSoon = false
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

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<ConversionRecord> { record in
            record.mediaCategory == "video"
        },
        sort: \ConversionRecord.date,
        order: .reverse
    ) private var history: [ConversionRecord]

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
                    if activeTool == "time_clip" {
                        timeClipThumbnail = thumbnail
                        timeClipFileName = fileName
                        timeClipVideoURL = url
                        showTimeClipView = true
                    } else if activeTool == "speed" {
                        speedThumbnail = thumbnail
                        speedFileName = fileName
                        speedVideoURL = url
                        showSpeedView = true
                    } else {
                        viewModel.selectVideo(thumbnail: thumbnail, fileName: fileName, fileURL: url)
                    }
                }
            }
            .navigationDestination(isPresented: $showSpeedView) {
                if let thumbnail = speedThumbnail, let url = speedVideoURL {
                    VideoSpeedView(
                        thumbnail: thumbnail,
                        fileName: speedFileName,
                        fileURL: url
                    ) { outputThumbnail, outputURL in
                        viewModel.addHistoryRecord(
                            fileName: speedFileName,
                            thumbnail: outputThumbnail,
                            outputURL: outputURL,
                            toolType: "Speed",
                            context: modelContext
                        )
                        DispatchQueue.main.async {
                            showSpeedView = false
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
                        await viewModel.convert(to: format, context: modelContext)
                        selectedTab = .history
                    }
                }
            }
            .navigationDestination(isPresented: $showTimeClipView) {
                if let url = timeClipVideoURL, let thumb = timeClipThumbnail {
                    VideoTimeClipView(
                        videoURL: url,
                        thumbnail: thumb,
                        fileName: timeClipFileName
                    ) { outputThumb, outputURL in
                        viewModel.addHistoryRecord(
                            fileName: outputURL.lastPathComponent,
                            thumbnail: outputThumb,
                            outputURL: outputURL,
                            toolType: "Time Clip",
                            context: modelContext
                        )
                        DispatchQueue.main.async {
                            showTimeClipView = false
                            showVideoPicker = false
                            selectedTab = .history
                        }
                    }
                }
            }
            .alert("Coming Soon", isPresented: $showComingSoon) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This tool is not available yet. Stay tuned!")
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
        .foregroundStyle(tool.isAvailable ? .primary : .secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if !tool.isAvailable {
                Text("Soon")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary, in: Capsule())
                    .padding(8)
            }
        }
    }

    private func handleToolTap(_ tool: VideoTool) {
        if tool.isAvailable {
            activeTool = tool.id
            switch tool.id {
            case "convert", "time_clip", "speed":
                showVideoPicker = true
            default:
                break
            }
        } else {
            showComingSoon = true
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
        .modelContainer(for: ConversionRecord.self, inMemory: true)
}
