# Video Progress Tracking with Percentage

## Problem

FFmpegKit on iOS (kewlbear/FFmpeg-iOS v0.0.5) only exposes `ffmpeg([String]) -> Int` — a synchronous C function with **no progress callbacks**, no delegate pattern, and no `ffprobe`. We need real-time percentage progress for video operations (convert, compress, speed change).

## Solution: `-progress` File Polling

FFmpeg's CLI supports `-progress <filepath>` which writes progress data to a file in real time. We poll this file from a detached Swift Task every 500ms.

### How It Works

1. **Probe input duration** using `AVAsset` (native iOS, no ffprobe needed):
   ```swift
   let asset = AVAsset(url: inputURL)
   let cmDuration = try await asset.load(.duration)
   let totalDurationUs = CMTimeGetSeconds(cmDuration) * 1_000_000
   ```

2. **Pass `-progress <filepath>` to FFmpeg** as extra args before the output file. FFmpeg writes blocks like:
   ```
   frame=120
   fps=45.2
   out_time_us=4000000
   progress=continue
   ```

3. **Poll the file** from a `Task.detached` every 500ms, parse `out_time_us` values:
   ```swift
   // Read file, find last out_time_us line, compute ratio
   progress = min(lastOutTimeUs / totalDurationUs, 0.99)
   ```

4. **Update SwiftData record** on MainActor, triggering UI refresh in HistoryRowView.

5. **Cleanup**: Cancel polling task and delete progress file after FFmpeg finishes.

### Key Implementation Details

- **Cap progress at 0.99** during polling. Set to 1.0 only after FFmpeg actually completes successfully. This prevents showing 100% while FFmpeg is still finalizing the file.
- **Parse from end of file** — FFmpeg appends many progress blocks. Reverse-iterate lines to find the last `out_time_us=` value efficiently.
- **Speed change adjusts expected duration** — when changing speed, the output duration is `inputDuration / speed`, so use `totalDurationUs / speed` as the denominator.
- **Time clip (`-c copy`) is too fast for progress** — stream copying doesn't re-encode, so it completes nearly instantly. No meaningful progress to track; just show indeterminate spinner briefly.
- **`ConversionJob.progressFilePath`** — Added as `var` on ConversionJob. When set, `FFmpegConversionEngine.buildFFmpegArgs()` automatically includes `-progress <path>` in the FFmpeg command.

### Where Progress Is Stored

- `ConversionRecord.progress: Double = 0.0` — SwiftData `@Model` property
- `HistoryRowView` reads `record.progress`:
  - `progress == 0` → indeterminate spinner + "Starting..."
  - `progress > 0` → circular `ProgressView(value:)` + percentage text (e.g. "42%")
  - `progress == 1.0` (status `.converted`) → green "Done" checkmark

### Background Processing Pattern

All video tools follow this pattern in `VideoConverterViewModel`:

1. Create `ConversionRecord` with `.converting` status
2. Insert into SwiftData context → appears in History tab immediately
3. Navigate user to History tab (via `DispatchQueue.main.async`)
4. Probe duration with `AVAsset`
5. Create temp progress file
6. Start polling task
7. Run FFmpeg (via `FFmpegWrapper.shared.convert()`)
8. Cancel polling, delete progress file
9. On success: persist output, set `progress = 1.0`, status → `.converted`
10. On failure: status → `.failed`, set `errorMessage`
11. Save context

### Methods in VideoConverterViewModel

| Method | Tool | Progress? | Notes |
|--------|------|-----------|-------|
| `convert(to:context:)` | Format Conversion | Yes | Uses `ConversionCoordinator` → `FFmpegConversionEngine` |
| `compressVideo(...)` | Compression | Yes | Direct `FFmpegWrapper` call, mpeg4 encoder |
| `changeSpeed(...)` | Speed Change | Yes | `setpts` video filter + chained `atempo` audio filter |
| `clipVideo(...)` | Time Clip | No (too fast) | `-c copy` stream copy, no re-encoding |

### Reusable Helpers

- `probeDurationUs(url:) -> Double` — Returns total duration in microseconds via AVAsset
- `startProgressPolling(progressFile:totalDurationUs:record:context:) -> Task` — Returns cancellable polling task
- `parseProgress(from:totalDurationUs:) -> Double` — Static, reads progress file and returns 0.0–0.99
- `buildAtempoFilter(for speed:) -> String` — Chains `atempo` filters (FFmpeg only accepts 0.5–2.0 per filter)

### Gotchas

- **FFmpegWrapper is actor-isolated** — Only one FFmpeg conversion runs at a time (FFmpeg uses global C state). If user starts multiple conversions, they queue up.
- **`[weak record]` in Task.detached** — ConversionRecord is a class (`@Model`), use weak reference to avoid retain cycles if the record is deleted while polling.
- **Progress file path must be absolute** — Relative paths won't work since FFmpeg's working directory isn't guaranteed.
- **`out_time_us` can be negative** early in conversion — Always check `us > 0` before using.
