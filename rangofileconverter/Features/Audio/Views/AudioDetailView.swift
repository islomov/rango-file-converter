import SwiftUI

struct AudioDetailView: View {
    let fileName: String
    let fileURL: URL
    let onConvert: (FormatDefinition) -> Void

    private static let supportedAudioFormats = FormatRegistry.audioFormats

    @State private var targetFormat: FormatDefinition = FormatRegistry.audioFormats[0] // MP3
    @State private var isConverting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Audio icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .frame(height: 200)

                    VStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text(sourceExtension.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.secondary, in: Capsule())
                    }
                }

                // File info
                VStack(alignment: .leading, spacing: 8) {
                    Text(fileName)
                        .font(.headline)
                    Text(formattedFileSize)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Format selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Convert to")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(Self.supportedAudioFormats) { format in
                            Button(format.displayName) {
                                targetFormat = format
                            }
                            .buttonStyle(.bordered)
                            .tint(targetFormat.id == format.id ? .accentColor : .secondary)
                        }
                    }
                }

                // Convert button
                Button {
                    isConverting = true
                    onConvert(targetFormat)
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
        .navigationTitle("Audio Conversion")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sourceExtension: String {
        fileName.components(separatedBy: ".").last ?? ""
    }

    private var formattedFileSize: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64 else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
