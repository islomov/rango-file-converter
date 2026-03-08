import SwiftUI

// MARK: - PreferenceKey

/// A PreferenceKey that propagates tab bar visibility from child views to the root.
/// Any child view can attach `.hidesFloatingTabBar()` to request the tab bar be hidden.
struct TabBarVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        // If any child wants to hide, hide
        value = value || nextValue()
    }
}

// MARK: - View Modifier

extension View {
    /// Hides the floating tab bar when this view is visible.
    func hidesFloatingTabBar() -> some View {
        preference(key: TabBarVisibilityPreferenceKey.self, value: true)
    }
}
