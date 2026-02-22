import SwiftUI

struct VideoDetailView: View {
    let thumbnail: UIImage
    let fileName: String
    let fileURL: URL
    let onConvert: (FormatDefinition) async -> Void

    private static let unsupportedFormats: Set<String> = ["webm", "ogv", "swf", "amv"]
    private static let supportedVideoFormats = FormatRegistry.videoFormats.filter { !unsupportedFormats.contains($0.id) }

    @State private var targetFormat: FormatDefinition = FormatRegistry.videoFormats[0] // MP4
    @State private var isConverting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(fileName)
                        .font(.headline)
                    Text(formattedFileSize)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Convert to")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(Self.supportedVideoFormats) { format in
                            Button(format.displayName) {
                                targetFormat = format
                            }
                            .buttonStyle(.bordered)
                            .tint(targetFormat.id == format.id ? .accentColor : .secondary)
                        }
                    }
                }

                Button {
                    isConverting = true
                    Task {
                        await onConvert(targetFormat)
                        isConverting = false
                        dismiss()
                    }
                } label: {
                    if isConverting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Convert")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConverting)
            }
            .padding(20)
        }
        .navigationTitle("Convert Video")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formattedFileSize: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64 else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
