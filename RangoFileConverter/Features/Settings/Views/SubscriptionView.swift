import SwiftUI
import Combine
import RevenueCat

struct SubscriptionView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showRestoreSuccess = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false
    @State private var currentCarouselPage = 0
    @State private var glowRotation: Double = 0

    private let carouselTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    // 8 features across 2 carousel pages (2x2 grid each)
    private let allFeatures: [(icon: String, title: String)] = [
        ("infinity", "Unlimited Conversions"),
        ("bolt.fill", "Priority Processing"),
        ("eye.slash.fill", "Ad-Free Experience"),
        ("star.fill", "All 74+ Formats"),
        ("square.and.arrow.down.on.square", "Batch Processing"),
        ("wand.and.stars", "HD Quality Output"),
        ("clock.arrow.circlepath", "Conversion History"),
        ("person.crop.circle.badge.checkmark", "Premium Support")
    ]

    private var featurePages: [[(icon: String, title: String)]] {
        stride(from: 0, to: allFeatures.count, by: 4).map { start in
            Array(allFeatures[start..<min(start + 4, allFeatures.count)])
        }
    }

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.surface)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                        featureCarousel

                        if subscriptionManager.isProUser {
                            activeSubscriptionBadge
                        } else {
                            Button { dismiss() } label: {
                                Text("Continue with limited version")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                if !subscriptionManager.isProUser {
                    bottomSection
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            subscriptionManager.fetchOfferings()
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                glowRotation = 360
            }
        }
        .onReceive(carouselTimer) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                currentCarouselPage = (currentCarouselPage + 1) % featurePages.count
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Something went wrong. Please try again.")
        }
        .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(subscriptionManager.isProUser
                 ? "Your Pro subscription has been restored!"
                 : "No active subscriptions found.")
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            WebViewSheet(
                title: "Privacy policy",
                url: URL(string: "https://viralapps.studio/rangosimpleconverter/privacy-policy")!,
                colorScheme: themeManager.colorScheme
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
            .preferredColorScheme(themeManager.colorScheme)
        }
        .sheet(isPresented: $showTermsOfUse) {
            WebViewSheet(
                title: "Terms of use",
                url: URL(string: "https://viralapps.studio/rangosimpleconverter/terms-of-use")!,
                colorScheme: themeManager.colorScheme
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
            .preferredColorScheme(themeManager.colorScheme)
        }
    }

    // MARK: - Header with animated glow

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Animated gradient ring
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                AppColors.buttonGradientStart,
                                AppColors.buttonGradientEnd,
                                AppColors.accent,
                                AppColors.accentLight,
                                AppColors.buttonGradientStart
                            ]),
                            center: .center,
                            angle: .degrees(glowRotation)
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 2)

                // Outer glow
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                AppColors.buttonGradientStart.opacity(0.4),
                                AppColors.buttonGradientEnd.opacity(0.1),
                                AppColors.accentLight.opacity(0.4),
                                AppColors.buttonGradientStart.opacity(0.1),
                                AppColors.buttonGradientStart.opacity(0.4)
                            ]),
                            center: .center,
                            angle: .degrees(glowRotation)
                        ),
                        lineWidth: 6
                    )
                    .frame(width: 106, height: 106)
                    .blur(radius: 6)

                // App icon
                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            HStack(spacing: 6) {
                Text("Rango")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text("PRO")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Feature Carousel (2x2 grid pages)

    private var featureCarousel: some View {
        VStack(spacing: 12) {
            TabView(selection: $currentCarouselPage) {
                ForEach(Array(featurePages.enumerated()), id: \.offset) { pageIndex, page in
                    featureGrid(features: page)
                        .tag(pageIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)

            // Page indicators
            HStack(spacing: 6) {
                ForEach(0..<featurePages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentCarouselPage ? AppColors.accent : AppColors.placeholder)
                        .frame(width: index == currentCarouselPage ? 20 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.25), value: currentCarouselPage)
                }
            }
        }
    }

    private func featureGrid(features: [(icon: String, title: String)]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                featureGridCell(icon: feature.icon, title: feature.title)
            }
        }
        .padding(.horizontal, 4)
    }

    private func featureGridCell(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(AppColors.accent)
                .frame(height: 28)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(AppColors.surface)
        .cornerRadius(14)
    }

    // MARK: - Active Badge

    private var activeSubscriptionBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundColor(AppColors.success)

            Text("You're a Pro member!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(AppColors.surface)
        .cornerRadius(14)
    }

    // MARK: - Bottom Section (packages + button + links)

    private var bottomSection: some View {
        VStack(spacing: 10) {
            // Package selection
            if let offering = subscriptionManager.currentOffering {
                VStack(spacing: 8) {
                    ForEach(offering.availablePackages, id: \.identifier) { package in
                        packageRow(package)
                            .onAppear {
                                if selectedPackage == nil {
                                    selectedPackage = package
                                }
                            }
                    }
                }
            }

            // Secured by App Store
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
                Text("Secured by App Store")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top, 2)

            // Continue button
            Button {
                if let package = selectedPackage {
                    purchasePackage(package)
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .bold))
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
                    .cornerRadius(26)
            }
            .disabled(isPurchasing || selectedPackage == nil)
            .opacity(isPurchasing ? 0.7 : 1)

            // Footer links
            HStack(spacing: 16) {
                Button { showTermsOfUse = true } label: {
                    Text("Terms of Use")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                Button { restorePurchases() } label: {
                    Text("Restore")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                Button { showPrivacyPolicy = true } label: {
                    Text("Privacy Policy")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 10)
        .background(AppColors.background)
    }

    // MARK: - Package Row (border-only selection, no toggle)

    private func packageRow(_ package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let hasSavingsBadge = package.packageType == .annual

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPackage = package
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    if let intro = package.storeProduct.introductoryDiscount,
                       intro.paymentMode == .freeTrial {
                        Text("then \(package.storeProduct.localizedPriceString)/\(package.storeProduct.subscriptionPeriod?.periodLabel ?? "")")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text("\(package.storeProduct.localizedPriceString)/\(package.storeProduct.subscriptionPeriod?.periodLabel ?? "")")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                if let intro = package.storeProduct.introductoryDiscount,
                   intro.paymentMode == .freeTrial {
                    Text("FREE")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.textPrimary)
                } else {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.textPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColors.surface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if hasSavingsBadge {
                    Text("SAVE 90%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.accent)
                        .cornerRadius(6)
                        .offset(x: -12, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func purchasePackage(_ package: Package) {
        isPurchasing = true
        Task {
            do {
                let completed = try await subscriptionManager.purchase(package)
                isPurchasing = false
                if completed {
                    AnalyticsService.log("subscription_purchased", parameters: [
                        "product_id": package.storeProduct.productIdentifier
                    ])
                }
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func restorePurchases() {
        isPurchasing = true
        Task {
            do {
                try await subscriptionManager.restorePurchases()
                isPurchasing = false
                showRestoreSuccess = true
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Helpers

private extension SubscriptionPeriod {
    var periodDescription: String {
        switch unit {
        case .day:
            return value == 7 ? "1 week" : "\(value) day\(value == 1 ? "" : "s")"
        case .week:
            return "\(value) week\(value == 1 ? "" : "s")"
        case .month:
            return "\(value) month\(value == 1 ? "" : "s")"
        case .year:
            return "\(value) year\(value == 1 ? "" : "s")"
        @unknown default:
            return ""
        }
    }

    var periodLabel: String {
        switch unit {
        case .day:
            return value == 7 ? "week" : "day"
        case .week:
            return "week"
        case .month:
            return "month"
        case .year:
            return "year"
        @unknown default:
            return ""
        }
    }
}
