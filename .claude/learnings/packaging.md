# Project Packaging Structure

## Before (Flat Structure)
```
rangofileconverter/
  Models/          — all models mixed together
  ViewModels/      — all viewmodels mixed together
  Views/           — all views mixed together
    Components/    — shared components
  Engine/          — conversion engines
```

Problems with flat structure:
- No clear ownership — hard to tell which files belong to which feature
- Models/ViewModels/Views grow unbounded as features are added
- Difficult to onboard new contributors or work on features in parallel

## After (Feature-based Structure)
```
rangofileconverter/
  rangofileconverterApp.swift
  ContentView.swift
  Engine/                        — conversion engines (shared across features)
  Shared/                        — shared models and components
  Features/
    Image/
      ViewModels/
      Views/
    Video/
      Views/
    Audio/
      Views/
    File/
      Views/
```

## Key Decisions

### Root-level packages
Only three packages at root: `Engine/`, `Shared/`, `Features/`. App entry point files (`rangofileconverterApp.swift`, `ContentView.swift`) live at root.

### Feature packages
Each media category (Image, Video, Audio, File) gets its own package under `Features/`. Each feature package contains its own `Views/` and `ViewModels/` subfolders.

### Shared package
Cross-feature files go in `Shared/`:
- `FormatRegistry.swift` — format definitions used by all features
- `ConversionRecord.swift` — SwiftData model for conversion history
- `HistoryRowView.swift` — reusable history row component

### Engine package
Conversion engines stay in `Engine/` at root level since they serve all features:
- `ConversionEngine.swift` — protocol + shared types
- `ConversionCoordinator.swift` — routes jobs to engines
- `FFmpegConversionEngine.swift` — FFmpeg-based conversion
- `FFmpegWrapper.swift` — low-level FFmpeg actor
- `NativeImageEngine.swift` — native iOS image encoding

## Xcode Considerations
- Project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), so moving files on disk is sufficient — no `.pbxproj` edits needed
- All files remain in the same Swift module, so no import path changes required
- Use `git mv` to preserve git history when restructuring

## Guidelines for Adding New Files
1. Feature-specific views go in `Features/<Category>/Views/`
2. Feature-specific viewmodels go in `Features/<Category>/ViewModels/`
3. Feature-specific models go in `Features/<Category>/Models/`
4. Cross-feature models/components go in `Shared/`
5. Conversion engines go in `Engine/`
