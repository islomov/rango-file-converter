import SwiftUI

struct VideoDownloaderView: View {
    var onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            Text("Video Downloader")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .background(AppColors.background)
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
