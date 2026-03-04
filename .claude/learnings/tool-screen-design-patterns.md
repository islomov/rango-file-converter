# Tool Screen Design Patterns

Applies to ALL tool screens across Image, Video, and Audio categories (not Document).

## Floating Tab Bar Hiding
- Use the `PreferenceKey` approach — child views add `.hidesFloatingTabBar()` modifier
- Defined in `Shared/TabBarVisibility.swift`
- `ContentView` reads via `.onPreferenceChange()` and animates in/out
- Do NOT pass `@Binding var hideTabBar` — use the preference key instead
- Any view pushed via `navigationDestination` just adds `.hidesFloatingTabBar()`

## Post-Action Navigation
- After applying ANY tool action, navigate the user to the **History tab**
- Each category converter view exposes `onNavigateToHistory: (() -> Void)?`
- `ContentView` wires it: `selectedCategory = nil; selectedTab = .history`
- Call `onNavigateToHistory?()` after processing and dismissing views

## Screen Layout (Top → Bottom)
1. **Header**: custom nav bar, hide default with `.navigationBarHidden(true)`
2. **Preview**: media preview with fixed padding (no expanding Spacers)
3. **File size info**: original → estimated size
4. **Controls**: tool-specific options
5. **Bottom buttons**: pinned at bottom

## Header
- Title: system semibold 20px, centered, `#1D1D1D`, -0.408 tracking
- Height: 56px, horizontal padding: 8px
- Close button (top-right): SF Symbol `xmark`, size 14 semibold, 40x40 frame
  - Circular background: `#888888` at 8% opacity

## Media Preview
- Max height: **260px**
- Do NOT use expanding `Spacer` — it pushes controls to the bottom of the screen
- Use fixed padding: `.padding(.vertical, 24)` on media, `.padding(.bottom, 12)` on file size
- Clip with `RoundedRectangle(cornerRadius: 16)`
- White background with bottom border: `#565656` at 8% opacity, 1px

## File Size Info
- Original size (dark `#1D1D1D`) → arrow → estimated size (orange `#F4800D`) → percentage (gray `#888888`)
- Font: system semibold 12px, -0.408 tracking

## Bottom Action Buttons
- Two buttons side by side: **Reset (30%)** and **Main Action (70%)**
- 16px horizontal padding, 8px spacing between buttons
- Height: 60px, corner radius: 16px, 24px vertical padding
- Reset: `#888888` at 12% opacity background, `#1D1D1D` text, 50% opacity when disabled
- Main action: orange gradient, white text
  - **Enabled**: `#FFA05C` → `#EF731A` (leading → trailing)
  - **Disabled**: `#FFD9B8` → `#F8C192` → `#FFD9B8`

## Controls Section
- Section labels: system semibold 14px, `#888888`, -0.408 tracking
- Action icon buttons: 72x72px, 16px corner radius, `#888888` at 12% opacity background
- Slider tint: `#F4800D`
- 16px padding around controls section

## General
- Montserrat in Figma → use `.system` font with matching size/weight (not bundled in app)
- `Color(hex:)` extension available project-wide from `HomeView.swift`
