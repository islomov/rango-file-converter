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

    @Environment(\.dismiss) private var dismiss
    @State private var outputFormat: AudioMergeOutputFormat = .mp3

    var body: some View {
        VStack(spacing: 0) {
            header
            audioList
            bottomSection
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .task { await loadDurations() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Merge audio")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color(hex: "888888").opacity(0.08)))
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - Audio List

    private var audioList: some View {
        List {
            ForEach(Array(audios.enumerated()), id: \.element.id) { index, audio in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "888888"))
                        .tracking(-0.408)
                        .frame(width: 20)

                    ZStack {
                        RoundedRectangle(cornerRadius: 8.32)
                            .fill(Color(hex: "E6E6EC"))
                            .frame(width: 56, height: 56)

                        Image("icon_musicnote_bold")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color(hex: "888888"))
                            .frame(width: 24, height: 24)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(audio.fileName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "1D1D1D"))
                            .tracking(-0.408)
                            .lineLimit(1)

                        Text(audio.duration)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "888888"))
                            .tracking(-0.408)
                    }

                    Spacer()
                }
                .padding(.vertical, 12)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(hex: "888888").opacity(0.12))
                        .frame(height: 1)
                        .padding(.leading, 48)
                }
            }
            .onMove { from, to in
                audios.move(fromOffsets: from, toOffset: to)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "565656").opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: "565656").opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 0) {
                // Output format
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output format")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "888888"))
                        .tracking(-0.408)

                    HStack(spacing: 8) {
                        ForEach(AudioMergeOutputFormat.allCases, id: \.self) { format in
                            Button {
                                outputFormat = format
                            } label: {
                                Text(format.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .tracking(-0.408)
                                    .foregroundColor(outputFormat == format ? .white : Color(hex: "1D1D1D"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(
                                            outputFormat == format
                                                ? Color(hex: "F4800D")
                                                : Color(hex: "888888").opacity(0.08)
                                        )
                                    )
                            }
                        }
                    }
                }
                .padding(16)

                // Combine button
                Button {
                    onApply(outputFormat.fileExtension)
                } label: {
                    Text("Combine audios")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(-0.408)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(combineButtonGradient)
                        )
                }
                .disabled(audios.count < 2)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
    }

    private var combineButtonGradient: LinearGradient {
        if audios.count < 2 {
            return LinearGradient(
                colors: [Color(hex: "FFD9B8"), Color(hex: "F8C192"), Color(hex: "FFD9B8")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
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