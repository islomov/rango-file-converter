//
//  ForceUpdateView.swift
//  RangoFileConverter
//
//  Created by Sardor Islomov on 08/03/26.
//

import SwiftUI

struct ForceUpdateView: View {
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id6759793517")!

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 12) {
                    Text("Update Required")
                        .font(.custom("Montserrat-Bold", size: 24))
                        .foregroundColor(AppColors.textPrimary)

                    Text("A new version of Rango is available. Please update to continue using the app.")
                        .font(.custom("Sora-Regular", size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button {
                    UIApplication.shared.open(appStoreURL)
                } label: {
                    Text("Update Now")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .interactiveDismissDisabled()
    }
}
