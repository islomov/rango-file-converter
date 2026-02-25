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

    @State private var outputFormat: MergeOutputFormat = .mp4
    @State private var durations: [URL: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            videoList
            controls
        }
        .navigationTitle("Merge")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDurations() }
    }

    // MARK: - Video List

    private var videoList: some View {
        List {
            ForEach(Array(videos.enumerated()), id: \.offset) { index, video in
                HStack(spacing: 12) {
                    Image(uiImage: video.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.fileName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        Text(durations[video.url] ?? "0:00")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .onMove { from, to in
                videos.move(fromOffsets: from, toOffset: to)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Output Format")
                    .font(.subheadline.weight(.medium))
                Picker("Format", selection: $outputFormat) {
                    ForEach(MergeOutputFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Text("\(videos.count) videos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button {
                let thumbnail = videos.first?.thumbnail ?? UIImage(systemName: "video")!
                onApply(outputFormat.fileExtension, thumbnail)
            } label: {
                Text("Merge Videos")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
            .disabled(videos.count < 2)
        }
        .padding(20)
        .background(.bar)
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
