import SwiftUI
import Photos
import UniformTypeIdentifiers

enum AssetPickerMode {
    case single
    case multiple(minCount: Int)
}

private enum AssetSource: String, CaseIterable {
    case gallery = "Gallery"
    case files = "Files"
}

struct AssetPickerView: View {
    let mode: AssetPickerMode
    var onImageSelected: ((UIImage, String, URL) -> Void)?
    var onMultipleSelected: (([(UIImage, String, URL)]) -> Void)?

    init(onImageSelected: @escaping (UIImage, String, URL) -> Void) {
        self.mode = .single
        self.onImageSelected = onImageSelected
        self.onMultipleSelected = nil
    }

    init(mode: AssetPickerMode, onMultipleSelected: @escaping ([(UIImage, String, URL)]) -> Void) {
        self.mode = mode
        self.onImageSelected = nil
        self.onMultipleSelected = onMultipleSelected
    }

    @State private var photoVM = PhotoLibraryViewModel()
    @State private var selectedSource: AssetSource = .gallery
    @State private var showFilePicker = false
    @State private var isLoadingFullImage = false
    @Environment(\.dismiss) private var dismiss

    // Multi-select state
    @State private var selectedAssetIDs: Set<String> = []
    @State private var selectionOrderList: [String] = []

    private var isMultiSelect: Bool {
        if case .multiple = mode { return true }
        return false
    }

    private var minCount: Int {
        if case .multiple(let min) = mode { return min }
        return 1
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        VStack(spacing: 0) {
            content

            if isMultiSelect {
                multiSelectBar
            } else {
                sourceBar
            }
        }
        .navigationTitle(isMultiSelect ? "Select Images" : "Select Image")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            photoVM.requestAccessAndFetch()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.image],
            allowsMultipleSelection: isMultiSelect
        ) { result in
            handleFileImport(result)
        }
        .overlay {
            if isLoadingFullImage {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView(isMultiSelect ? "Loading \(selectedAssetIDs.count) images..." : "Loading...")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSource {
        case .gallery:
            galleryGrid
        case .files:
            filesPlaceholder
        }
    }

    private var galleryGrid: some View {
        Group {
            switch photoVM.authorizationStatus {
            case .authorized, .limited:
                if photoVM.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if photoVM.assets.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("No photos found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photoVM.assets, id: \.localIdentifier) { asset in
                                thumbnailCell(for: asset)
                            }
                        }
                    }
                }
            case .denied, .restricted:
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Photo access denied")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            default:
                Spacer()
                ProgressView("Requesting access...")
                Spacer()
            }
        }
    }

    private func thumbnailCell(for asset: PHAsset) -> some View {
        Button {
            if isMultiSelect {
                toggleSelection(asset)
            } else {
                selectAsset(asset)
            }
        } label: {
            GeometryReader { geo in
                ZStack(alignment: .topTrailing) {
                    if let thumbnail = photoVM.thumbnails[asset.localIdentifier] {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(width: geo.size.width, height: geo.size.width)
                            .onAppear {
                                photoVM.loadThumbnail(for: asset)
                            }
                    }

                    if isMultiSelect {
                        let isSelected = selectedAssetIDs.contains(asset.localIdentifier)
                        let idx = selectionOrder(for: asset)
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.pink : Color.black.opacity(0.3))
                                .frame(width: 26, height: 26)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 26, height: 26)
                            if isSelected, let idx {
                                Text("\(idx)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .disabled(isLoadingFullImage)
    }

    // MARK: - Multi-select

    private func toggleSelection(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
            selectionOrderList.removeAll { $0 == id }
        } else {
            selectedAssetIDs.insert(id)
            selectionOrderList.append(id)
        }
    }

    private func selectionOrder(for asset: PHAsset) -> Int? {
        guard let idx = selectionOrderList.firstIndex(of: asset.localIdentifier) else { return nil }
        return idx + 1
    }

    private var multiSelectBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                HStack(spacing: 16) {
                    Button {
                        selectedSource = .gallery
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.body)
                            Text("Gallery")
                                .font(.caption2)
                        }
                        .foregroundStyle(selectedSource == .gallery ? .primary : .secondary)
                    }

                    Button {
                        selectedSource = .files
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "folder")
                                .font(.body)
                            Text("Files")
                                .font(.caption2)
                        }
                        .foregroundStyle(selectedSource == .files ? .primary : .secondary)
                    }
                }

                Spacer()

                Text("\(selectedAssetIDs.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Done") {
                    loadSelectedAndFinish()
                }
                .font(.headline)
                .disabled(selectedAssetIDs.count < minCount || isLoadingFullImage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func loadSelectedAndFinish() {
        let orderedAssets = selectionOrderList.compactMap { id in
            photoVM.assets.first { $0.localIdentifier == id }
        }
        guard orderedAssets.count >= minCount else { return }

        isLoadingFullImage = true
        Task {
            let results = await photoVM.loadFullImages(for: orderedAssets)
            isLoadingFullImage = false
            if results.count >= minCount {
                onMultipleSelected?(results)
            }
        }
    }

    // MARK: - Source Bar (single mode)

    private var sourceBar: some View {
        HStack(spacing: 0) {
            ForEach(AssetSource.allCases, id: \.self) { source in
                Button {
                    selectedSource = source
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: source == .gallery ? "photo.on.rectangle" : "folder")
                            .font(.title3)
                        Text(source.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(selectedSource == source ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.top, 4)
        .background(.bar)
    }

    private var filesPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Browse files on your device")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Open File Browser") {
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Single select

    private func selectAsset(_ asset: PHAsset) {
        isLoadingFullImage = true
        Task {
            if let (image, fileName, url) = await photoVM.loadFullImage(for: asset) {
                isLoadingFullImage = false
                onImageSelected?(image, fileName, url)
            } else {
                isLoadingFullImage = false
            }
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        if isMultiSelect {
            var results: [(UIImage, String, URL)] = []
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                guard (try? FileManager.default.copyItem(at: url, to: tempURL)) != nil else { continue }
                guard let data = try? Data(contentsOf: tempURL),
                      let image = UIImage(data: data) else { continue }
                results.append((image, url.lastPathComponent, tempURL))
            }
            if results.count >= minCount {
                onMultipleSelected?(results)
            }
        } else {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            guard (try? FileManager.default.copyItem(at: url, to: tempURL)) != nil else { return }
            guard let data = try? Data(contentsOf: tempURL),
                  let image = UIImage(data: data) else { return }
            onImageSelected?(image, url.lastPathComponent, tempURL)
        }
    }
}
