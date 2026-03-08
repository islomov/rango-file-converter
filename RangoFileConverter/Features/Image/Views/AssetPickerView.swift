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

    @StateObject private var photoVM = PhotoLibraryViewModel()
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
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom navigation bar
                navBar

                // Gallery / Files toggle
                sourceToggle
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Content
                content

                if isMultiSelect {
                    multiSelectBar
                }
            }
        }
        .navigationBarHidden(true)
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
                        ProgressView {
                            if isMultiSelect {
                                Text("Loading \(selectedAssetIDs.count) images...")
                            } else {
                                Text("Loading...")
                            }
                        }
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
    }

    // MARK: - Navigation Bar

    private var navBar: some View {
        ZStack {
            Group {
                if isMultiSelect {
                    Text("Select images")
                } else {
                    Text("Choose image")
                }
            }
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                }

                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - Source Toggle

    private var sourceToggle: some View {
        HStack(spacing: 0) {
            ForEach(AssetSource.allCases, id: \.self) { source in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSource = source
                    }
                } label: {
                    Text(LocalizedStringKey(source.rawValue))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Group {
                                if selectedSource == source {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppColors.surface)
                                        .shadow(color: AppColors.textPrimary.opacity(0.12), radius: 4, x: 0, y: 0)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
        )
    }

    // MARK: - Content

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
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(photoVM.assets, id: \.localIdentifier) { asset in
                                thumbnailCell(for: asset)
                            }
                        }
                        .padding(.horizontal, 16)
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
                            .fill(AppColors.placeholder)
                            .frame(width: geo.size.width, height: geo.size.width)
                    }

                    if isMultiSelect {
                        let isSelected = selectedAssetIDs.contains(asset.localIdentifier)
                        let idx = selectionOrder(for: asset)
                        ZStack {
                            Circle()
                                .fill(isSelected ? AppColors.accent : Color.black.opacity(0.3))
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
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                photoVM.loadThumbnail(for: asset)
            }
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
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)
            HStack {
                Text("\(selectedAssetIDs.count) selected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(-0.408)

                Spacer()

                Button {
                    loadSelectedAndFinish()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: selectedAssetIDs.count >= minCount
                                    ? [AppColors.buttonGradientStart, AppColors.buttonGradientEnd]
                                    : [AppColors.buttonDisabledStart, AppColors.buttonDisabledMid, AppColors.buttonDisabledStart],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedAssetIDs.count < minCount || isLoadingFullImage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(AppColors.surface)
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

    // MARK: - Files Placeholder

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

        isLoadingFullImage = true
        let isMulti = isMultiSelect
        let min = minCount

        Task.detached(priority: .userInitiated) {
            if isMulti {
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
                await MainActor.run {
                    isLoadingFullImage = false
                    if results.count >= min {
                        onMultipleSelected?(results)
                    }
                }
            } else {
                guard let url = urls.first else {
                    await MainActor.run { isLoadingFullImage = false }
                    return
                }
                guard url.startAccessingSecurityScopedResource() else {
                    await MainActor.run { isLoadingFullImage = false }
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                guard (try? FileManager.default.copyItem(at: url, to: tempURL)) != nil else {
                    await MainActor.run { isLoadingFullImage = false }
                    return
                }
                guard let data = try? Data(contentsOf: tempURL),
                      let image = UIImage(data: data) else {
                    await MainActor.run { isLoadingFullImage = false }
                    return
                }
                let name = url.lastPathComponent
                await MainActor.run {
                    isLoadingFullImage = false
                    onImageSelected?(image, name, tempURL)
                }
            }
        }
    }
}
