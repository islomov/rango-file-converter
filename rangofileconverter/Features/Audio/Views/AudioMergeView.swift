import SwiftUI
import AVFoundation

private enum AudioMergeOutputFormat: String, CaseIterable {
    case mp3 = "MP3"
    case wav = "WAV"
    case m4a = "M4A"
    case flac = "FLAC"
    case aac = "AAC"

    var fileExtension: String { rawValue.lowercased() }
}

struct AudioMergeView: View {
    @State var audios: [MergeAudioItem]
    let onApply: (String) -> Void

    @State private var outputFormat: AudioMergeOutputFormat = .mp3

    var body: some View {
        VStack(spacing: 0) {
            audioList
            controls
        }
        .navigationTitle("Merge Audios")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDurations() }
    }

    // MARK: - Audio List

    private var audioList: some View {
        List {
            ForEach(audios) { audio in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.quaternary)
                            .frame(width: 44, height: 44)
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(audio.fileName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        Text(audio.duration)
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
                audios.move(fromOffsets: from, toOffset: to)
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
                    ForEach(AudioMergeOutputFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Text("\(audios.count) audios")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button {
                onApply(outputFormat.fileExtension)
            } label: {
                Text("Merge Audios")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
            .disabled(audios.count < 2)
        }
        .padding(20)
        .background(.bar)
    }

    // MARK: - Helpers

    private func loadDurations() async {
        var loaded: [UUID: String] = [:]
        for audio in audios {
            let asset = AVAsset(url: audio.url)
            if let cmDuration = try? await asset.load(.duration) {
                let seconds = CMTimeGetSeconds(cmDuration)
                if seconds.isFinite {
                    let mins = Int(seconds) / 60
                    let secs = Int(seconds) % 60
                    loaded[audio.id] = String(format: "%d:%02d", mins, secs)
                }
            }
        }
        for i in audios.indices {
            if let dur = loaded[audios[i].id] {
                audios[i].duration = dur
            }
        }
    }
}

struct MergeAudioItem: Identifiable {
    let id = UUID()
    let fileName: String
    let url: URL
    var duration: String = "0:00"
}
