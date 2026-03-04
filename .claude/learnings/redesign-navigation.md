# Redesign Navigation Architecture

## Tab Structure Change
- **Before:** 4-tab native TabView (Image, Video, Audio, Document) — each tab was a full converter view
- **After:** 3-tab custom floating tab bar (Home, History, Settings)
  - Home → shows 4 stacked service cards → tapping a card navigates to the converter view
  - History → global history across all categories
  - Settings → existing SettingsView

## Key Decisions
- Custom floating tab bar (pill-shaped, `.ultraThinMaterial` background) replaces native `TabView`
- Each converter view retains its own `NavigationStack` and custom header — no wrapping needed
- `MediaCategory` enum added to `HomeView.swift` for type-safe category selection
- `Color(hex:)` extension added to `HomeView.swift` for Figma color matching
- Tapping Home tab icon when already on Home resets to the card selection (clears `selectedCategory`)

## Colors from Figma Design
- Background: `#F2F2F6`
- Black card (Image): `#1D1D1D`
- Green card (Audio): `#A3E96C`
- Purple card (Documents): `#BDA9F1`
- Orange accent/gradient: `#F4800D` to `#FFAD5B`
- Gray text: `#888888`

## Card Layout
- Cards are stacked with `ZStack` and offset — overlapping rounded tops create a layered look
- Offsets: Image=0, Video=118, Audio=236, Documents=354
- Heights: Image=256, Video=256, Audio=190, Documents=143
- Top corner radius: 32pt for all cards
- Only Documents card has bottom corner radius

## Files Created
- `Features/Home/Views/HomeView.swift` — Home screen with stacked cards
- `Features/History/Views/HistoryView.swift` — Global history with category filter chips

## Files Modified
- `ContentView.swift` — Replaced native TabView with custom floating tab bar + tab switching logic
