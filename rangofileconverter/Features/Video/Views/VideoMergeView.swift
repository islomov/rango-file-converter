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

    var body: some View {
        VStack(spacing: 0) {
            videoList
            controls
        }
        .navigationTitle("Merge")
        .navigationBarTitleDisplayMode(.inline)
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

                        Text(videoDuration(url: video.url))
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

    private func videoDuration(url: URL) -> String {
        let asset = AVAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite else { return "0:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
