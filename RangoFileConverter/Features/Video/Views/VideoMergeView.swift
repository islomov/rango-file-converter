import SwiftUI
import AVFoundation

private enum MergeOutputFormat: String, CaseIterable {
    case mp4 = "MP4"
    case mov = "MOV"
    case mkv = "MKV"

    var fileExtension: String { rawValue.lowercased() }
}

struct VideoMergeView: View {
    @State var videos: [(thumbnail: UIImage, fileName: String, url: URL)]
    let onApply: (String, UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var outputFormat: MergeOutputFormat = .mp4
    @State private var durations: [URL: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            header
            videoList
            bottomSection
        }
        .background(AppColors.surface)
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .task { await loadDurations() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Merge video")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AppColors.textSecondary.opacity(0.08)))
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - Video List

    private var videoList: some View {
        List {
            ForEach(Array(videos.enumerated()), id: \.element.url) { index, video in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)
                        .frame(width: 20)

                    Image(uiImage: video.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8.32))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.fileName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(-0.408)
                            .lineLimit(1)

                        Text(durations[video.url] ?? "0:00")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(-0.408)
                    }

                    Spacer()
                }
                .padding(.vertical, 12)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.12))
                        .frame(height: 1)
                        .padding(.leading, 84)
                }
            }
            .onMove { from, to in
                videos.move(fromOffsets: from, toOffset: to)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 0) {
                // Output format
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output format")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)

                    HStack(spacing: 8) {
                        ForEach(MergeOutputFormat.allCases, id: \.self) { format in
                            Button {
                                outputFormat = format
                            } label: {
                                Text(format.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .tracking(-0.408)
                                    .foregroundColor(outputFormat == format ? .white : AppColors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(
                                            outputFormat == format
                                                ? AppColors.accent
                                                : AppColors.textSecondary.opacity(0.08)
                                        )
                                    )
                            }
                        }
                    }
                }
                .padding(16)

                // Merge button
                Button {
                    let thumbnail = videos.first?.thumbnail ?? UIImage(systemName: "video")!
                    onApply(outputFormat.fileExtension, thumbnail)
                } label: {
                    Text("Merge video")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(-0.408)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(mergeButtonGradient)
                        )
                }
                .disabled(videos.count < 2)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
    }

    private var mergeButtonGradient: LinearGradient {
        if videos.count < 2 {
            return LinearGradient(
                colors: [AppColors.buttonDisabledStart, AppColors.buttonDisabledMid, AppColors.buttonDisabledStart],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        } else {
            return LinearGradient(
                colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

    // MARK: - Helpers

    private func loadDurations() async {
        for video in videos {
            let asset = AVAsset(url: video.url)
            if let cmDuration = try? await asset.load(.duration) {
                let seconds = CMTimeGetSeconds(cmDuration)
                if seconds.isFinite {
                    let mins = Int(seconds) / 60
                    let secs = Int(seconds) % 60
                    durations[video.url] = String(format: "%d:%02d", mins, secs)
                }
            }
        }
    }
}
