import SwiftUI

struct ImageDetailView: View {
    let image: UIImage
    let fileName: String
    let onConvert: (ImageFormat) -> Void

    @State private var targetFormat: ImageFormat = .jpeg
    @State private var showComingSoon = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 350)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

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

                    Picker("Format", selection: $targetFormat) {
                        ForEach(ImageFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    showComingSoon = true
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
        .alert("Coming Soon", isPresented: $showComingSoon) {
            Button("OK") {
                onConvert(targetFormat)
                dismiss()
            }
        } message: {
            Text("Image conversion is not yet available. This will be added in a future update.")
        }
    }

    private var formattedFileSize: String {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(data.count))
    }
}
