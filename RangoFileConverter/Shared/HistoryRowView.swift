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
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.placeholder)
                    .frame(width: 56, height: 56)
                    .overlay(
                        placeholderIcon
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(record.sourceFileName)
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    toolBadge

                    HStack(spacing: 4) {
                        Text(record.sourceFormat.uppercased())
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundColor(AppColors.textPrimary)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)

                        Text(record.targetFormat.displayName)
                            .font(.custom("Montserrat-SemiBold", size: 12))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }

            Spacer(minLength: 4)

            // Status + date
            VStack(alignment: .trailing, spacing: 4) {
                statusBadge

                Text(formattedDate)
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundColor(AppColors.textSecondary)
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
                .foregroundColor(AppColors.textTertiary)
        case "audio":
            Image(systemName: "music.note")
                .font(.system(size: 18))
                .foregroundColor(AppColors.textTertiary)
        case "document":
            Image(systemName: "doc.fill")
                .font(.system(size: 18))
                .foregroundColor(AppColors.textTertiary)
        default:
            Image(systemName: "photo.fill")
                .font(.system(size: 18))
                .foregroundColor(AppColors.textTertiary)
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
        switch record.tool {
        case .convert: return "Convert:"
        case .compress: return "Compress:"
        case .rotate: return "Rotate:"
        case .resize: return "Resize:"
        case .crop: return "Crop:"
        case .gif: return "GIF"
        case .stitch: return "Stitch"
        case .merge: return "Merge:"
        case .speed: return "Speed:"
        case .timeClip: return "Time Clip:"
        case .extractAudio: return "Extract Audio:"
        case .ratio: return "Ratio:"
        case .mergePDF: return "Merge PDF:"
        case .splitPDF: return "Split PDF:"
        case .reorderPDF: return "Reorder PDF:"
        case .protectPDF: return "Protect PDF:"
        }
    }

    @ViewBuilder
    private var toolBadgeBackground: some View {
        switch record.tool {
        case .convert:
            LinearGradient(
                colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case .compress:
            Color(hex: "43CF18")
        case .rotate:
            AppColors.textPrimary
        case .resize:
            Color(hex: "196EDD")
        case .crop:
            Color(hex: "14C5A2")
        case .stitch:
            Color(hex: "E5A800")
        case .gif:
            AppColors.error
        case .speed:
            Color(hex: "9B59B6")
        case .timeClip:
            Color(hex: "E67E22")
        case .extractAudio:
            AppColors.info
        case .ratio:
            AppColors.success
        case .merge:
            Color(hex: "E74C3C")
        case .mergePDF:
            Color(hex: "8E44AD")
        case .splitPDF:
            Color(hex: "2980B9")
        case .reorderPDF:
            Color(hex: "27AE60")
        case .protectPDF:
            Color(hex: "C0392B")
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
                    .foregroundColor(AppColors.accent)
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.accent)
            }
        case .converting:
            HStack(spacing: 4) {
                Text("\(Int(record.progress * 100))%")
                    .font(.custom("Montserrat-SemiBold", size: 12))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                ProgressView()
                    .controlSize(.mini)
                    .tint(AppColors.accent)
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
                    .foregroundColor(AppColors.destructive)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.destructive)
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
