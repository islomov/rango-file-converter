import SwiftUI

private enum ImageTab: String, CaseIterable {
    case tools = "Tools"
    case history = "History"
}

private struct ImageTool: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let isAvailable: Bool
}

private let imageTools: [ImageTool] = [
    ImageTool(id: "convert", title: "Convert", icon: "arrow.triangle.2.circlepath", isAvailable: true),
    ImageTool(id: "compress", title: "Compress", icon: "arrow.down.right.and.arrow.up.left", isAvailable: true),
    ImageTool(id: "rotate", title: "Rotate", icon: "rotate.right", isAvailable: true),
    ImageTool(id: "resize", title: "Resize", icon: "arrow.up.left.and.arrow.down.right", isAvailable: true),
    ImageTool(id: "crop", title: "Crop", icon: "crop", isAvailable: true),
    ImageTool(id: "stitch", title: "Stitch", icon: "rectangle.grid.2x2", isAvailable: true),
    ImageTool(id: "gif", title: "Make GIF", icon: "photo.stack", isAvailable: true),
]

struct ImageConverterView: View {
    @StateObject private var viewModel = ImageConverterViewModel()
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var selectedTab: ImageTab = .tools
    @State private var showComingSoon = false
    @State private var showAssetPicker = false
    @State private var activeTool: String?

    // Settings
    @State private var showSettings = false

    // History sheet state
    @State private var selectedRecord: ConversionRecord?

    // Single-image tool state (URL-based)
    @State private var showRotateView = false
    @State private var showCropView = false
    @State private var showResizeView = false
    @State private var showCompressView = false
    @State private var toolFileURL: URL?
    @State private var toolFileName: String = ""

    // GIF tool state
    @State private var showGifPicker = false
    @State private var showGifView = false
    @State private var gifFileURLs: [URL] = []
    @State private var gifFileNames: [String] = []

    // Stitch tool state
    @State private var showStitchPicker = false
    @State private var showStitchView = false
    @State private var stitchFileURLs: [URL] = []
    @State private var stitchFileNames: [String] = []

    private var history: [ConversionRecord] {
        historyStore.records(for: "image")
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
            .navigationDestination(isPresented: $showAssetPicker) {
                AssetPickerView { image, fileName, url in
                    handleAssetSelected(image: image, fileName: fileName, url: url)
                }
            }
            .navigationDestination(isPresented: $showGifPicker) {
                AssetPickerView(mode: .multiple(minCount: 2)) { results in
                    handleMultipleAssetsSelected(results)
                }
            }
            .navigationDestination(isPresented: $showStitchPicker) {
                AssetPickerView(mode: .multiple(minCount: 2)) { results in
                    handleStitchAssetsSelected(results)
                }
            }
            .navigationDestination(isPresented: $viewModel.showConversionDetail) {
                if let url = viewModel.selectedFileURL {
                    ImageDetailView(
                        fileURL: url,
                        fileName: viewModel.selectedFileName
                    ) { format in
                        await viewModel.convert(to: format)
                        selectedTab = .history
                    }
                }
            }
            .navigationDestination(isPresented: $showRotateView) {
                if let url = toolFileURL {
                    ImageRotateView(
                        fileURL: url,
                        fileName: toolFileName
                    ) { rotation, flipH, flipV in
                        let capturedURL = url
                        let capturedName = toolFileName
                        Task {
                            await viewModel.processRotation(
                                fileURL: capturedURL,
                                fileName: capturedName,
                                rotation: rotation,
                                flipH: flipH,
                                flipV: flipV
                            )
                        }
                        DispatchQueue.main.async {
                            showRotateView = false
                            showAssetPicker = false
                            toolFileURL = nil
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showCropView) {
                if let url = toolFileURL {
                    ImageCropView(
                        fileURL: url,
                        fileName: toolFileName
                    ) { cropRect in
                        let capturedURL = url
                        let capturedName = toolFileName
                        Task {
                            await viewModel.processCrop(
                                fileURL: capturedURL,
                                fileName: capturedName,
                                cropRect: cropRect
                            )
                        }
                        DispatchQueue.main.async {
                            showCropView = false
                            showAssetPicker = false
                            toolFileURL = nil
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showResizeView) {
                if let url = toolFileURL {
                    ImageResizeView(
                        fileURL: url,
                        fileName: toolFileName
                    ) { width, height in
                        let capturedURL = url
                        let capturedName = toolFileName
                        Task {
                            await viewModel.processResize(
                                fileURL: capturedURL,
                                fileName: capturedName,
                                width: width,
                                height: height
                            )
                        }
                        DispatchQueue.main.async {
                            showResizeView = false
                            showAssetPicker = false
                            toolFileURL = nil
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showCompressView) {
                if let url = toolFileURL {
                    ImageCompressView(
                        fileURL: url,
                        fileName: toolFileName
                    ) { formatExt, quality in
                        let capturedURL = url
                        let capturedName = toolFileName
                        Task {
                            await viewModel.processCompress(
                                fileURL: capturedURL,
                                fileName: capturedName,
                                formatExtension: formatExt,
                                quality: quality
                            )
                        }
                        DispatchQueue.main.async {
                            showCompressView = false
                            showAssetPicker = false
                            toolFileURL = nil
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showGifView) {
                if !gifFileURLs.isEmpty {
                    MakeGifView(
                        fileURLs: gifFileURLs,
                        fileNames: gifFileNames
                    ) { frameDelay, loopForever in
                        let capturedURLs = gifFileURLs
                        let capturedNames = gifFileNames
                        Task {
                            await viewModel.processGif(
                                fileURLs: capturedURLs,
                                fileNames: capturedNames,
                                frameDelay: frameDelay,
                                loopForever: loopForever
                            )
                        }
                        DispatchQueue.main.async {
                            showGifView = false
                            showGifPicker = false
                            gifFileURLs = []
                            gifFileNames = []
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showStitchView) {
                if !stitchFileURLs.isEmpty {
                    ImageStitchView(
                        fileURLs: stitchFileURLs,
                        fileNames: stitchFileNames
                    ) { layout, background in
                        let capturedURLs = stitchFileURLs
                        Task {
                            await viewModel.processStitch(
                                fileURLs: capturedURLs,
                                layout: layout,
                                background: background,
                                gap: 16
                            )
                        }
                        DispatchQueue.main.async {
                            showStitchView = false
                            showStitchPicker = false
                            stitchFileURLs = []
                            stitchFileNames = []
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

    private func handleAssetSelected(image: UIImage, fileName: String, url: URL) {
        // We only need the URL and fileName — ignore the UIImage
        toolFileName = fileName
        toolFileURL = url

        switch activeTool {
        case "convert":
            viewModel.selectImage(image, fileName: fileName, fileURL: url)
        case "rotate":
            showRotateView = true
        case "resize":
            showResizeView = true
        case "compress":
            showCompressView = true
        case "crop":
            showCropView = true
        default:
            break
        }
    }

    private var header: some View {
        HStack {
            Text("Image")
                .font(.title.bold())
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(historyStore)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(ImageTab.allCases, id: \.self) { tab in
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
                ForEach(imageTools) { tool in
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

    private func toolCard(_ tool: ImageTool) -> some View {
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

    private func handleToolTap(_ tool: ImageTool) {
        if tool.isAvailable {
            activeTool = tool.id
            if tool.id == "gif" {
                showGifPicker = true
            } else if tool.id == "stitch" {
                showStitchPicker = true
            } else {
                showAssetPicker = true
            }
        } else {
            showComingSoon = true
        }
    }

    private func handleMultipleAssetsSelected(_ results: [(UIImage, String, URL)]) {
        gifFileURLs = results.map { $0.2 }
        gifFileNames = results.map { $0.1 }
        showGifView = true
    }

    private func handleStitchAssetsSelected(_ results: [(UIImage, String, URL)]) {
        stitchFileURLs = results.map { $0.2 }
        stitchFileNames = results.map { $0.1 }
        showStitchView = true
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
                    Button {
                        selectedRecord = record
                    } label: {
                        HistoryRowView(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .sheet(item: $selectedRecord) { record in
                HistoryResultSheet(record: record)
                    .environmentObject(historyStore)
            }
        }
    }
}

#Preview {
    ImageConverterView()
        .environmentObject(HistoryStore.shared)
}
