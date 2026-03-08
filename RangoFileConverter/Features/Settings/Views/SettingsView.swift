import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var dailyReminders = true
    @State private var showClearHistoryAlert = false
    @State private var showLanguagePicker = false

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    generalSection
                    themeSection
                    clearHistoryButton
                    linksSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .top) {
            headerView
        }
        .navigationBarHidden(true)
        .alert("Clear History", isPresented: $showClearHistoryAlert) {
            Button("Clear", role: .destructive) {
                historyStore.removeAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all converted files and history. This action cannot be undone.")
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
                Toggle("", isOn: $dailyReminders)
                    .labelsHidden()
                    .tint(AppColors.accent)
            }

            // App language
            settingsRow(
                icon: "globe",
                title: "App language",
                showDivider: true
            ) {
                HStack(spacing: 0) {
                    Text("English")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 24, height: 24)
                }
            }

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

    // MARK: - Clear History

    private var clearHistoryButton: some View {
        Button {
            showClearHistoryAlert = true
        } label: {
            HStack {
                Text("Clear history")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.destructive)
                Spacer()
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Links Section

    private var linksSection: some View {
        VStack(spacing: 0) {
            linkRow(title: "Rate app", isFirst: true, isLast: false)

            linkRow(title: "Privacy policy", isFirst: false, isLast: false)

            linkRow(title: "Terms of use", isFirst: false, isLast: false)

            versionRow
        }
        .background(AppColors.surface)
        .cornerRadius(16)
    }

    private func linkRow(title: String, isFirst: Bool, isLast: Bool) -> some View {
        Button {
            // Handle link tap
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

            HStack(spacing: 4) {
                Text(appVersion)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func settingsRow<Trailing: View>(
        icon: String,
        title: String,
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
}

#Preview {
    SettingsView()
        .environmentObject(HistoryStore.shared)
        .environmentObject(ThemeManager.shared)
}
