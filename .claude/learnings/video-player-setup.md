# Video Player Setup & Navigation

## Video Loading from AssetPicker

When a user selects a video from the gallery, `VideoPickerView` delegates to `VideoLibraryViewModel.loadFullVideo(for:)`. This method:

1. Finds the `PHAssetResource` with type `.video` from the selected `PHAsset`
2. Writes the raw video bytes to a temp file using `PHAssetResourceManager.default().writeData(for:toFile:options:)`
3. Generates a thumbnail via `AVAssetImageGenerator` at time `.zero` with `maximumSize` of 600x600
4. Returns a tuple `(UIImage, String, URL)` — thumbnail, file name, and temp file URL

The loading feels smooth because the gallery grid already has low-res thumbnails cached via `PHCachingImageManager`, so the user sees the grid instantly. Only when they tap a video does the full export happen, shown with a `ProgressView("Loading video...")` overlay.

For files selected via `.fileImporter`, the security-scoped URL is immediately copied to `FileManager.temporaryDirectory` before the security scope expires (inside `defer { url.stopAccessingSecurityScopedResource() }`).

## AVPlayer Aspect Ratio (Portrait vs Landscape)

The player uses a raw `AVPlayerLayer` via `UIViewRepresentable` (not `VideoPlayer` from AVKit — see second learning for why). The aspect ratio is determined dynamically from the video track:

```swift
let tracks = try await asset.loadTracks(withMediaType: .video)
if let track = tracks.first {
    let size = try await track.load(.naturalSize)
    let transform = try await track.load(.preferredTransform)
    let transformedSize = size.applying(transform)
    let w = abs(transformedSize.width)
    let h = abs(transformedSize.height)
    if w > 0 && h > 0 {
        videoAspectRatio = w / h
    }
}
```

Key detail: `naturalSize` alone is not enough. iPhone videos recorded in portrait have a `naturalSize` of e.g. 1920x1080 (landscape) but a `preferredTransform` that rotates 90 degrees. Applying the transform and taking `abs()` of both dimensions gives the correct display size (1080x1920 for portrait). The `PlayerView` then uses `.aspectRatio(videoAspectRatio, contentMode: .fit)` and `videoGravity = .resizeAspect` so the player fits naturally.

While the player loads, the thumbnail (passed from the picker) is shown as a fallback with `.aspectRatio(contentMode: .fit)`.

## PlayerView UIViewRepresentable

```swift
private struct PlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
```

By overriding `layerClass` to `AVPlayerLayer`, the view's root layer IS the player layer — no sublayer management needed. The layer automatically resizes with Auto Layout.

## Resource Cleanup

In `.onDisappear`, `cleanupPlayer()` is called:

```swift
private func cleanupPlayer() {
    player?.pause()
    isPlaying = false
    if let observer = timeObserver {
        player?.removeTimeObserver(observer)
        timeObserver = nil
    }
    player = nil
}
```

This removes the periodic time observer (critical — not removing it causes a retain cycle and crash), pauses playback, and nils out the player so ARC deallocates it. Setting `timeObserver = nil` ensures we don't double-remove on re-entry.

## Navigation: Back Button Returns to Tools Tab, Not Picker

The navigation stack in `VideoConverterView` is:

```
Tools Grid → VideoPickerView → VideoTimeClipView
```

All three screens are pushed via `.navigationDestination(isPresented:)`. When the clip is applied, the `onApply` callback sets:

```swift
showTimeClipView = false   // pops clip view
showVideoPicker = false     // pops picker view
selectedTab = .history      // switches to history tab
```

Both booleans are set to `false` in the same `DispatchQueue.main.async` block, so NavigationStack pops both screens in one animation back to the tools grid (now showing history tab).

When the user taps the back button manually from the clip view, SwiftUI's NavigationStack only pops `showTimeClipView` — leaving them on the picker. From the picker, back goes to the tools grid. This is the standard NavigationStack behavior with chained `navigationDestination` modifiers.
