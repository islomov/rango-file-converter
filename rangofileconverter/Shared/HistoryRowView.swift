import SwiftUI

struct HistoryRowView: View {
    @ObservedObject var record: ConversionRecord

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with rounded border
            if let thumbnail = record.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "E0E0E6"), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "E6E6EC"))
                    .frame(width: 56, height: 56)
                    .overlay(
                        placeholderIcon
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "E0E0E6"), lineWidth: 1)
                    )
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(record.sourceFileName)
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(Color(hex: "1D1D1D"))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    toolBadge

                    HStack(spacing: 4) {
                        Text(record.sourceFormat.uppercased())
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundColor(Color(hex: "1D1D1D"))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "1D1D1D"))

                        Text(record.targetFormat.displayName)
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundColor(Color(hex: "1D1D1D"))
                    }
                }
            }

            Spacer(minLength: 4)

            // Status + date
            VStack(alignment: .trailing, spacing: 4) {
                statusBadge

                Text(formattedDate)
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "888888"))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Placeholder Icon

    @ViewBuilder
    private var placeholderIcon: some View {
        switch record.mediaCategory {
        case "video":
            Image(systemName: "video.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "B0B0B8"))
        case "audio":
            Image(systemName: "music.note")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "B0B0B8"))
        case "document":
            Image(systemName: "doc.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "B0B0B8"))
        default:
            Image(systemName: "photo.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "B0B0B8"))
        }
    }

    // MARK: - Tool Badge

    @ViewBuilder
    private var toolBadge: some View {
        let label = toolLabel
        Text(label)
            .font(.custom("Montserrat-SemiBold", size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(toolBadgeBackground)
            .clipShape(Capsule())
    }

    private var toolLabel: String {
        switch record.toolType {
        case "Convert": return "Convert:"
        case "Compress": return "Compress:"
        case "Rotate": return "Rotate:"
        case "Resize": return "Resize:"
        case "Crop": return "Crop:"
        case "GIF": return "GIF"
        case "Stitch": return "Stitch"
        case "Merge": return "Merge:"
        case "Split": return "Split:"
        default: return "\(record.toolType):"
        }
    }

    @ViewBuilder
    private var toolBadgeBackground: some View {
        switch record.toolType {
        case "Convert":
            LinearGradient(
                colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case "Compress":
            Color(hex: "43CF18")
        case "Rotate":
            Color(hex: "1D1D1D")
        case "Resize":
            Color(hex: "196EDD")
        case "Crop":
            Color(hex: "14C5A2")
        case "Stitch":
            Color(hex: "E5A800")
        case "GIF":
            Color(hex: "FF4D4D")
        default:
            Color(hex: "F4800D")
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        switch record.status {
        case .pending:
            HStack(spacing: 4) {
                Text("Pending")
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "F4800D"))
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "F4800D"))
            }
        case .converting:
            HStack(spacing: 4) {
                Text("\(Int(record.progress * 100))%")
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                ProgressView()
                    .controlSize(.mini)
                    .tint(Color(hex: "F4800D"))
            }
        case .converted:
            HStack(spacing: 4) {
                Text("Done")
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "22C713"))
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "22C713"))
            }
        case .failed:
            HStack(spacing: 4) {
                Text("Fail")
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "F21414"))
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "F21414"))
            }
        }
    }

    // MARK: - Date Formatting

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: record.date)
    }
}
