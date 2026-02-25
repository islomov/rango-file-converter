# Audio Cropping: Implementation & Patterns

## Overview
Audio cropping lets users select a time range from an audio file and export the trimmed clip. It mirrors the video "Time Clip" tool pattern.

**Key files:**
- `rangofileconverter/Features/Audio/Views/AudioCropView.swift` — Crop UI
- `rangofileconverter/Features/Audio/Views/AudioConverterView.swift` — Tool routing
- `rangofileconverter/Features/Audio/ViewModels/AudioConverterViewModel.swift` — `cropAudio()` method
- `rangofileconverter/Shared/RangeSliderView.swift` — Shared dual-thumb slider

## FFmpeg Crop Command

Same as video time clip — uses stream copy for near-instant trimming:

```swift
try await FFmpegWrapper.shared.convert(
    input: inputURL,
    output: outputURL,
    extraArgs: [
        "-ss", String(format: "%.3f", startTime),
        "-to", String(format: "%.3f", endTime),
        "-c", "copy"
    ]
)
```

- `-ss` = start position, `-to` = end position (absolute timestamps)
- `-c copy` = stream copy, no re-encoding (fast)
- Output keeps the same extension/format as input

## Playback for All Audio Formats

AVPlayer only supports 9 of the 25 audio formats natively:
`mp3, wav, m4a, aac, aiff, flac, caf, au, mp2`

For unsupported formats (ogg, opus, dts, gsm, wma, etc.), the view converts to a temporary WAV via FFmpeg before creating the AVPlayer:

```swift
if !isAVPlayerCompatible {
    isConverting = true
    let wavURL = tempDir.appendingPathComponent("preview_\(shortID).wav")
    try await FFmpegWrapper.shared.convert(
        input: fileURL,
        output: wavURL,
        extraArgs: ["-vn", "-acodec", "pcm_s16le"]
    )
    audioURL = wavURL
    playableURL = wavURL  // Stored for cleanup
    isConverting = false
}
```

- Shows "Preparing audio..." with a `ProgressView` while converting
- If conversion fails, the view still loads duration (if possible) but hides playback controls
- Temporary WAV is cleaned up in `cleanupPlayer()` via `FileManager.removeItem`

## RangeSliderView Extraction

`RangeSliderView` was originally `private` inside `VideoTimeClipView.swift`. It was extracted to `Shared/RangeSliderView.swift` as an `internal` struct so both video and audio crop views can reuse it.

The slider uses:
- `GeometryReader` for width calculations
- Two `Circle` thumbs with `DragGesture`
- A highlighted `Capsule` between the two thumbs (`.fill(.mint)`)
- `onLowerChanged` / `onUpperChanged` callbacks for seeking on drag

## Navigation Flow

```
AudioConverterView (tap "Audio Cropping")
  → showCropPicker = true
    → AudioPickerView (select file)
      → cropFileName, cropFileURL stored
      → showCropView = true
        → AudioCropView (adjust range, preview)
          → onApply(startTime, endTime)
            → viewModel.cropAudio(inputURL:fileName:startTime:endTime:)
            → showCropView = false, showCropPicker = false
            → selectedTab = .history
```

Uses two `@State` navigation flags (`showCropPicker`, `showCropView`) and two `.navigationDestination(isPresented:)` modifiers.

## Gotcha: Crop Uses Original File, Not Preview WAV

The crop operation (`cropAudio()`) always uses the **original file URL** — not the temporary WAV created for playback preview. The preview WAV is only for the AVPlayer in the UI. This preserves the original format and quality.

## Adding New Audio Tools Checklist

1. Add tool entry in `audioTools` array with `isAvailable: true`
2. Add `@State` nav flags and file state in `AudioConverterView`
3. Add `case` in `handleToolTap`
4. Add `.navigationDestination` blocks for picker → tool view
5. Create tool view with `onApply` callback
6. Add ViewModel method following fire-and-forget pattern (see `fire-and-forget-tasks.md`)
7. Pass all data as parameters — don't read `@Published` properties inside `Task.detached`
