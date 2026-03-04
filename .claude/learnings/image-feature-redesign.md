# Image Feature Selection Screen Redesign

## What Changed
- Removed the Tools/History tab picker from `ImageConverterView` — history is now only in the global History tab
- Removed the settings gear icon from the header — settings lives in the Settings tab
- Added `onBack` closure to `ImageConverterView` for navigating back to Home
- Replaced SF Symbol icons with custom Figma-exported SVG icons in the asset catalog
- New design: 2-column grid of white rounded cards on `#F2F2F6` background
- "Make GIF" card spans full width using `.gridCellColumns(2)`

## New Icon Assets Added
All icons are SVGs with `original` rendering intent and `preserves-vector-representation: true`:
- `icon_convert` — streamline-plump:convert-pdf-1-solid
- `icon_compress` — material-symbols:compress-rounded
- `icon_rotate` — f7:rotate-left-fill
- `icon_resize` — fluent:resize-16-filled
- `icon_crop` — material-symbols:crop
- `icon_stitch` — icon-park-solid:graphic-stitching-four
- `icon_gif` — mage:gif-fill
- `icon_arrow_left` — vuesax/linear/arrow-left (template rendering)

## Design Specs (from Figma)
- Background: `#F2F2F6`
- Card: white, 16px corner radius, 106px height
- Grid: 2 columns, 12px spacing, 16px horizontal padding
- Icons: 28x28px, orange gradient from Figma
- Title: system semibold 20px, centered with back arrow on left
- Card labels: system semibold 16px, `#1D1D1D`, -0.408 tracking
- Header height: 56px

## Key Patterns
- Montserrat font is in Figma design but NOT bundled in the project — use `.system` font with matching size/weight
- `Color(hex:)` extension is defined in `HomeView.swift` and accessible project-wide
- The project has NO separate RangoDesign module — design tokens are inline
- Icons from Figma MCP are SVGs served from temporary URLs (7-day expiry) — must download and save to asset catalog
- `gridCellColumns(2)` works on iOS 16+ for making a LazyVGrid item span multiple columns

## Figma SVG Gotcha
- Figma MCP exports SVGs with CSS variables for colors, e.g. `stroke="var(--stroke-0, #1D1D1D)"`
- Xcode does NOT support CSS variables in SVGs — template rendering and tinting will silently fail
- **Fix:** Replace `var(--stroke-0, #1D1D1D)` with the raw hex `#1D1D1D` before adding to asset catalog
- Also remove `preserveAspectRatio="none"`, `width="100%"`, `height="100%"`, and inline `style` attributes from the root `<svg>` — use explicit pixel dimensions and a `viewBox` instead
- Always inspect downloaded Figma SVGs before committing — they often need cleanup for Xcode compatibility

## Navigation Flow
- `ContentView` manages `selectedCategory` state
- `ImageConverterView.onBack` calls `{ selectedCategory = nil }` in ContentView
- Each converter view has its own `NavigationStack` for internal sub-navigation
