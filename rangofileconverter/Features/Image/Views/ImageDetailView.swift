import SwiftUI

struct ImageDetailView: View {
    let fileURL: URL
    let fileName: String
    let onConvert: (FormatDefinition) -> Void

    @State private var previewImage: UIImage?
    @State private var targetFormat: FormatDefinition = FormatRegistry.imageFormats[1] // JPEG
    @State private var fileSizeText: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                } else {
                    ProgressView()
                        .frame(height: 350)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(fileName)
                        .font(.headline)
                    Text(fileSizeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Convert to")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(FormatRegistry.imageFormats) { format in
                            Button(format.displayName) {
                                targetFormat = format
                            }
                            .buttonStyle(.bordered)
                            .tint(targetFormat.id == format.id ? .accentColor : .secondary)
                        }
                    }
                }

                Button {
                    onConvert(targetFormat)
                } label: {
                    Text("Convert")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .navigationTitle("Convert Image")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let url = fileURL
            let result = await Task.detached(priority: .userInitiated) {
                let image = ImageConverterViewModel.loadPreviewImage(from: url)
                let size: String
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let bytes = attrs[.size] as? Int64 {
                    let formatter = ByteCountFormatter()
                    formatter.countStyle = .file
                    size = formatter.string(fromByteCount: bytes)
                } else {
                    size = ""
                }
                return (image, size)
            }.value
            previewImage = result.0
            fileSizeText = result.1
        }
    }
}
