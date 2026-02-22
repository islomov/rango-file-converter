import SwiftUI

struct HistoryRowView: View {
    let record: ConversionRecord

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
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.sourceFileName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text("\(record.sourceFormat) → \(record.targetFormat.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                statusBadge

                if record.status == .converted, let outputURL = record.outputURL {
                    ShareLink(item: outputURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.caption2)
                    }
                } else {
                    Text(record.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
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
                ProgressView()
                    .controlSize(.mini)
                Text("Converting")
                    .font(.caption2)
                    .foregroundStyle(.blue)
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
