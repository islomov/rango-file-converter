import SwiftUI

private struct ImageTool: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let isAvailable: Bool
    let isFullWidth: Bool

    init(id: String, title: String, icon: String, isAvailable: Bool = true, isFullWidth: Bool = false) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isAvailable = isAvailable
        self.isFullWidth = isFullWidth
    }
}

private let imageTools: [ImageTool] = [
    ImageTool(id: "convert", title: "Convert", icon: "icon_convert"),
    ImageTool(id: "compress", title: "Compress", icon: "icon_compress"),
    ImageTool(id: "rotate", title: "Rotate", icon: "icon_rotate"),
    ImageTool(id: "resize", title: "Resize", icon: "icon_resize"),
    ImageTool(id: "crop", title: "Crop", icon: "icon_crop"),
    ImageTool(id: "stitch", title: "Stitch", icon: "icon_stitch"),
    ImageTool(id: "gif", title: "Make GIF", icon: "icon_gif", isFullWidth: true),
]

struct ImageConverterView: View {
    var onBack: (() -> Void)?
    var onNavigateToHistory: (() -> Void)?

    @StateObject private var viewModel = ImageConverterViewModel()
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var showComingSoon = false
    @State private var showAssetPicker = false
    @State private var activeTool: String?

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

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F2F2F6")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    toolsGrid
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showAssetPicker) {
                AssetPickerView { image, fileName, url in
                    handleAssetSelected(image: image, fileName: fileName, url: url)
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $showGifPicker) {
                AssetPickerView(mode: .multiple(minCount: 2)) { results in
                    handleMultipleAssetsSelected(results)
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $showStitchPicker) {
                AssetPickerView(mode: .multiple(minCount: 2)) { results in
                    handleStitchAssetsSelected(results)
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $viewModel.showConversionDetail) {
                ImageDetailView(
                    fileURL: viewModel.selectedFileURL ?? URL(fileURLWithPath: ""),
                    fileName: viewModel.selectedFileName
                ) { format in
                    guard let url = viewModel.selectedFileURL else { return }
                    viewModel.convert(inputURL: url, fileName: viewModel.selectedFileName, to: format)
                    viewModel.showConversionDetail = false
                    showAssetPicker = false
                    toolFileURL = nil
                    onNavigateToHistory?()
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $showRotateView) {
                if let url = toolFileURL {
                    ImageRotateView(
                        fileURL: url,
                        fileName: toolFileName
                    ) { rotation, flipH, flipV in
                        viewModel.processRotation(
                            fileURL: url,
                            fileName: toolFileName,
                            rotation: rotation,
                            flipH: flipH,
                            flipV: flipV
                        )
                        showRotateView = false
                        showAssetPicker = false
                        toolFileURL = nil
                        onNavigateToHistory?()
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $showCropView) {
                if let url = toolFileURL {
                    ImageCropView(
                        fileURL: url,
                        fileName: toolFileName
                    ) { cropRect in
                        viewModel.processCrop(
                            fileURL: url,
                            fileName: toolFileName,
                            cropRect: cropRect
                        )
                        showCropView = false
                        showAssetPicker = false
                        toolFileURL = nil
                    }
                }
            }
            .navigationDestination(isPresented: $showResizeView) {
                if let url = toolFileURL {
                    ImageResizeView(
                        fileURL: url,
                        fileName: toolFileName
                    ) { width, height in
                        viewModel.processResize(
                            fileURL: url,
                            fileName: toolFileName,
                            width: width,
                            height: height
                        )
                        showResizeView = false
                        showAssetPicker = false
                        toolFileURL = nil
                    }
                }
            }
            .navigationDestination(isPresented: $showCompressView) {
                if let url = toolFileURL {
                    ImageCompressView(
                        fileURL: url,
                        fileName: toolFileName
                    ) { formatExt, quality in
                        viewModel.processCompress(
                            fileURL: url,
                            fileName: toolFileName,
                            formatExtension: formatExt,
                            quality: quality
                        )
                        showCompressView = false
                        showAssetPicker = false
                        toolFileURL = nil
                    }
                }
            }
            .navigationDestination(isPresented: $showGifView) {
                if !gifFileURLs.isEmpty {
                    MakeGifView(
                        fileURLs: gifFileURLs,
                        fileNames: gifFileNames
                    ) { frameDelay, loopForever in
                        viewModel.processGif(
                            fileURLs: gifFileURLs,
                            fileNames: gifFileNames,
                            frameDelay: frameDelay,
                            loopForever: loopForever
                        )
                        showGifView = false
                        showGifPicker = false
                        gifFileURLs = []
                        gifFileNames = []
                    }
                }
            }
            .navigationDestination(isPresented: $showStitchView) {
                if !stitchFileURLs.isEmpty {
                    ImageStitchView(
                        fileURLs: stitchFileURLs,
                        fileNames: stitchFileNames
                    ) { layout, background in
                        viewModel.processStitch(
                            fileURLs: stitchFileURLs,
                            layout: layout,
                            background: background,
                            gap: 16
                        )
                        showStitchView = false
                        showStitchPicker = false
                        stitchFileURLs = []
                        stitchFileNames = []
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

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Image")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))

            HStack {
                Button {
                    onBack?()
                } label: {
                    Image("icon_arrow_left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(hex: "1D1D1D"))
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
                ForEach(imageTools) { tool in
                    if tool.isFullWidth {
                        // Full-width card spanning both columns
                        Button {
                            handleToolTap(tool)
                        } label: {
                            toolCard(tool)
                        }
                        .gridCellColumns(2)
                    } else {
                        Button {
                            handleToolTap(tool)
                        } label: {
                            toolCard(tool)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    private func toolCard(_ tool: ImageTool) -> some View {
        VStack(spacing: 8) {
            Image(tool.icon)
                .resizable()
                .frame(width: 28, height: 28)

            Text(tool.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 106)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Tool Actions

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

    private func handleAssetSelected(image: UIImage, fileName: String, url: URL) {
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
}

#Preview {
    ImageConverterView()
        .environmentObject(HistoryStore.shared)
}
