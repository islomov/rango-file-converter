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
    @State private var glowOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var didPurchase = false

    let source: String

    private let features: [(icon: String, title: LocalizedStringKey)] = [
        ("infinity", "Unlimited Conversions"),
        ("bolt.fill", "Priority Processing"),
        ("eye.slash.fill", "Ad-Free Experience"),
        ("star.fill", "All 74+ Formats"),
        ("slider.horizontal.3", "Custom Compression"),
        ("square.and.arrow.up", "Share & Export Files"),
        ("doc.viewfinder", "Built-in File Viewer"),
        ("rectangle.stack.badge.plus", "Merge & Stitch Files"),
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
            // Phase 1: Scale up + fade in with spring
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            // Phase 2: Glow pulse
            withAnimation(.easeInOut(duration: 0.5).delay(0.4)) {
                glowOpacity = 1.0
            }
            // Analytics: paywall viewed
            if !subscriptionManager.isProUser {
                AnalyticsService.log(AnalyticsService.Event.paywallViewed, parameters: [
                    AnalyticsService.Param.source: source
                ])
                FacebookEventService.logAddToCart()
            }
        }
        .onDisappear {
            if !subscriptionManager.isProUser && !didPurchase {
                AnalyticsService.log(AnalyticsService.Event.paywallDismissed, parameters: [
                    AnalyticsService.Param.source: source
                ])
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
        VStack(spacing: 8) {
            ZStack {
                // Radial orange glow behind icon
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.3),
                                Color.orange.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .opacity(glowOpacity)

                // App icon
                Image("app_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: .orange.opacity(0.25), radius: 12, y: 4)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)

            HStack(spacing: 5) {
                Text("Media Converter")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text("Pro")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .padding(.top, -8)
        .padding(.bottom, 20)
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

            // Secured by App Store badge
            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
                Text("Secured by App Store")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AppColors.textSecondary)
            }
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
            .padding(.bottom, 6)

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

    /// Short currency symbol lookup — maps currency codes to their native short symbols.
    private static let shortSymbols: [String: String] = {
        var map: [String: String] = [:]
        for id in Locale.availableIdentifiers {
            let locale = Locale(identifier: id)
            if let code = locale.currencyCode, map[code] == nil,
               let symbol = locale.currencySymbol {
                map[code] = symbol
            }
        }
        return map
    }()

    /// Create a currency formatter that uses the short symbol (e.g. "$" not "US$").
    private func currencyFormatter(for product: RevenueCat.StoreProduct) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = product.currencyCode
        formatter.locale = product.priceFormatter?.locale ?? .current
        if let code = product.currencyCode,
           let short = Self.shortSymbols[code] {
            formatter.currencySymbol = short
        }
        return formatter
    }

    /// Format price using the short currency symbol (e.g. "$49.99" not "US$49.99").
    private func formattedPrice(for product: RevenueCat.StoreProduct) -> String {
        currencyFormatter(for: product).string(from: product.price as NSDecimalNumber)
            ?? product.localizedPriceString
    }

    /// Calculate per-day price for yearly plan
    private func perDayPrice(for package: Package) -> String? {
        guard package.packageType == .annual else { return nil }

        let yearlyPrice = (package.storeProduct.price as NSDecimalNumber).doubleValue
        let perDay = yearlyPrice / 365.0

        let formatter = currencyFormatter(for: package.storeProduct)
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: NSNumber(value: perDay))
    }

    // MARK: - Yearly Package Section (banner + card)

    private func yearlyPackageSection(_ package: Package, allPackages: [Package]) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let savings = savingsPercentage(for: package, allPackages: allPackages)

        return VStack(spacing: 10) {
            // "Cancel Anytime" label above yearly card
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Text("Cancel Anytime")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedPackage = package
                }
                logPlanSelected(package)
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
                            Text("then \(formattedPrice(for: package.storeProduct)) per \(package.storeProduct.subscriptionPeriod?.periodLabel ?? "")")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            Text("Only \(formattedPrice(for: package.storeProduct)) per year")
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
    }

    // MARK: - Package Row (non-yearly)

    /// Format price text as "X.XX per period"
    private func priceText(for package: Package) -> String {
        let price = formattedPrice(for: package.storeProduct)
        let period = package.storeProduct.subscriptionPeriod?.periodLabel ?? ""
        return String(localized: "\(price) per \(period)")
    }

    private func packageRow(_ package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPackage = package
            }
            logPlanSelected(package)
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
                    Text(formattedPrice(for: package.storeProduct))
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

    private func logPlanSelected(_ package: Package) {
        let price = (package.storeProduct.price as NSDecimalNumber).doubleValue
        let currency = package.storeProduct.currencyCode ?? "USD"
        AnalyticsService.log(AnalyticsService.Event.paywallPlanSelected, parameters: [
            AnalyticsService.Param.planID: package.storeProduct.productIdentifier,
            AnalyticsService.Param.price: price,
            AnalyticsService.Param.currency: currency
        ])
    }

    private func purchasePackage(_ package: Package) {
        let price = (package.storeProduct.price as NSDecimalNumber).doubleValue
        let currency = package.storeProduct.currencyCode ?? "USD"
        let productID = package.storeProduct.productIdentifier

        // Facebook: initiated checkout
        FacebookEventService.logInitiatedCheckout(planID: productID, price: price, currency: currency)

        isPurchasing = true
        Task {
            do {
                let completed = try await subscriptionManager.purchase(package)
                isPurchasing = false
                if completed {
                    didPurchase = true

                    // Firebase: subscription purchased
                    AnalyticsService.log(AnalyticsService.Event.subscriptionPurchased, parameters: [
                        AnalyticsService.Param.productID: productID,
                        AnalyticsService.Param.price: price,
                        AnalyticsService.Param.currency: currency
                    ])

                    // Facebook: purchase with revenue for ROAS
                    FacebookEventService.logPurchase(amount: price, currency: currency, productID: productID)

                    dismiss()
                }
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
                showError = true

                // Firebase: subscription failed
                AnalyticsService.log(AnalyticsService.Event.subscriptionFailed, parameters: [
                    AnalyticsService.Param.errorMessage: error.localizedDescription
                ])
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

                // Firebase: subscription restored
                AnalyticsService.log(AnalyticsService.Event.subscriptionRestored, parameters: [
                    AnalyticsService.Param.isPro: subscriptionManager.isProUser
                ])
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
