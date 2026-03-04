# UI Design Patterns

## Figma SVG Gotcha
- Figma exports SVGs with CSS variables (`var(--stroke-0, #1D1D1D)`) — Xcode does NOT support these
- Replace with raw hex values before adding to asset catalog
- Also strip `preserveAspectRatio="none"`, `width="100%"`, `height="100%"`, inline `style` attributes
- Montserrat font in Figma is NOT bundled — use `.system` font with matching size/weight

## Floating Tab Bar
- Custom pill-shaped bar with `.ultraThinMaterial`, not native `TabView`
- 3 tabs: Home, History, Settings
- Hide via `PreferenceKey` approach (`Shared/TabBarVisibility.swift`) — do NOT pass `@Binding var hideTabBar`
- Tapping Home tab when on Home resets `selectedCategory` to nil

## Tool Screen Layout (Image/Video/Audio)
- Hide default nav bar: `.navigationBarHidden(true)`
- Do NOT use expanding `Spacer` — it pushes controls to bottom
- After any tool action: navigate to History tab via `onNavigateToHistory` closure
- Bottom buttons: Reset (30%) + Main Action (70%) side by side, 60px height, 16px corner radius
- Main action enabled gradient: `#FFA05C` → `#EF731A`; disabled: `#FFD9B8` → `#F8C192` → `#FFD9B8`

## Key Colors
- Background: `#F2F2F6`
- Text: `#1D1D1D`
- Gray: `#888888`
- Orange accent: `#F4800D`
- Cards: Black `#1D1D1D`, Green `#A3E96C`, Purple `#BDA9F1`

## Utilities
- `Color(hex:)` extension in `HomeView.swift`, accessible project-wide
- No separate RangoDesign module — design tokens are inline
- `gridCellColumns(2)` works on iOS 16+ for spanning grid columns
