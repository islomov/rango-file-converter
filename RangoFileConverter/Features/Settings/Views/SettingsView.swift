import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var reminderManager = DailyReminderManager.shared
    @State private var showClearStorageAlert = false
    @State private var clearStorageCategory: String?
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var showLanguagePicker = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false
    @State private var showRateAppAlert = false
    @State private var rateAppPrompt: RateAppPrompt = .random()
    @State private var sectionsAppeared = false
    @State private var showFAQ = false
    @State private var showSubscription = false
    @State private var isRestoringPurchases = false
    @State private var showRestoreAlert = false
    @State private var restoreAlertTitle = ""
    @State private var restoreAlertMessage = ""

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    proSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.02), value: sectionsAppeared)

                    generalSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.08), value: sectionsAppeared)

                    themeSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.15), value: sectionsAppeared)

                    storageSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.22), value: sectionsAppeared)

                    supportSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.29), value: sectionsAppeared)

                    linksSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.36), value: sectionsAppeared)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
        }
        .safeAreaInset(edge: .top) {
            headerView
        }
        .navigationBarHidden(true)
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
        .sheet(isPresented: $showFAQ) {
            FAQBottomSheetView()
                .presentationDetents([.large])
                .preferredColorScheme(themeManager.colorScheme)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView(source: "settings")
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .preferredColorScheme(themeManager.colorScheme)
        }
        .onAppear {
            if !sectionsAppeared {
                sectionsAppeared = true
            }
            historyStore.refreshStorageSizes()
        }
        .alert("Clear \(clearStorageCategory?.capitalized ?? "") Storage", isPresented: $showClearStorageAlert) {
            Button("Delete", role: .destructive) {
                historyStore.removeAll(for: clearStorageCategory)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all converted \(clearStorageCategory ?? "") files. This action cannot be undone.")
        }
        .alert(restoreAlertTitle, isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(restoreAlertMessage)
        }
        .alert(rateAppPrompt.title, isPresented: $showRateAppAlert) {
            Button("Rate Now") {
                if let url = URL(string: "https://apps.apple.com/app/id6759793517?action=write-review") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Maybe Later", role: .cancel) { }
        } message: {
            Text(rateAppPrompt.message)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            Text("Settings")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(AppColors.background)
    }

    // MARK: - Pro Section

    private var proSection: some View {
        Button {
            showSubscription = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Media Converter Pro")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(SubscriptionManager.shared.isProUser ? "Active" : "Unlock all features")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface)
            .cornerRadius(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(spacing: 0) {
            // Daily reminders
            settingsRow(
                icon: "bell.fill",
                title: "Daily reminders",
                showDivider: true
            ) {
                Toggle("", isOn: $reminderManager.isEnabled)
                    .labelsHidden()
                    .tint(AppColors.accent)
            }

            // App language
            Button {
                showLanguagePicker = true
            } label: {
                settingsRow(
                    icon: "globe",
                    title: "App language",
                    showDivider: true
                ) {
                    HStack(spacing: 0) {
                        Text(languageManager.currentLanguage.nativeName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)

                        Image(systemName: "chevron.forward")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .buttonStyle(.plain)

            // Default save location
            settingsRow(
                icon: "mappin.and.ellipse",
                title: "Default save location",
                showDivider: false
            ) {
                Text("Photos")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .background(AppColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(AppTheme.allCases.enumerated()), id: \.element.rawValue) { index, theme in
                themeRow(theme: theme, isLast: index == AppTheme.allCases.count - 1)
            }
        }
        .background(AppColors.surface)
        .cornerRadius(16)
    }

    private func themeRow(theme: AppTheme, isLast: Bool) -> some View {
        Button {
            themeManager.selectedTheme = theme
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.clear)
                        .frame(width: 36, height: 36)

                    Image(systemName: theme.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.textPrimary)
                }

                Text(theme.localizedName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if themeManager.selectedTheme == theme {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.accent)
                } else {
                    Circle()
                        .fill(AppColors.placeholder)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.12))
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Storage Section

    private let storageCategories: [(title: LocalizedStringKey, icon: String, category: String)] = [
        ("Images", "photo.fill", "image"),
        ("Videos", "video.fill", "video"),
        ("Audio", "waveform", "audio"),
        ("Documents", "doc.fill", "document")
    ]

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Storage")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text(formattedSize(historyStore.cachedTotalStorageBytes))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(storageCategories.enumerated()), id: \.element.category) { index, item in
                    storageRow(
                        icon: item.icon,
                        title: item.title,
                        category: item.category,
                        isLast: index == storageCategories.count - 1
                    )
                }
            }
            .background(AppColors.surface)
            .cornerRadius(16)
        }
    }

    private func storageRow(icon: String, title: LocalizedStringKey, category: String, isLast: Bool) -> some View {
        Button {
            clearStorageCategory = category
            showClearStorageAlert = true
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.clear)
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.textPrimary)
                }

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(formattedSize(historyStore.cachedCategoryStorageBytes[category] ?? 0))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.12))
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024.0 * 1024.0)
        if mb < 0.1 {
            return "0 MB"
        } else if mb < 100 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        VStack(spacing: 0) {
            linkRow(icon: "questionmark.circle.fill", title: "FAQ", isFirst: true, isLast: false) {
                showFAQ = true
            }

            linkRow(icon: "envelope.fill", title: "Write to Support", isFirst: false, isLast: true) {
                if let url = URL(string: "mailto:support@viralapps.studio?subject=Support%20Request") {
                    UIApplication.shared.open(url)
                }
            }
        }
        .background(AppColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Links Section

    private var linksSection: some View {
        VStack(spacing: 0) {
            linkRow(title: "Rate app", isFirst: true, isLast: false) {
                AnalyticsService.log(AnalyticsService.Event.rateAppTapped)
                rateAppPrompt = .random()
                showRateAppAlert = true
            }

            linkRow(title: "Privacy policy", isFirst: false, isLast: false) {
                showPrivacyPolicy = true
            }

            linkRow(title: "Terms of use", isFirst: false, isLast: false) {
                showTermsOfUse = true
            }

            linkRow(title: "Manage subscription", isFirst: false, isLast: false) {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            }

            restorePurchasesRow

            versionRow
        }
        .background(AppColors.surface)
        .cornerRadius(16)
    }

    private func linkRow(icon: String, title: LocalizedStringKey, isFirst: Bool, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(AppColors.textPrimary)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(height: 56)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.12))
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func linkRow(title: LocalizedStringKey, isFirst: Bool, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(height: 56)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.12))
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var versionRow: some View {
        HStack {
            Text("Version")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text("\(appVersion) (\(appBuildNumber))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
    }

    private var restorePurchasesRow: some View {
        Button {
            restorePurchases()
        } label: {
            HStack {
                Text("Restore purchases")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if isRestoringPurchases {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .frame(height: 56)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.textSecondary.opacity(0.12))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isRestoringPurchases)
    }

    private func restorePurchases() {
        isRestoringPurchases = true
        Task {
            do {
                try await SubscriptionManager.shared.restorePurchases()
                await MainActor.run {
                    isRestoringPurchases = false
                    if SubscriptionManager.shared.isProUser {
                        restoreAlertTitle = String(localized: "Purchases Restored")
                        restoreAlertMessage = String(localized: "Your Pro subscription has been restored successfully.")
                    } else {
                        restoreAlertTitle = String(localized: "No Purchases Found")
                        restoreAlertMessage = String(localized: "No previous purchases were found for this account.")
                    }
                    showRestoreAlert = true
                }
            } catch {
                await MainActor.run {
                    isRestoringPurchases = false
                    restoreAlertTitle = String(localized: "Restore Failed")
                    restoreAlertMessage = String(localized: "Unable to restore purchases. Please try again later.")
                    showRestoreAlert = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func settingsRow<Trailing: View>(
        icon: String,
        title: LocalizedStringKey,
        showDivider: Bool,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(AppColors.textPrimary)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            if showDivider {
                Rectangle()
                    .fill(AppColors.textSecondary.opacity(0.12))
                    .frame(height: 1)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView()
        .environmentObject(HistoryStore.shared)
        .environmentObject(ThemeManager.shared)
        .environmentObject(LanguageManager.shared)
}
