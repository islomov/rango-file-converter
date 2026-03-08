# Rango — iOS File Converter

## Project Overview
Rango is a universal file format converter iOS app (**iOS 16.6+**, Swift 5.9, SwiftUI) supporting 74 formats across 4 media categories. All processing is on-device.

## Supported Formats

**Image — 21 Formats**
HEIC, JPEG, PNG, JPG, WEBP, TGA, BMP, JP2, GIF, TIFF, PBM, PGM, EXR, PAM, PFM, RAS, RGB, SGI, SUNVBM, XWD, YUV

**Video — 21 Formats**
MP4, AMV, AVI, MOV, MPG, M4V, MKV, WMV, FLV, MPEG, RM, VOB, TS, WEBM, ASF, 3GP, SWF, MXF, F4V, 3G2, OGV

**Audio — 25 Formats**
MP3, WAV, FLAC, M4A, AAC, OGG, AC3, WMA, AMR, OPUS, AIFF, MP2, GSM, DTS, AU, CAF, WV, OGA, W64, VOC, SND, SPX, IRCAM

**Document — 7 Formats**
DOC, DOCX, PDF, HTML, ODT, RTF, TXT

## Architecture
- **Pattern:** MVVM + Coordinator
- **Layers:** Presentation (SwiftUI) → ViewModel (`ObservableObject`) → Domain (Use Cases/Protocols) → Data (Conversion Engines) → Infrastructure (FFmpeg/Firebase)
- **Navigation:** `NavigationStack` with coordinator, 3 tabs: Home, Profile, Settings

## Module Structure
- `RangoApp/` — Entry point, DI container
- `RangoUI/` — SwiftUI views, view models, navigation
- `RangoDomain/` — Pure Swift entities, protocols, use cases
- `RangoConversion/` — Conversion engines, FFmpeg bridge, workers, format registry
- `RangoDesign/` — Design tokens, theme, reusable components
- `RangoInfra/` — Firebase, file system, background tasks


## iOS 16.6 Compatibility Rules
The minimum deployment target is **iOS 16.6**. Do NOT use any iOS 17+ or iOS 18+ APIs:

| Avoid (iOS 17+/18+) | Use Instead (iOS 16+) |
|---|---|
| `@Observable` | `ObservableObject` + `@Published` + `import Combine` |
| `@State private var vm` (with Observable) | `@StateObject private var vm` (with ObservableObject) |
| SwiftData (`@Model`, `ModelContainer`, `@Query`) | `Codable` classes + JSON file persistence (`HistoryStore`) |
| `Tab("Label", systemImage:) { }` (iOS 18) | `.tabItem { Label("Label", systemImage:) }` |
| `.onChange(of:) { oldValue, newValue in }` | `.onChange(of:) { newValue in }` (single param) |
| `.toolbar { ToolbarItem(placement: .topBarTrailing) }` | `.toolbar { ToolbarItem(placement: .navigationBarTrailing) }` |
| `#Predicate` | Manual filtering on arrays |

## Key Conventions
- Views observe ViewModels via `@StateObject` / `@ObservedObject`
- ViewModels are `ObservableObject` with `@Published` properties (requires `import Combine`)
- History persistence uses `HistoryStore` (JSON-based singleton), not SwiftData
- Pass `HistoryStore` to views via `.environmentObject()`
- Domain layer is pure Swift with no framework imports
- Conversion engines conform to `ConversionEngine` protocol (Actor-based)
- `ConversionCoordinator` routes jobs to the correct engine by `MediaType`
- `FormatRegistry` holds all 74 format definitions and the conversion graph
- 22 formats use native iOS APIs; 52 require FFmpegKit

## Dependencies
FFmpegKit (format conversion), Firebase, Kingfisher, swift-algorithms

## Performance Targets
- Image < 2s, Video (1min 1080p) < 30s, Audio (5min) < 5s, Document < 3s
- Cold launch < 1.5s, Memory < 200MB

## Testing
- **No automated tests** — the user performs manual testing on device/simulator
- After making changes, verify the build succeeds with `xcodebuild build` but do **not** run UI tests or attempt to launch the simulator
- Use a valid simulator destination (e.g. `iPhone 17 Pro`) — older names like `iPhone 16` may not be available

## Localizable.xcstrings
- Xcode auto-modifies `RangoFileConverter/Localizable.xcstrings` on every build — these changes are noise
- Before committing, run `git restore RangoFileConverter/Localizable.xcstrings` to discard build-generated changes
- Only commit `Localizable.xcstrings` when you intentionally added or modified localization strings

## Agent Learnings
Before starting work, check `.claude/learnings/` for known issues and patterns discovered by previous agents. When you discover a bug, workaround, or important pattern, save it as a markdown file in `.claude/learnings/` so future agents benefit.
