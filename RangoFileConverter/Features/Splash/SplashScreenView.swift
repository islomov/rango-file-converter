//
//  SplashScreenView.swift
//  RangoFileConverter
//
//  Created by Sardor Islomov on 08/03/26.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var finished = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ZStack {
                // Glow behind icon
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.3),
                                Color.orange.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 10,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .opacity(glowOpacity)

                // App icon
                Image("app_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .orange.opacity(0.25), radius: 20, y: 8)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
        }
        .onAppear {
            // Phase 1: Scale up + fade in with spring
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }

            // Phase 2: Glow pulse
            withAnimation(.easeInOut(duration: 0.5).delay(0.4)) {
                glowOpacity = 1.0
            }

            // Phase 3: Dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeIn(duration: 0.25)) {
                    finished = true
                }
            }
        }
        .opacity(finished ? 0 : 1)
        .scaleEffect(finished ? 1.1 : 1.0)
    }
}
