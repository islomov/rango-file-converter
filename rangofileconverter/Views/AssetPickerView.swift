import SwiftUI
import Photos
import UniformTypeIdentifiers

private enum AssetSource: String, CaseIterable {
    case gallery = "Gallery"
    case files = "Files"
}

struct AssetPickerView: View {
    let onImageSelected: (UIImage, String, URL) -> Void

    @State private var photoVM = PhotoLibraryViewModel()
    @State private var selectedSource: AssetSource = .gallery
    @State private var showFilePicker = false
    @State private var isLoadingFullImage = false
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        VStack(spacing: 0) {
            content
            sourceBar
        }
        .navigationTitle("Select Image")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            photoVM.requestAccessAndFetch()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.image],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .overlay {
            if isLoadingFullImage {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Loading...")
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
            selectAsset(asset)
        } label: {
            GeometryReader { geo in
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
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .disabled(isLoadingFullImage)
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

    private func selectAsset(_ asset: PHAsset) {
        isLoadingFullImage = true
        Task {
            if let (image, fileName, url) = await photoVM.loadFullImage(for: asset) {
                isLoadingFullImage = false
                onImageSelected(image, fileName, url)
            } else {
                isLoadingFullImage = false
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tempURL)
        guard (try? FileManager.default.copyItem(at: url, to: tempURL)) != nil else { return }

        guard let data = try? Data(contentsOf: tempURL),
              let image = UIImage(data: data) else { return }

        onImageSelected(image, url.lastPathComponent, tempURL)
    }
}
