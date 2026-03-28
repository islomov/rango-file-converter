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
        .task {
            photoVM.requestAccessAndFetch()
        }
        .typedFilePicker(
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
                    Image(systemName: "chevron.backward")
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
                        .foregroundColor(selectedSource == source ? .white : AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .contentShape(Rectangle())
                        .background(
                            Group {
                                if selectedSource == source {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppColors.accent)
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
                } else if photoVM.assetCount == 0 {
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
                            ForEach(0..<photoVM.assetCount, id: \.self) { index in
                                if let asset = photoVM.asset(at: index) {
                                    thumbnailCell(for: asset)
                                }
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
        AssetThumbnailCell(
            asset: asset,
            isMultiSelect: isMultiSelect,
            isSelected: selectedAssetIDs.contains(asset.localIdentifier),
            selectionIndex: selectionOrder(for: asset),
            isDisabled: isLoadingFullImage
        ) {
            if isMultiSelect {
                toggleSelection(asset)
            } else {
                selectAsset(asset)
            }
        }
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
        let orderedAssets: [PHAsset] = selectionOrderList.compactMap { id in
            guard let fetchResult = photoVM.fetchResult else { return nil }
            let opts = PHFetchOptions()
            opts.predicate = NSPredicate(format: "localIdentifier == %@", id)
            return PHAsset.fetchAssets(with: opts).firstObject
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
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.10))
                        .frame(width: 80, height: 80)
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }

                VStack(spacing: 8) {
                    Text("Browse image files on your device")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .multilineTextAlignment(.center)

                    Text("Import from Files app")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                }
            }

            Button {
                showFilePicker = true
            } label: {
                Text("Open File Browser")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .padding(16)
                    .frame(width: 200)
                    .background(
                        LinearGradient(
                            colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

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
