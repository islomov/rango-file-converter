import SwiftUI

private enum AudioTab: String, CaseIterable {
    case tools = "Tools"
    case history = "History"
}

private struct AudioTool: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let isAvailable: Bool
}

private let audioTools: [AudioTool] = [
    AudioTool(id: "convert", title: "Format Conversion", subtitle: "Any conversion of multiple formats", icon: "arrow.triangle.2.circlepath", isAvailable: true),
    AudioTool(id: "extract", title: "Extract Audio", subtitle: "Extract audio from video", icon: "music.note", isAvailable: true),
    AudioTool(id: "compress", title: "Audio Compression", subtitle: "Custom compression", icon: "arrow.down.right.and.arrow.up.left", isAvailable: true),
    AudioTool(id: "speed", title: "Audio Speed Change", subtitle: "0.1 to 5 times free adjustment", icon: "gauge.with.dots.needle.33percent", isAvailable: false),
    AudioTool(id: "merge", title: "Combined Audios", subtitle: "Easily merge multiple audios", icon: "square.stack.3d.up", isAvailable: false),
    AudioTool(id: "crop", title: "Audio Cropping", subtitle: "Capture and retain audio clips", icon: "scissors", isAvailable: true),
]

struct AudioConverterView: View {
    @StateObject private var viewModel = AudioConverterViewModel()
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var selectedTab: AudioTab = .tools
    @State private var showAudioPicker = false
    @State private var showExtractVideoPicker = false
    @State private var showCompressPicker = false
    @State private var showComingSoon = false
    @State private var showSettings = false
    @State private var showCropPicker = false
    @State private var showCropView = false
    @State private var cropFileName: String = ""
    @State private var cropFileURL: URL?

    private var history: [ConversionRecord] {
        historyStore.records(for: "audio")
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
                        viewModel.showConversionDetail = false
                        showAudioPicker = false
                        selectedTab = .history
                    }
                }
            }
            .navigationDestination(isPresented: $showExtractVideoPicker) {
                VideoPickerView { thumbnail, fileName, url in
                    viewModel.selectVideoForExtractAudio(thumbnail: thumbnail, fileName: fileName, fileURL: url)
                }
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
                        viewModel.showCompressDetail = false
                        showCompressPicker = false
                        selectedTab = .history
                    }
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
                        viewModel.showExtractAudioDetail = false
                        showExtractVideoPicker = false
                        selectedTab = .history
                    }
                }
            }
            .navigationDestination(isPresented: $showCropPicker) {
                AudioPickerView { fileName, url in
                    cropFileName = fileName
                    cropFileURL = url
                    showCropView = true
                }
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
                        showCropView = false
                        showCropPicker = false
                        selectedTab = .history
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
            Text("Audio")
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
            ForEach(AudioTab.allCases, id: \.self) { tab in
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
                ForEach(audioTools) { tool in
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

    private func toolCard(_ tool: AudioTool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: tool.icon)
                .font(.title2)
            Text(tool.title)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
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

    private func handleToolTap(_ tool: AudioTool) {
        if tool.isAvailable {
            switch tool.id {
            case "convert":
                showAudioPicker = true
            case "extract":
                showExtractVideoPicker = true
            case "compress":
                showCompressPicker = true
            case "crop":
                showCropPicker = true
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
    AudioConverterView()
        .environmentObject(HistoryStore.shared)
}
