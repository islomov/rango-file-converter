# Architecture & Code Patterns

## Fire-and-Forget Conversion Tasks
ViewModel conversion methods are **synchronous** — they create a `ConversionRecord(.converting)`, add to store, spawn `Task.detached`, and return immediately. View navigates to history tab right after calling.

**Rules:**
- Pass all data as **parameters** — never read `@Published` properties inside `Task.detached` (race condition)
- Use `Task.detached` (not `Task {}`) to avoid inheriting actor context
- `[weak self]` in all `Task.detached` closures
- `defer { taskManager.remove(id: record.id) }` for cleanup
- Check `Task.isCancelled` before expensive operations
- Register task with `ConversionTaskManager.shared.register(id:task:)` for cancellation
- No `Task {}` wrapper in view callbacks — method is sync

## Resource Cleanup
- **AVPlayer**: pause + nil in `dismantleUIViewController` or `.onDisappear`; deactivate `AVAudioSession`
- **GIF frames**: set `animationImages = nil` in `dismantleUIView`; cap frames at 150
- **Task handles**: store in `@State`, cancel in `.onDisappear`
- **Time observers**: always remove periodic observers (retain cycle + crash if not)
- **Polling tasks**: cancel on BOTH success AND error paths

## Main Thread Safety
- No `FileManager` calls from view body or computed properties — use `.task` + `Task.detached`
- `PHAsset.fetchAssets` on background thread for large libraries
- `HistoryStore.save()` encodes + writes on background serial queue
- Thumbnail computed properties must be cached (hash-based), not decoded every render
- Use ImageIO downsampling (`CGImageSourceCreateThumbnailAtIndex`) for previews

## AVPlayer & Video
- `naturalSize` alone is wrong for portrait video — apply `preferredTransform` + `abs()` both dimensions
- Use raw `AVPlayerLayer` (not SwiftUI `VideoPlayer`) for clip boundary enforcement — built-in controls bypass your code causing state desync
- Override `layerClass` to `AVPlayerLayer` — no sublayer management needed
- Play always seeks to `startTime` first via completion handler, then calls `play()`
- `toleranceBefore: .zero, toleranceAfter: .zero` for frame-accurate seeking
- Filter `AVPlayerItemDidPlayToEndTime` by specific player item to avoid cross-contamination
- Capture player weakly in seek closures

## Audio Playback
- AVPlayer supports only 9/25 audio formats natively: mp3, wav, m4a, aac, aiff, flac, caf, au, mp2
- Unsupported formats: convert to temp WAV via FFmpeg (`-vn -acodec pcm_s16le`) for preview
- Crop always uses original file (not preview WAV) to preserve quality

## File Handling
- Security-scoped URLs from `fileImporter` expire after callback — copy to temp immediately
- PhotosPicker: temp file extension matters (FFmpeg uses it to detect input format)

## Project Structure
- Feature-based: `Features/<Category>/Views/` and `ViewModels/`; cross-feature in `Shared/`; engines in `Engine/`
- Uses `PBXFileSystemSynchronizedRootGroup` — moving files on disk is sufficient, no `.pbxproj` edits
- Use `git mv` to preserve history
