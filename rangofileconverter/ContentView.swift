import SwiftUI

enum AppTab: Int, CaseIterable {
    case home
    case history
    case settings

    var iconName: String {
        switch self {
        case .home: return "icon_home_bold"
        case .history: return "icon_task_square"
        case .settings: return "icon_setting"
        }
    }

    /// Whether this tab's icon uses original rendering (e.g. gradient) vs template tinting
    var usesOriginalRendering: Bool {
        switch self {
        case .home: return true
        case .history, .settings: return false
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var selectedCategory: MediaCategory?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .home:
                    if let category = selectedCategory {
                        categoryView(for: category)
                    } else {
                        HomeView { category in
                            selectedCategory = category
                        }
                    }
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating tab bar
            FloatingTabBar(selectedTab: $selectedTab) {
                // Reset category when tapping home
                if selectedTab == .home {
                    selectedCategory = nil
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private func categoryView(for category: MediaCategory) -> some View {
        switch category {
        case .image:
            ImageConverterView(onBack: { selectedCategory = nil })
        case .video:
            VideoConverterView()
        case .audio:
            AudioConverterView()
        case .document:
            DocumentConverterView()
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
                        if tab == .home && selectedTab == .home {
                            onHomeTap()
                        }
                        selectedTab = tab
                    } label: {
                        tabIcon(for: tab)
                            .frame(width: 52, height: 52)
                            .background(
                                selectedTab == tab
                                ? Color(hex: "F4800D").opacity(0.08)
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
                    .fill(Color.white.opacity(0.88))
                    .shadow(color: Color(hex: "505050").opacity(0.2), radius: 10, y: 0)
            )
        }
        .padding(.bottom, 44)
    }

    @ViewBuilder
    private func tabIcon(for tab: AppTab) -> some View {
        if tab.usesOriginalRendering {
            // Home icon has a built-in gradient — use original rendering
            Image(tab.iconName)
                .resizable()
                .frame(width: 28, height: 28)
        } else {
            // History & Settings icons — tint based on selection
            Image(tab.iconName)
                .resizable()
                .renderingMode(.template)
                .frame(width: 28, height: 28)
                .foregroundColor(
                    selectedTab == tab
                    ? Color(hex: "F4800D")
                    : Color(hex: "888888")
                )
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HistoryStore.shared)
}
