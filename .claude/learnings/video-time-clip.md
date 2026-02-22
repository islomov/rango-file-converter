# Video Time Clip: Clipping & Custom Playback Controls

## FFmpeg Stream-Copy Clipping

The clip is performed by `FFmpegWrapper.shared.convert()` with extra args:

```swift
try await FFmpegWrapper.shared.convert(
    input: videoURL,
    output: outputURL,
    extraArgs: [
        "-ss", String(format: "%.3f", startTime),
        "-to", String(format: "%.3f", endTime),
        "-c", "copy"
    ]
)
```

- `-ss` sets the start position, `-to` sets the end position (absolute, not relative)
- `-c copy` means stream copy — no re-encoding. This makes clipping nearly instant regardless of video length, because it just copies the compressed packets between the two timestamps
- The output file keeps the same extension as the input (preserves container format)
- Output goes to `tmp/rango_conversions/clip_<uuid>.<ext>`, then `ConversionRecord.persistOutput()` copies it to `Documents/rango_conversions/`

After clipping, a thumbnail is generated from the output file at time `.zero` using `AVAssetImageGenerator`.

## Why Custom Play Button Instead of AVPlayer's Built-in Controls

We use a raw `AVPlayerLayer` (`PlayerView` via `UIViewRepresentable`) instead of SwiftUI's `VideoPlayer` from AVKit. This was a deliberate choice after discovering that `VideoPlayer`'s built-in media controls conflict with clip boundary enforcement.

### The Problem with VideoPlayer (AVKit)

`VideoPlayer` renders its own play/pause button, scrubber, and transport controls. These controls directly call `player.play()` and `player.pause()` without going through our code. When we tried to enforce clip boundaries (stop playback at `endTime`, constrain playback to start at `startTime`), the built-in controls created several bugs:

1. **Play from endTime bug**: When the user drags the end slider, we seek to `endTime` to preview the end frame. Then pressing AVPlayer's built-in play button starts playback from `endTime`. Our periodic time observer sees `currentTime >= endTime` and immediately pauses — the video appears to not play at all.

2. **Boundary enforcement loop**: Adding logic to seek back to `startTime` when hitting `endTime` creates a visible flash — the video briefly plays from `endTime`, the observer fires (every 0.1s), pauses, and seeks back. The user sees a stutter.

3. **State desync**: AVPlayer's built-in UI tracks its own play/pause state. When our observer pauses the player, the built-in UI still shows "playing" state, or vice versa. There's no API to sync our `isPlaying` state with the built-in controls.

### The Solution: Raw AVPlayerLayer + Custom Controls

By using `AVPlayerLayer` directly (no built-in UI), we have full control over playback:

- **Our play button always seeks to `startTime` first**, then calls `player.play()`. This guarantees playback starts from the clip start, never from a stale position.
- **Our `isPlaying` state is always accurate** because we're the only ones calling `play()` and `pause()`.
- **The periodic observer can safely enforce boundaries** because it only checks `isPlaying` (which we control) before pausing at `endTime`.

### Custom Playback Controls

The controls section has three buttons:

- **Skip to start** (`backward.end.fill`): calls `pauseAndSeek(to: startTime)`
- **Play/Pause** (`play.circle.fill` / `pause.circle.fill`): calls `togglePlayback()`
- **Skip to end** (`forward.end.fill`): calls `pauseAndSeek(to: max(startTime, endTime - 0.5))`

Plus a tap gesture on the video itself that also calls `togglePlayback()`, with a fade-in/fade-out play icon overlay.

### togglePlayback() Implementation

```swift
private func togglePlayback() {
    guard let player else { return }
    if isPlaying {
        player.pause()
        isPlaying = false
    } else {
        player.seek(to: CMTime(seconds: startTime, ...)) { _ in
            player.play()
            isPlaying = true
        }
    }
}
```

Key: play always seeks to `startTime` first using the completion handler to ensure the seek finishes before playback begins. This prevents the "play from wrong position" bug.

### Boundary Enforcement in Periodic Observer

```swift
let observer = avPlayer.addPeriodicTimeObserver(
    forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
    queue: .main
) { [weak avPlayer] time in
    let secs = CMTimeGetSeconds(time)
    guard secs.isFinite else { return }
    currentTime = secs

    if isPlaying && secs >= endTime {
        avPlayer?.pause()
        isPlaying = false
        avPlayer?.seek(to: CMTime(seconds: startTime, ...))
        currentTime = startTime
    }
}
```

The `isPlaying` guard is critical — without it, the observer would fire during manual seeks (e.g., slider drags) and incorrectly trigger the boundary logic.

## Range Slider Interaction

When the user drags sliders, `pauseAndSeek(to:)` is called:

- **Start slider**: pauses and seeks to the new `startTime` to preview the start frame
- **End slider**: pauses and seeks to `max(startTime, endTime - 0.5)` — slightly before the end, so the playhead is inside the clip range and the next play works correctly

```swift
private func pauseAndSeek(to seconds: Double) {
    player?.pause()
    isPlaying = false
    player?.seek(to: CMTime(seconds: seconds, ...), toleranceBefore: .zero, toleranceAfter: .zero)
    currentTime = seconds
}
```

`toleranceBefore: .zero, toleranceAfter: .zero` ensures frame-accurate seeking (no keyframe snapping), which matters for precise clip boundaries.
