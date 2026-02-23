import SwiftUI

struct HistoryRowView: View {
    @ObservedObject var record: ConversionRecord

    var body: some View {
        HStack(spacing: 12) {
            if let thumbnail = record.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: record.mediaCategory == "video" ? "video" : "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.sourceFileName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(record.toolType)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(toolColor, in: Capsule())

                    Text("\(record.sourceFormat) → \(record.targetFormat.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                statusBadge

                if record.status == .converted, let outputURL = record.outputURL {
                    ShareLink(item: outputURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.caption2)
                    }
                }

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var toolColor: Color {
        switch record.toolType {
        case "Rotate": return .blue
        case "Compress": return .purple
        case "Resize": return .orange
        case "Crop": return .teal
        case "GIF": return .pink
        case "Stitch": return .mint
        default: return .green
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: record.date)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch record.status {
        case .pending:
            Label("Pending", systemImage: "clock")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .converting:
            HStack(spacing: 4) {
                if record.progress > 0 {
                    ProgressView(value: record.progress)
                        .progressViewStyle(.circular)
                        .controlSize(.mini)
                    Text("\(Int(record.progress * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.blue)
                } else {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Starting...")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        case .converted:
            Label("Done", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .failed:
            Label("Failed", systemImage: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}
