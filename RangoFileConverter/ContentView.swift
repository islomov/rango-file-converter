import SwiftUI

enum AppTab: Int, CaseIterable {
    case home
    case history
    case settings

    /// Outline icon for unselected state (template-rendered, tinted gray)
    var unselectedIconName: String {
        switch self {
        case .home: return "icon_home_linear"
        case .history: return "icon_task_square"
        case .settings: return "icon_setting"
        }
    }

    /// Bold/filled icon for selected state (original rendering with built-in gradient)
    var selectedIconName: String {
        switch self {
        case .home: return "icon_home_bold"
        case .history: return "icon_task_square_bold"
        case .settings: return "icon_setting_bold"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var selectedCategory: MediaCategory?
    @State private var hideTabBar: Bool = false

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                if let category = selectedCategory {
                    categoryView(for: category)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    HomeView { category in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            selectedCategory = category
                        }
                    }
                    .transition(.opacity)
                }
            case .history:
                HistoryView()
                    .transition(.opacity)
            case .settings:
                SettingsView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !hideTabBar {
                FloatingTabBar(selectedTab: $selectedTab) {
                    // Reset category when tapping home
                    if selectedTab == .home {
                        selectedCategory = nil
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onPreferenceChange(TabBarVisibilityPreferenceKey.self) { shouldHide in
            withAnimation(.easeInOut(duration: 0.25)) {
                hideTabBar = shouldHide
            }
        }
        .onChange(of: selectedTab) { _ in
            // When switching to History or Settings, always show the tab bar.
            // Fixes stale preference when leaving a converter sub-view mid-conversion.
            if selectedTab != .home || selectedCategory == nil {
                withAnimation(.easeInOut(duration: 0.25)) {
                    hideTabBar = false
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: .didTapDailyReminder)) { _ in
            selectedTab = .home
            selectedCategory = nil
        }
    }

    @ViewBuilder
    private func categoryView(for category: MediaCategory) -> some View {
        switch category {
        case .image:
            ImageConverterView(
                onBack: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        selectedCategory = nil
                    }
                },
                onNavigateToHistory: {
                    selectedCategory = nil
                    selectedTab = .history
                }
            )
        case .video:
            VideoConverterView(
                onBack: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        selectedCategory = nil
                    }
                },
                onNavigateToHistory: {
                    selectedCategory = nil
                    selectedTab = .history
                }
            )
        case .audio:
            AudioConverterView(
                onBack: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        selectedCategory = nil
                    }
                },
                onNavigateToHistory: {
                    selectedCategory = nil
                    selectedTab = .history
                }
            )
        case .document:
            DocumentConverterView(
                onBack: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        selectedCategory = nil
                    }
                },
                onNavigateToHistory: {
                    selectedCategory = nil
                    selectedTab = .history
                }
            )
        }
    }
}

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab
    var onHomeTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ForEach(AppTab.allCases, id: \.rawValue) { tab in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if tab == .home && selectedTab == .home {
                            onHomeTap()
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTab = tab
                        }
                    } label: {
                        tabIcon(for: tab)
                            .frame(width: 52, height: 52)
                            .background(
                                selectedTab == tab
                                ? AppColors.accent.opacity(0.08)
                                : Color.clear
                            )
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppColors.tabBarBackground)
                    .overlay(
                        Capsule()
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .shadow(color: AppColors.shadow.opacity(0.2), radius: 10, y: 0)
            )
        }
        .padding(.bottom, 44)
    }

    @ViewBuilder
    private func tabIcon(for tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        if isSelected {
            // Selected: bold/filled icon with built-in gradient (original rendering)
            Image(tab.selectedIconName)
                .resizable()
                .frame(width: 28, height: 28)
        } else {
            // Unselected: outline icon tinted dark gray (template rendering)
            Image(tab.unselectedIconName)
                .resizable()
                .renderingMode(.template)
                .frame(width: 28, height: 28)
                .foregroundColor(AppColors.tabIconDefault)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HistoryStore.shared)
        .environmentObject(ThemeManager.shared)
}
