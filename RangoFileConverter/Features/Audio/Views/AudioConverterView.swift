import SwiftUI

private struct AudioTool: Identifiable, Hashable {
    let id: String
    let title: LocalizedStringKey
    let icon: String
    let isAvailable: Bool

    init(id: String, title: LocalizedStringKey, icon: String, isAvailable: Bool = true) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isAvailable = isAvailable
    }

    static func == (lhs: AudioTool, rhs: AudioTool) -> Bool {
        lhs.id == rhs.id && lhs.icon == rhs.icon && lhs.isAvailable == rhs.isAvailable
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(icon)
        hasher.combine(isAvailable)
    }
}

private let audioTools: [AudioTool] = [
    AudioTool(id: "convert", title: "Convert", icon: "icon_convert"),
    AudioTool(id: "extract", title: "Extract audio", icon: "icon_extract_audio"),
    AudioTool(id: "compress", title: "Compress", icon: "icon_compress"),
    AudioTool(id: "speed", title: "Speed change", icon: "icon_speed"),
    AudioTool(id: "merge", title: "Merge audio", icon: "icon_merge"),
    AudioTool(id: "crop", title: "Audio cropping", icon: "icon_clip"),
]

struct AudioConverterView: View {
    var onBack: (() -> Void)?
    var onNavigateToHistory: (() -> Void)?

    @StateObject private var viewModel = AudioConverterViewModel()
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var showAudioPicker = false
    @State private var showSpeedAudioPicker = false
    @State private var showExtractVideoPicker = false
    @State private var showCompressPicker = false
    @State private var showComingSoon = false
    @State private var showCropPicker = false
    @State private var showCropView = false
    @State private var cropFileName: String = ""
    @State private var cropFileURL: URL?

    // Merge tool state
    @State private var showMergePicker = false
    @State private var showMergeView = false
    @State private var mergeAudios: [MergeAudioItem] = []

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
            .navigationDestination(isPresented: $showAudioPicker) {
                ZStack {
                    AudioPickerView { fileName, url in
                        viewModel.selectAudio(fileName: fileName, fileURL: url)
                    }

                    if viewModel.isExtracting {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Extracting audio...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $viewModel.showConversionDetail) {
                if let fileURL = viewModel.selectedFileURL {
                    AudioDetailView(
                        fileName: viewModel.selectedFileName,
                        fileURL: fileURL
                    ) { format in
                        viewModel.convert(
                            inputURL: fileURL,
                            fileName: viewModel.selectedFileName,
                            to: format
                        )
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $showExtractVideoPicker) {
                VideoPickerView { thumbnail, fileName, url in
                    viewModel.selectVideoForExtractAudio(thumbnail: thumbnail, fileName: fileName, fileURL: url)
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $showCompressPicker) {
                ZStack {
                    AudioPickerView { fileName, url in
                        viewModel.selectAudioForCompress(fileName: fileName, fileURL: url)
                    }

                    if viewModel.isExtracting {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Extracting audio...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $viewModel.showCompressDetail) {
                if let fileURL = viewModel.compressFileURL {
                    AudioCompressView(
                        fileName: viewModel.compressFileName,
                        fileURL: fileURL
                    ) { bitrate, sampleRate, format in
                        viewModel.compressAudio(
                            inputURL: fileURL,
                            fileName: viewModel.compressFileName,
                            bitrate: bitrate,
                            sampleRate: sampleRate,
                            outputFormat: format
                        )
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $viewModel.showExtractAudioDetail) {
                if let thumbnail = viewModel.extractThumbnail,
                   let fileURL = viewModel.extractVideoURL {
                    ExtractAudioDetailView(
                        thumbnail: thumbnail,
                        fileName: viewModel.extractFileName,
                        fileURL: fileURL
                    ) { format in
                        viewModel.extractAudio(
                            inputURL: fileURL,
                            fileName: viewModel.extractFileName,
                            thumbnail: thumbnail,
                            to: format
                        )
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $showSpeedAudioPicker) {
                ZStack {
                    AudioPickerView { fileName, url in
                        viewModel.selectAudioForSpeed(fileName: fileName, fileURL: url)
                    }

                    if viewModel.isExtracting {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Extracting audio...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $viewModel.showSpeedDetail) {
                if let fileURL = viewModel.speedFileURL {
                    AudioSpeedDetailView(
                        fileName: viewModel.speedFileName,
                        fileURL: fileURL
                    ) { speed, format in
                        viewModel.convertWithSpeed(
                            inputURL: fileURL,
                            fileName: viewModel.speedFileName,
                            speed: speed,
                            to: format
                        )
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $showCropPicker) {
                AudioPickerView { fileName, url in
                    cropFileName = fileName
                    cropFileURL = url
                    showCropView = true
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $showCropView) {
                if let url = cropFileURL {
                    AudioCropView(
                        fileURL: url,
                        fileName: cropFileName
                    ) { startTime, endTime in
                        viewModel.cropAudio(
                            inputURL: url,
                            fileName: cropFileName,
                            startTime: startTime,
                            endTime: endTime
                        )
                    }
                    .hidesFloatingTabBar()
                }
            }
            .navigationDestination(isPresented: $showMergePicker) {
                AudioMergePickerView { results in
                    mergeAudios = results.map { MergeAudioItem(fileName: $0.fileName, url: $0.url) }
                    showMergeView = true
                }
                .hidesFloatingTabBar()
            }
            .navigationDestination(isPresented: $showMergeView) {
                if !mergeAudios.isEmpty {
                    AudioMergeView(audios: mergeAudios) { outputExtension in
                        viewModel.mergeAudios(
                            inputs: mergeAudios.map(\.url),
                            outputExtension: outputExtension
                        )
                    }
                    .hidesFloatingTabBar()
                }
            }
            .alert("Coming Soon", isPresented: $showComingSoon) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This tool is not available yet. Stay tuned!")
            }
            .onChange(of: viewModel.navigateToHistoryTrigger) { _ in
                showAudioPicker = false
                showSpeedAudioPicker = false
                showExtractVideoPicker = false
                showCompressPicker = false
                showCropPicker = false
                showCropView = false
                showMergePicker = false
                showMergeView = false
                viewModel.showConversionDetail = false
                viewModel.showCompressDetail = false
                viewModel.showExtractAudioDetail = false
                viewModel.showSpeedDetail = false
                onNavigateToHistory?()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Audio")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

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
                ForEach(audioTools) { tool in
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

    private func toolCard(_ tool: AudioTool) -> some View {
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

    private func handleToolTap(_ tool: AudioTool) {
        if tool.isAvailable {
            switch tool.id {
            case "convert":
                showAudioPicker = true
            case "extract":
                showExtractVideoPicker = true
            case "compress":
                showCompressPicker = true
            case "speed":
                showSpeedAudioPicker = true
            case "crop":
                showCropPicker = true
            case "merge":
                showMergePicker = true
            default:
                break
            }
        } else {
            showComingSoon = true
        }
    }
}

#Preview {
    AudioConverterView()
        .environmentObject(HistoryStore.shared)
}
