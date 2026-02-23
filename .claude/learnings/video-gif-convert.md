# Video to GIF Conversion

## FFmpeg GIF Palette Optimization (Single-Pass)

Basic `-c:v gif` produces low-quality, banded output. High-quality GIF requires palette optimization.

### Two approaches:
1. **Two-pass** (not used): Requires two FFmpeg invocations — first generates palette.png, then uses it. Incompatible with current `FFmpegWrapper.convert()` which only supports single-input commands.
2. **Single-pass with filter_complex** (used): Splits the video stream, generates palette inline, and applies it in one command:

```
[0:v] fps=10,scale=320:-1:flags=lanczos,split [a][b]; [a] palettegen [p]; [b][p] paletteuse
```

### Key implementation details:
- `-filter_complex` and `-vf` **cannot be used together**. When output is GIF, `buildFFmpegArgs` returns early with GIF-specific args, skipping the normal `-vf` filter chain.
- `scale=W:-1:flags=lanczos` — the `-1` auto-calculates height to preserve aspect ratio. `lanczos` gives sharper downscaling.
- `-loop 0` makes the GIF loop infinitely.
- FPS reduction (`fps=10`) is critical for file size — video at 30fps becomes massive as GIF.

### ConversionJob fields used:
- `job.fps: Int?` — frame rate for GIF output (default 10 if nil)
- `job.scale: CGSize?` — width only matters; height set to -1 for auto
- `job.progressFilePath: String?` — progress tracking works with GIF too (appended before the filter_complex args)

## GIF Preview with AVAssetImageGenerator

To show a live preview of how the GIF will look before converting:

1. **Extract frames** using `AVAssetImageGenerator`:
   - `appliesPreferredTrackTransform = true` — handles portrait/rotated videos correctly
   - `maximumSize = CGSize(width: targetWidth, height: targetWidth)` — scales frames to match output width
   - `requestedTimeToleranceBefore/After = .zero` — frame-accurate extraction (no keyframe snapping)
   - `copyCGImage(at:actualTime:)` — synchronous but called from `Task.detached` to avoid blocking UI

2. **Animate with Timer** (same pattern as `MakeGifView`):
   - Timer interval = `1.0 / fps`
   - Cycles `currentFrameIndex` through extracted frames
   - Timer restarts when FPS slider changes
   - Frames re-extract when width slider changes (need different resolution)

3. **Performance considerations**:
   - Cap at 30 frames max for preview (first 3 seconds of video)
   - Cancel previous extraction task when settings change
   - Show thumbnail with material overlay + spinner while extracting
   - Use `Task.detached` + `Task.isCancelled` checks for responsive cancellation

## Navigation Pattern (activeTool + shared picker)

The Video tab uses a single `showVideoPicker` for all tools, with an `activeTool` string to track which tool requested it. After video selection, `handleVideoSelected()` routes to the correct detail view based on `activeTool`.

For GIF:
- `handleToolTap("gif")` → sets `activeTool = "gif"`, shows picker
- `handleVideoSelected` → calls `viewModel.selectVideoForGif(...)` which sets `showGifDetail = true`
- `navigationDestination(isPresented: $viewModel.showGifDetail)` → shows `VideoToGifView`
- On convert: `onConvert` fires a `Task` for async conversion, then `DispatchQueue.main.async` pops both views and switches to history tab

This is the same pattern used by compress, speed, time clip, and format conversion tools.

## GIF Format in FormatRegistry

GIF is defined as `mediaType: .image` (not `.video`) in `FormatRegistry.imageFormats`:
```swift
.init(id: "gif", displayName: "GIF", fileExtension: "gif", mediaType: .image, ...)
```

This matters because:
- `FFmpegConversionEngine.canConvert` checks `supportedMediaTypes` which includes `.image`
- `buildFFmpegArgs` has special handling: `if job.outputFormat.mediaType == .image && job.outputFormat.id != "gif"` adds `-frames:v 1` — GIF is explicitly excluded since it's multi-frame
- The GIF branch in `buildFFmpegArgs` returns early before this check anyway

## ConversionRecord for GIF

Uses `toolType: "GIF"` and `mediaCategory: "video"` so it appears in the Video tab's history (filtered by `mediaCategory == "video"`). The `toolType` distinguishes it from format conversions in history display.
