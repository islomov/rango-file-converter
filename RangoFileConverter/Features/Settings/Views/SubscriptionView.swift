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
    @State private var glowRotation: Double = 0
    @State private var glowScale: CGFloat = 1.0

    private let features: [(icon: String, title: LocalizedStringKey)] = [
        ("infinity", "Unlimited Conversions"),
        ("bolt.fill", "Priority Processing"),
        ("eye.slash.fill", "Ad-Free Experience"),
        ("star.fill", "All 74+ Formats"),
        ("clock.arrow.circlepath", "Conversion History"),
        ("person.crop.circle.badge.checkmark", "Premium Support")
    ]

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

                headerSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        featureList

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
            selectYearlyIfNeeded()
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                glowRotation = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowScale = 1.15
            }
        }
        .onChange(of: subscriptionManager.currentOffering?.identifier) { _ in
            selectYearlyIfNeeded()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? String(localized: "Something went wrong. Please try again."))
        }
        .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(subscriptionManager.isProUser
                 ? LocalizedStringKey("Your Pro subscription has been restored!")
                 : LocalizedStringKey("No active subscriptions found."))
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
                // Soft ambient glow behind icon
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .scaleEffect(glowScale)

                // Subtle rotating border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                AppColors.buttonGradientStart.opacity(0.6),
                                AppColors.buttonGradientEnd.opacity(0.2),
                                AppColors.accentLight.opacity(0.6),
                                AppColors.buttonGradientStart.opacity(0.2),
                                AppColors.buttonGradientStart.opacity(0.6)
                            ]),
                            center: .center,
                            angle: .degrees(glowRotation)
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 90, height: 90)

                // App icon
                Image("app_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
            }

            HStack(spacing: 6) {
                Text("Media Converter")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text("Pro")
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
        .padding(.bottom, 27)
    }

    // MARK: - Feature List (icons, no cards)

    private var featureList: some View {
        VStack(spacing: 14) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28)

                    Text(feature.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.success)
                }
            }
        }
        .padding(.horizontal, 4)
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
            // Package selection — yearly first
            if let offering = subscriptionManager.currentOffering {
                let sorted = sortedPackages(offering.availablePackages)
                VStack(spacing: 8) {
                    ForEach(Array(sorted.enumerated()), id: \.element.identifier) { index, package in
                        if package.packageType == .annual {
                            yearlyPackageSection(package, allPackages: offering.availablePackages)
                                .onAppear {
                                    if selectedPackage == nil {
                                        selectedPackage = package
                                    }
                                }
                        } else {
                            packageRow(package)
                                .onAppear {
                                    if selectedPackage == nil {
                                        selectedPackage = package
                                    }
                                }
                        }
                    }
                }
            }

            // Auto-renewal disclosure
            Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage in Settings > Apple ID > Subscriptions.")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.top, 7)

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

    // MARK: - Package sorting (yearly first)

    private func sortedPackages(_ packages: [Package]) -> [Package] {
        packages.sorted { a, b in
            packageSortOrder(a.packageType) < packageSortOrder(b.packageType)
        }
    }

    private func packageSortOrder(_ type: PackageType) -> Int {
        switch type {
        case .annual: return 0
        case .monthly: return 1
        case .weekly: return 2
        default: return 3
        }
    }

    // MARK: - Price formatting

    /// Format a price amount using the product's currency with a clean symbol (e.g. "$" not "US$", "£" not "UK£").
    /// Uses the user's locale for number formatting but strips country-prefixed currency symbols.
    private func formatPrice(_ amount: Decimal, for product: StoreProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.currencyCode = product.currencyCode

        // Look up the clean currency symbol (e.g. "$" for USD, "£" for GBP)
        // by using the "en" locale which doesn't add country prefixes
        let symbolLookup = NumberFormatter()
        symbolLookup.numberStyle = .currency
        symbolLookup.currencyCode = product.currencyCode
        symbolLookup.locale = Locale(identifier: "en")
        formatter.currencySymbol = symbolLookup.currencySymbol

        return formatter.string(from: amount as NSDecimalNumber) ?? product.localizedPriceString
    }

    /// The product's formatted price string using clean currency symbols
    private func cleanPrice(for package: Package) -> String {
        formatPrice(package.storeProduct.price, for: package.storeProduct)
    }

    // MARK: - Savings calculation

    /// Calculate savings % of a package compared to the weekly plan
    private func savingsPercentage(for package: Package, allPackages: [Package]) -> Int? {
        guard package.packageType == .annual else { return nil }

        // Find the weekly package to calculate savings against
        guard let weeklyPackage = allPackages.first(where: { $0.packageType == .weekly }) else {
            return nil
        }

        let weeklyPricePerYear = weeklyPackage.storeProduct.price as Decimal * 52
        let yearlyPrice = package.storeProduct.price as Decimal
        guard weeklyPricePerYear > 0 else { return nil }

        let savings = ((weeklyPricePerYear - yearlyPrice) / weeklyPricePerYear) * 100
        return Int(NSDecimalNumber(decimal: savings).doubleValue.rounded())
    }

    /// Calculate per-day price for yearly plan
    private func perDayPrice(for package: Package) -> String? {
        guard package.packageType == .annual else { return nil }

        let yearlyPrice = (package.storeProduct.price as NSDecimalNumber).doubleValue
        let perDay = yearlyPrice / 365.0

        return formatPrice(Decimal(perDay), for: package.storeProduct)
    }

    // MARK: - Yearly Package Section (banner + card)

    private func yearlyPackageSection(_ package: Package, allPackages: [Package]) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let savings = savingsPercentage(for: package, allPackages: allPackages)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPackage = package
            }
        } label: {
            VStack(spacing: 0) {
                // Full-width "SAVE XX%" banner on top
                if let savings = savings {
                    Text("SAVE \(savings)%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                // Card content
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(package.storeProduct.localizedTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)

                        if let intro = package.storeProduct.introductoryDiscount,
                           intro.paymentMode == .freeTrial {
                            Text("then \(cleanPrice(for: package)) per \(package.storeProduct.subscriptionPeriod?.periodLabel ?? "")")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            Text("Only \(cleanPrice(for: package)) per year")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    if let intro = package.storeProduct.introductoryDiscount,
                       intro.paymentMode == .freeTrial {
                        Text("FREE")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(isSelected ? AppColors.accent : AppColors.textPrimary)
                    } else if let dayPrice = perDayPrice(for: package) {
                        VStack(spacing: 1) {
                            Text(dayPrice)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(isSelected ? AppColors.accent : AppColors.textPrimary)
                            Text("per day")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppColors.surface)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Package Row (non-yearly)

    /// Format price text as "X.XX per period"
    private func priceText(for package: Package) -> String {
        let price = cleanPrice(for: package)
        let period = package.storeProduct.subscriptionPeriod?.periodLabel ?? ""
        return String(localized: "\(price) per \(period)")
    }

    private func packageRow(_ package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPackage = package
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    if let intro = package.storeProduct.introductoryDiscount,
                       intro.paymentMode == .freeTrial {
                        Text("then \(priceText(for: package))")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text(priceText(for: package))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                if let intro = package.storeProduct.introductoryDiscount,
                   intro.paymentMode == .freeTrial {
                    Text("FREE")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.textPrimary)
                } else {
                    Text(cleanPrice(for: package))
                        .font(.system(size: 18, weight: .bold))
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
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func selectYearlyIfNeeded() {
        guard selectedPackage == nil,
              let offering = subscriptionManager.currentOffering else { return }
        selectedPackage = offering.availablePackages.first(where: { $0.packageType == .annual })
            ?? offering.availablePackages.first
    }

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
                    dismiss()
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
            return value == 7 ? String(localized: "1 week") : "\(value) " + String(localized: value == 1 ? "day" : "days")
        case .week:
            return "\(value) " + String(localized: value == 1 ? "week" : "weeks")
        case .month:
            return "\(value) " + String(localized: value == 1 ? "month" : "months")
        case .year:
            return "\(value) " + String(localized: value == 1 ? "year" : "years")
        @unknown default:
            return ""
        }
    }

    var periodLabel: String {
        switch unit {
        case .day:
            return value == 7 ? String(localized: "week") : String(localized: "day")
        case .week:
            return String(localized: "week")
        case .month:
            return String(localized: "month")
        case .year:
            return String(localized: "year")
        @unknown default:
            return ""
        }
    }
}
