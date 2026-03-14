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

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    generalSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.05), value: sectionsAppeared)

                    themeSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.12), value: sectionsAppeared)

                    storageSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.19), value: sectionsAppeared)

                    linksSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.26), value: sectionsAppeared)
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
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(AppColors.background)
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

                        Image(systemName: "chevron.right")
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

                Text(theme.rawValue)
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

                Image(systemName: "chevron.right")
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

    // MARK: - Links Section

    private var linksSection: some View {
        VStack(spacing: 0) {
            linkRow(title: "Rate app", isFirst: true, isLast: false) {
                rateAppPrompt = .random()
                showRateAppAlert = true
            }

            linkRow(title: "Privacy policy", isFirst: false, isLast: false) {
                showPrivacyPolicy = true
            }

            linkRow(title: "Terms of use", isFirst: false, isLast: false) {
                showTermsOfUse = true
            }

            versionRow
        }
        .background(AppColors.surface)
        .cornerRadius(16)
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

                Image(systemName: "chevron.right")
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
