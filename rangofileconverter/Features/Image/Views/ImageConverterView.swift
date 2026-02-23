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

    // History sheet state
    @State private var selectedRecord: ConversionRecord?

    // Rotate tool state
    @State private var showRotateView = false
    @State private var rotateImage: UIImage?
    @State private var rotateFileName: String = ""
    @State private var rotateFileURL: URL?

    // Crop tool state
    @State private var showCropView = false
    @State private var cropImage: UIImage?
    @State private var cropFileName: String = ""
    @State private var cropFileURL: URL?

    // Resize tool state
    @State private var showResizeView = false
    @State private var resizeImage: UIImage?
    @State private var resizeFileName: String = ""

    // Compress tool state
    @State private var showCompressView = false
    @State private var compressImage: UIImage?
    @State private var compressFileName: String = ""
    @State private var compressFileURL: URL?

    // GIF tool state
    @State private var showGifPicker = false
    @State private var showGifView = false
    @State private var gifImages: [UIImage] = []
    @State private var gifFileNames: [String] = []

    // Stitch tool state
    @State private var showStitchPicker = false
    @State private var showStitchView = false
    @State private var stitchImages: [UIImage] = []
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
                if let image = viewModel.selectedImage {
                    ImageDetailView(
                        image: image,
                        fileName: viewModel.selectedFileName
                    ) { format in
                        await viewModel.convert(to: format)
                        selectedTab = .history
                    }
                }
            }
            .navigationDestination(isPresented: $showRotateView) {
                if let image = rotateImage {
                    ImageRotateView(
                        image: image,
                        fileName: rotateFileName
                    ) { rotatedImage, outputURL in
                        viewModel.addHistoryRecord(
                            fileName: rotateFileName,
                            thumbnail: rotatedImage,
                            outputURL: outputURL,
                            toolType: "Rotate"
                        )
                        DispatchQueue.main.async {
                            showRotateView = false
                            showAssetPicker = false
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showCropView) {
                if let image = cropImage {
                    ImageCropView(
                        image: image,
                        fileName: cropFileName
                    ) { croppedImage, outputURL in
                        viewModel.addHistoryRecord(
                            fileName: cropFileName,
                            thumbnail: croppedImage,
                            outputURL: outputURL,
                            toolType: "Crop"
                        )
                        DispatchQueue.main.async {
                            showCropView = false
                            showAssetPicker = false
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showResizeView) {
                if let image = resizeImage {
                    ImageResizeView(
                        image: image,
                        fileName: resizeFileName
                    ) { resizedImage, outputURL in
                        viewModel.addHistoryRecord(
                            fileName: resizeFileName,
                            thumbnail: resizedImage,
                            outputURL: outputURL,
                            toolType: "Resize"
                        )
                        DispatchQueue.main.async {
                            showResizeView = false
                            showAssetPicker = false
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showCompressView) {
                if let image = compressImage, let url = compressFileURL {
                    ImageCompressView(
                        image: image,
                        fileName: compressFileName,
                        fileURL: url
                    ) { compressedImage, outputURL in
                        viewModel.addHistoryRecord(
                            fileName: outputURL.lastPathComponent,
                            thumbnail: compressedImage,
                            outputURL: outputURL,
                            toolType: "Compress"
                        )
                        DispatchQueue.main.async {
                            showCompressView = false
                            showAssetPicker = false
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showGifView) {
                if !gifImages.isEmpty {
                    MakeGifView(
                        images: gifImages,
                        fileNames: gifFileNames
                    ) { thumbnail, outputURL in
                        viewModel.addHistoryRecord(
                            fileName: "animated.gif",
                            thumbnail: thumbnail,
                            outputURL: outputURL,
                            toolType: "GIF"
                        )
                        DispatchQueue.main.async {
                            showGifView = false
                            showGifPicker = false
                            selectedTab = .history
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showStitchView) {
                if !stitchImages.isEmpty {
                    ImageStitchView(
                        images: stitchImages,
                        fileNames: stitchFileNames
                    ) { thumbnail, outputURL in
                        viewModel.addHistoryRecord(
                            fileName: "stitched.png",
                            thumbnail: thumbnail,
                            outputURL: outputURL,
                            toolType: "Stitch"
                        )
                        DispatchQueue.main.async {
                            showStitchView = false
                            showStitchPicker = false
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
        switch activeTool {
        case "convert":
            viewModel.selectImage(image, fileName: fileName, fileURL: url)
        case "rotate":
            rotateImage = image
            rotateFileName = fileName
            rotateFileURL = url
            showRotateView = true
        case "resize":
            resizeImage = image
            resizeFileName = fileName
            showResizeView = true
        case "compress":
            compressImage = image
            compressFileName = fileName
            compressFileURL = url
            showCompressView = true
        case "crop":
            cropImage = image
            cropFileName = fileName
            cropFileURL = url
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
        gifImages = results.map { $0.0 }
        gifFileNames = results.map { $0.1 }
        showGifView = true
    }

    private func handleStitchAssetsSelected(_ results: [(UIImage, String, URL)]) {
        stitchImages = results.map { $0.0 }
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
