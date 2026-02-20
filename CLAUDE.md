# FormatX — iOS File Converter

## Project Overview
FormatX is a universal file format converter iOS app (iOS 17+, Swift 5.9, SwiftUI) supporting 74 formats across 4 media categories: Image (21), Video (21), Audio (25), Document (7). All processing is on-device. Freemium model with ads (free tier) and subscriptions (weekly $19.99 w/ 3-day trial, yearly $49.99).

## Architecture
- **Pattern:** MVVM + Coordinator
- **Layers:** Presentation (SwiftUI) → ViewModel (`ObservableObject`) → Domain (Use Cases/Protocols) → Data (Conversion Engines) → Infrastructure (FFmpeg/AdMob/Firebase)
- **Navigation:** `NavigationStack` with coordinator, 3 tabs: Home, Profile, Premium

## Module Structure
- `FormatXApp/` — Entry point, DI container
- `FormatXUI/` — SwiftUI views, view models, navigation
- `FormatXDomain/` — Pure Swift entities, protocols, use cases (zero dependencies)
- `FormatXConversion/` — Conversion engines, FFmpeg bridge, workers, format registry
- `FormatXDesign/` — Design tokens, theme, reusable components
- `FormatXInfra/` — StoreKit 2, AdMob, Firebase, file system, background tasks
- `FormatXTests/` — Unit, integration, snapshot tests

## Key Conventions
- Views observe ViewModels via `@StateObject`
- Domain layer is pure Swift with no framework imports
- Conversion engines conform to `ConversionEngine` protocol (Actor-based)
- `ConversionCoordinator` routes jobs to the correct engine by `MediaType`
- `FormatRegistry` holds all 74 format definitions and the conversion graph
- 22 formats use native iOS APIs; 52 require FFmpegKit

## Dependencies
FFmpegKit (format conversion), StoreKit 2, SwiftData, Google AdMob, Firebase, Kingfisher, swift-algorithms

## Performance Targets
- Image < 2s, Video (1min 1080p) < 30s, Audio (5min) < 5s, Document < 3s
- Cold launch < 1.5s, Memory < 200MB

## Testing
XCTest for unit/integration, swift-snapshot-testing for snapshots, XCUITest for UI. Target 80%+ unit coverage.

## See Also
- Full architecture: `.context/ARCHITECTURE.md`
