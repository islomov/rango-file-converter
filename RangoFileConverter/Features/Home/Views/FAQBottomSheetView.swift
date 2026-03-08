import SwiftUI

struct FAQBottomSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedIndex: Int? = nil

    private let faqs: [(question: String, answer: String)] = [
        (
            "How do I convert a file?",
            "Tap the category you need (Image, Video, Audio, or Documents) on the Home screen, select your file, choose the output format, and tap Convert. The converted file will be saved to your device."
        ),
        (
            "What file formats are supported?",
            "Rango supports 74 formats across 4 categories: 21 image formats (HEIC, JPEG, PNG, WEBP, etc.), 21 video formats (MP4, AVI, MOV, MKV, etc.), 25 audio formats (MP3, WAV, FLAC, AAC, etc.), and 7 document formats (PDF, DOCX, TXT, etc.)."
        ),
        (
            "Is my data safe?",
            "Yes! All file conversions are processed entirely on your device. Your files are never uploaded to any external server, ensuring complete privacy and security."
        ),
        (
            "Why is my conversion taking long?",
            "Conversion time depends on the file size and format. Large video files may take longer. Make sure your device has enough storage space and try closing other apps to free up memory."
        ),
        (
            "The app keeps crashing",
            "Try restarting the app and make sure your iOS is up to date. If the issue persists, try converting a smaller file first. For large files, ensure you have enough free storage on your device."
        ),
        (
            "Can I convert multiple files at once?",
            "Currently, Rango processes one file at a time to ensure the best quality and performance. Select a file, convert it, then proceed with the next one."
        ),
        (
            "Where are my converted files saved?",
            "Converted files are saved in your device's Files app under the Rango folder. You can also find your conversion history in the History tab."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Grab handle
            Capsule()
                .fill(Color(.quaternaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            // Header
            HStack {
                // Invisible spacer to balance the close button
                Color.clear
                    .frame(width: 40, height: 40)

                Spacer()

                Text("FAQ")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppColors.textSecondary.opacity(0.08))
                            .frame(width: 40, height: 40)

                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // FAQ list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                        FAQItemView(
                            question: faq.question,
                            answer: faq.answer,
                            isExpanded: expandedIndex == index,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    expandedIndex = expandedIndex == index ? nil : index
                                }
                            }
                        )
                    }
                }
                .padding(16)
            }

            Spacer()

            // Contact us section
            VStack(spacing: 10) {
                Text("More questions?")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)

                Button {
                    openMail()
                } label: {
                    Text("Contact us")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                        .cornerRadius(16)
                }
            }
            .padding(16)
        }
        .background(AppColors.surface)
    }

    private func openMail() {
        guard let url = URL(string: "mailto:support@viralapps.studio") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - FAQ Item

private struct FAQItemView: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }) {
                HStack(spacing: 8) {
                    Text(question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(14 * 0.4)

                    Spacer()

                    Image(systemName: isExpanded ? "minus" : "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 24, height: 24)
                }
                .padding(.bottom, isExpanded ? 12 : 0)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .background(AppColors.surfaceSecondary)
                    .padding(.bottom, 8)

                Text(answer)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(12 * 0.4)
            }
        }
        .padding(16)
        .background(AppColors.textSecondary.opacity(0.08))
        .cornerRadius(20)
    }
}
