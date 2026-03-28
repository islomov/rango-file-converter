import SwiftUI

struct WelcomeBottomSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Grab handle
            Capsule()
                .fill(Color(.quaternaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Spacer()

            // Content
            VStack(spacing: 24) {
                // App icon
                Image("app_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 16, y: 8)

                // Title & description
                VStack(spacing: 16) {
                    Text("Welcome to Media Converter!")
                        .font(.custom("Montserrat-Bold", size: 28))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 8) {
                        Text("Convert any file format — images, videos, audio & documents.")
                            .font(.system(size: 17))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(17 * 0.4)

                        Text("100% Free. No Ads. No Paywall. Ever.")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.accentLight, AppColors.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 16)
                }
            }

            Spacer()

            // Action button
            Button {
                dismiss()
            } label: {
                Text("You're awesome, thank you! 🎉")
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
                    .shadow(color: .orange.opacity(0.25), radius: 20, y: 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(AppColors.surface)
    }
}

