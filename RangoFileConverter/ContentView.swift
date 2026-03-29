import SwiftUI
import StoreKit

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
    @State private var showWelcome: Bool = false

    private static let hasSeenWelcomeKey = "hasSeenWelcomeSheet"

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
                        AnalyticsService.log(AnalyticsService.Event.categorySelected, parameters: [
                            AnalyticsService.Param.category: "\(category)"
                        ])
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
            if !hideTabBar || selectedTab != .home {
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
            // Only respect the hide preference on the Home tab.
            // Prevents stale preferences from converter sub-views (which use
            // .hidesFloatingTabBar()) from keeping the tab bar hidden after
            // navigating to History/Settings during a transition animation.
            let effective = shouldHide && selectedTab == .home
            withAnimation(.easeInOut(duration: 0.25)) {
                hideTabBar = effective
            }
        }
        .onChange(of: selectedTab) { _ in
            AnalyticsService.log(AnalyticsService.Event.tabSelected, parameters: [
                AnalyticsService.Param.tabName: "\(selectedTab)"
            ])
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
        .onAppear {
            if !UserDefaults.standard.bool(forKey: Self.hasSeenWelcomeKey) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    showWelcome = true
                    UserDefaults.standard.set(true, forKey: Self.hasSeenWelcomeKey)
                }
            }
        }
        .sheet(isPresented: $showWelcome, onDismiss: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
                SKStoreReviewController.requestReview(in: scene)
            }
        }) {
            WelcomeBottomSheetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(AppColors.surface)
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
        case .download:
            VideoDownloaderView(
                onBack: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        selectedCategory = nil
                    }
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
