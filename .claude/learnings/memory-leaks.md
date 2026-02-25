# Memory & Resource Management in Rango (Swift/SwiftUI)

This guide covers memory leak prevention, resource cleanup, and proper task management aligned with the fire-and-forget conversion architecture.

---

## 1. Fire-and-Forget Task Lifecycle

Conversion tasks run independently of views via `ConversionTaskManager`. They are NOT tied to any screen — the view dismisses immediately and the task runs in the background.

**Rules:**
- ViewModel methods are **synchronous** — they spawn `Task.detached` internally and return immediately
- Tasks register with `ConversionTaskManager.shared.register(id:task:)` for cancellation
- Tasks clean up with `defer { taskManager.remove(id: record.id) }` on completion
- Use `[weak self]` in all `Task.detached` closures to avoid retaining the ViewModel
- Check `Task.isCancelled` before expensive operations (image loading, FFmpeg calls)
- Pass all needed data as **parameters** — never read `@Published` properties inside `Task.detached` (race condition if user starts another conversion)

```swift
func processRotation(fileURL: URL, fileName: String, rotation: Double, flipH: Bool, flipV: Bool) {
    let record = makeRecord(fileName: fileName, fileURL: fileURL, toolType: "Rotate")
    store.add(record)

    let task = Task.detached { [weak self] in
        guard let self else { return }
        defer { self.taskManager.remove(id: record.id) }
        guard !Task.isCancelled else {
            await MainActor.run { self.failRecord(record, error: "Cancelled") }
            return
        }
        // ... do work ...
    }
    taskManager.register(id: record.id, task: task)
}
```

---

## 2. Resource Cleanup When Views Are Killed

When a SwiftUI view disappears, all media resources it created must be freed. Failure to do so leaks AVPlayers, audio sessions, image data, and task handles.

### AVPlayer / AVPlayerViewController

Always implement `dismantleUIViewController`:
```swift
static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: ()) {
    vc.player?.pause()
    vc.player = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
}
```

For views with `@State private var audioPlayer: AVPlayer?`, clean up in `.onDisappear`:
```swift
.onDisappear {
    audioPlayer?.pause()
    audioPlayer = nil
}
```

### Animated GIF Views (UIViewRepresentable)

GIF frames are decoded into `[UIImage]` arrays that can consume tens of MB. Always:
- Cap frame count: `let count = min(CGImageSourceGetCount(source), 150)`
- Use `Task.detached` for loading (not `DispatchQueue.global`) so it can be cancelled
- Store the load task in a `Coordinator` and cancel in `dismantleUIView`:

```swift
static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
    coordinator.loadTask?.cancel()
    coordinator.loadTask = nil
    coordinator.imageView?.stopAnimating()
    coordinator.imageView?.animationImages = nil  // Free all decoded frames
}
```

### Task Handles in Views

Any `Task` created for preview loading, file info fetching, etc. must be stored and cancelled:
```swift
@State private var fileInfoTask: Task<Void, Never>?
@State private var imageLoadTask: Task<Void, Never>?

.onDisappear {
    fileInfoTask?.cancel()
    fileInfoTask = nil
    imageLoadTask?.cancel()
    imageLoadTask = nil
}
```

### PHCachingImageManager

Call `stopCachingImagesForAllAssets()` in ViewModel `deinit` or view `onDisappear`.

---

## 3. Polling Tasks: Cancel on ALL Paths

FFmpeg progress polling runs every 500ms inside conversion tasks. It must be cancelled in **both** success and error paths:

```swift
var pollingTask: Task<Void, Never>?
do {
    pollingTask = startProgressPolling(...)
    let result = try await coordinator.convert(job: job)
    pollingTask?.cancel()  // Success path
    // ...
} catch {
    pollingTask?.cancel()  // Error path — don't forget!
    // ...
}
```

---

## 4. Main Thread Blocking Prevention

### File I/O Off Main Thread

Never call `FileManager` methods from view body, `onAppear`, or computed properties:
- `attributesOfItem(atPath:)` — use `.task` + `Task.detached`
- `Data(contentsOf:)` — use `Task.detached`
- `copyItem`, `moveItem`, `removeItem` — use background queue

```swift
@State private var fileSizeText = ""

.task {
    let path = fileURL.path
    let size = await Task.detached(priority: .utility) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let bytes = attrs[.size] as? Int64 else { return "" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }.value
    fileSizeText = size
}
```

### PHAsset.fetchAssets Off Main Thread

For libraries with thousands of assets, fetch on background thread:
```swift
func fetchAssets() {
    isLoading = true
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let result = PHAsset.fetchAssets(with: options)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in fetched.append(asset) }
        DispatchQueue.main.async {
            self?.assets = fetched
            self?.isLoading = false
        }
    }
}
```

### HistoryStore.save() on Background Queue

With 500 records + thumbnail data, JSON encoding blocks main thread. Snapshot and encode on a serial queue:
```swift
private let saveQueue = DispatchQueue(label: "com.rango.historystore.save", qos: .utility)

func save() {
    objectWillChange.send()
    let snapshot = records
    saveQueue.async {
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
}
```

---

## 5. Image Decoding & Caching

### Thumbnail Caching in ConversionRecord

Never decode thumbnails in computed properties — they run every render:
```swift
private var _cachedThumbnail: UIImage?
private var _thumbnailDataHash: Int?

var thumbnail: UIImage? {
    guard let data = thumbnailData else { return nil }
    let hash = data.hashValue
    if let cached = _cachedThumbnail, _thumbnailDataHash == hash { return cached }
    let image = UIImage(data: data)
    _cachedThumbnail = image
    _thumbnailDataHash = hash
    return image
}
```

Exclude cache fields from `Codable` with a `CodingKeys` enum.

### Preview Image Loading

Use ImageIO downsampling instead of loading full-resolution images for previews:
```swift
static func loadPreviewImage(from url: URL, maxPixelSize: CGFloat = 1200) -> UIImage? {
    let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }
    let downsampleOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else { return nil }
    return UIImage(cgImage: cgImage)
}
```

### Large Image Safety

Before loading full preview, check file size and pixel dimensions:
```swift
private static let maxPreviewFileSize: Int64 = 50 * 1024 * 1024  // 50 MB
private static let maxPreviewPixels: CGFloat = 100_000_000         // 100 MP
```

---

## 6. AVPlayer Seek Closures

Capture player weakly to avoid temporary retain cycles during seeks:
```swift
player.seek(to: .zero) { [weak player] _ in
    player?.play()
}
```

---

## 7. NotificationCenter Observer Scoping

Filter by the specific player item to avoid responding to unrelated events:
```swift
.onReceive(
    NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
        .filter { [weak audioPlayer] notification in
            (notification.object as? AVPlayerItem) === audioPlayer?.currentItem
        }
) { _ in isPlayingAudio = false }
```

---

## 8. Cancellation from History

`ConversionTaskManager.shared.cancel(id:)` is called from:
- **HistoryResultSheet** Cancel button — cancels the task, marks record as failed
- **HistoryStore.remove()** — cancels task before deleting output file
- **HistoryStore.removeAll()** — cancels all tasks in the category being cleared

---

## Quick Checklist for New Code

### Fire-and-Forget Tasks
- [ ] ViewModel method is **synchronous** (not `async`)
- [ ] All data passed as **parameters** (not read from `@Published` properties)
- [ ] `Task.detached` with `[weak self]` capture
- [ ] `defer { taskManager.remove(id:) }` in every task
- [ ] `Task.isCancelled` checks before expensive work
- [ ] Task registered with `taskManager.register(id:task:)`
- [ ] View callback calls method directly + navigates to history (no `Task {}` wrapper)

### Resource Cleanup on View Kill
- [ ] `AVPlayer` paused and set to nil in `dismantleUIViewController` or `.onDisappear`
- [ ] `AVAudioSession` deactivated when player is released
- [ ] GIF `animationImages` set to nil in `dismantleUIView`
- [ ] All `@State` task handles cancelled in `.onDisappear`
- [ ] `PHCachingImageManager.stopCachingImagesForAllAssets()` in cleanup

### Main Thread Safety
- [ ] No `FileManager` calls from view body or computed properties
- [ ] No `Data(contentsOf:)` or `UIImage(data:)` on main thread
- [ ] `PHAsset.fetchAssets` runs on background thread
- [ ] `HistoryStore.save()` encodes + writes on background queue

### Polling & Background Tasks
- [ ] Polling tasks cancelled on **both** success AND error paths
- [ ] Polling loop checks `Task.isCancelled` before sleeping
- [ ] Thumbnail computed properties are cached (not decoded every render)
- [ ] Image caches have size limits
