import SwiftUI
import UIKit

struct VideoDownloaderView: View {
    var onBack: (() -> Void)?

    @State private var urlText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 16) {
                // URL input row
                HStack(spacing: 12) {
                    TextField("Paste video URL here", text: $urlText)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textPrimary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppColors.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.border, lineWidth: 1)
                        )

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if let clipboardString = UIPasteboard.general.string {
                            urlText = clipboardString
                        }
                    } label: {
                        Text("Paste")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 24)

            Spacer()

            // Download button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Text("Download for convert")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(AppColors.background)
        .hidesFloatingTabBar()
    }

    private var header: some View {
        ZStack {
            Text("Video Downloader")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            HStack {
                Button {
                    onBack?()
                } label: {
                    Image("icon_arrow_left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .flipsForRightToLeftLayoutDirection(true)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }
}
