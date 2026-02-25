# Memory Leak Patterns & Prevention in Swift/SwiftUI

## 1. Uncancelled Tasks on View Disappear

**Pattern:** `Task { }` or `Task.detached { }` created in button actions or `onAppear` without storing the handle.

**Problem:** The task runs independently of the view lifecycle. If the user navigates away, the task continues holding references to captured state, view models, and large data (images, AVAssets).

**Fix:** Store the task handle in `@State` and cancel in `.onDisappear`:
```swift
@State private var myTask: Task<Void, Never>?

Button {
    myTask = Task {
        await doWork()
        guard !Task.isCancelled else { return }
        // update state only if not cancelled
    }
}
.onDisappear { myTask?.cancel() }
```

---

## 2. Strong `self` Capture in ViewModel Tasks

**Pattern:** `Task { self.someProperty = value }` inside an `ObservableObject` method.

**Problem:** The task retains `self` (the ViewModel) until it completes. If the view that owns the ViewModel is dismissed, the ViewModel stays alive.

**Fix:** Use `[weak self]` in both the task and the `MainActor.run` block:
```swift
Task { [weak self] in
    let result = await doWork()
    await MainActor.run { [weak self] in
        guard let self, !Task.isCancelled else { return }
        self.result = result
    }
}
```

---

## 3. Timer Race Conditions with Async Code

**Pattern:** `Timer.scheduledTimer` started inside `Task.detached` → `MainActor.run`, while `stopTimer()` is called in `onDisappear`.

**Problem:** If the detached task completes after `onDisappear` fires, `startTimer()` creates an orphan timer that never gets invalidated. The timer closure holds strong references to captured state (e.g., arrays of `UIImage`).

**Fix:**
1. Always call `stopTimer()` at the start of `startTimer()` to prevent doubles
2. Add `guard !Task.isCancelled` inside the `MainActor.run` block before calling `startTimer()`

---

## 4. Missing `dismantleUIViewController` / `dismantleUIView`

**Pattern:** `UIViewControllerRepresentable` or `UIViewRepresentable` that creates `AVPlayer`, `UIImageView` with animation, or activates `AVAudioSession`.

**Problem:** Resources created in `makeUIViewController`/`makeUIView` are not cleaned up when SwiftUI removes the view. `AVPlayer` keeps playing, `UIImageView` keeps animating with all frames in memory, `AVAudioSession` stays active.

**Fix:** Always implement the static `dismantle` method:
```swift
static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: ()) {
    vc.player?.pause()
    vc.player = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
}
```

---

## 5. Unbounded In-Memory Caches

**Pattern:** Dictionaries like `[String: UIImage]` that grow with every thumbnail loaded, or singleton arrays that accumulate records with embedded data.

**Problem:** On devices with thousands of photos, decoded thumbnails (200x200x4 bytes each) can consume hundreds of MB. No eviction means memory grows monotonically.

**Fix:**
- Cap the dictionary size and clear when exceeded
- Call `PHCachingImageManager.stopCachingImagesForAllAssets()` in `deinit`
- For singletons, set a `maxRecords` limit and prune oldest entries on insert

---

## 6. DispatchQueue.global Without Cancellation

**Pattern:** `DispatchQueue.global().async { ... DispatchQueue.main.async { self.state = value } }`

**Problem:** GCD work items cannot be cancelled. If the view is dismissed while the background work runs, the closure holds strong references until completion, then writes to state of a dismissed view.

**Fix:** Replace with `Task.detached` which supports cancellation:
```swift
myTask = Task.detached(priority: .userInitiated) {
    let result = await doWork()
    guard !Task.isCancelled else { return }
    await MainActor.run { state = result }
}
```

---

## 7. Polling Tasks Not Cancelled on Error Paths

**Pattern:** `pollingTask?.cancel()` only on the success path after `try await coordinator.convert(job:)`.

**Problem:** On conversion failure, the catch block does not cancel the polling task. The polling task continues running every 500ms indefinitely, doing file I/O and calling `store.save()`.

**Fix:** Always cancel polling tasks in both success and error paths:
```swift
} catch {
    pollingTask?.cancel()  // Don't forget this!
    // handle error...
}
```

---

## 8. AVPlayer Seek Closures

**Pattern:** `player.seek(to:completionHandler:)` where the closure references `player` directly.

**Problem:** AVPlayer retains the completion closure until seek finishes. The closure retains the player, creating a temporary retain cycle. If `cleanupPlayer()` sets `player = nil` during a seek, the player stays alive until the seek infrastructure releases the closure.

**Fix:** Capture player weakly in seek completion handlers:
```swift
player.seek(to: .zero) { [weak player] _ in
    player?.play()
}
```

---

## 9. GIF Frame Loading

**Problem:** Loading all GIF frames into `[UIImage]` at once with no cap. A 100-frame GIF = tens of MB of uncompressed bitmaps.

**Fix:**
- Cap frame count: `let count = min(CGImageSourceGetCount(source), maxFrames)`
- Use `Task.detached` instead of `DispatchQueue.global` for cancellation support
- In `dismantleUIView`, call `imageView.stopAnimating()` and set `animationImages = nil`

---

## 10. Unscoped NotificationCenter Observers

**Pattern:** `.onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in ... }`

**Problem:** Fires for *any* AVPlayerItem globally, not just the owned one.

**Fix:** Filter by the specific player item:
```swift
.onReceive(
    NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
        .filter { notification in
            (notification.object as? AVPlayerItem) === audioPlayer?.currentItem
        }
) { _ in ... }
```

---

---

## 11. Synchronous File I/O on Main Thread

**Pattern:** `FileManager.default.attributesOfItem(atPath:)`, `Data(contentsOf:)`, `UIImage(data:)`, or `CGImageSource` calls executed directly from SwiftUI view body, `onAppear`, or computed properties.

**Problem:** File system calls block the main thread. Image decoding (especially large images) can take 100ms+. `attributesOfItem` does stat() syscalls. When called from SwiftUI computed properties, these run on every re-render.

**Fix:** Move to `@State` properties loaded in `.task` or `Task.detached`:
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

---

## 12. PHAsset.fetchAssets on Main Thread

**Pattern:** `PHAsset.fetchAssets(with:)` + `enumerateObjects` called directly from `onAppear` or view model init.

**Problem:** For libraries with thousands of assets, fetching and enumerating blocks the main thread for hundreds of milliseconds.

**Fix:** Wrap in `DispatchQueue.global(qos: .userInitiated).async` and dispatch results back to main:
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

---

## 13. JSON Serialization in HistoryStore.save()

**Pattern:** `encoder.encode(records)` + `data.write(to:)` called synchronously on main thread, especially from polling tasks that call `store.save()` every 500ms.

**Problem:** With 500 records including thumbnail data, JSON encoding can take 50ms+ and disk writes add more. When called from MainActor.run blocks during progress polling, this freezes UI repeatedly.

**Fix:** Snapshot the data and encode/write on a dedicated serial queue:
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

## 14. ConversionRecord.thumbnail Decoding Every Render

**Pattern:** Computed property `var thumbnail: UIImage? { UIImage(data: thumbnailData) }` called from SwiftUI view body.

**Problem:** `UIImage(data:)` decodes the image data every single time the view re-renders. For a list of records, this means N decodes per scroll frame.

**Fix:** Cache the decoded UIImage with a hash check:
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

---

## Quick Checklist for New Code

- [ ] Every `Task { }` in a view has a stored handle and `.onDisappear { task?.cancel() }`
- [ ] Every `[weak self]` in ViewModel closures
- [ ] Every `UIViewRepresentable` has `dismantleUIView` if it creates resources
- [ ] Every `UIViewControllerRepresentable` has `dismantleUIViewController` if it creates players
- [ ] Every polling/background task is cancelled on both success AND error paths
- [ ] Image caches have size limits
- [ ] `PHCachingImageManager` calls `stopCachingImagesForAllAssets()` in `deinit`
- [ ] GIF loading has frame count caps
- [ ] `DispatchQueue.global` blocks are replaced with cancellable `Task.detached`
- [ ] `AVPlayer.seek` closures use `[weak player]`
- [ ] No `FileManager` calls (`attributesOfItem`, `copyItem`, `removeItem`) from view body or computed properties
- [ ] No `Data(contentsOf:)` or `UIImage(data:)` on main thread for user-selected files
- [ ] `PHAsset.fetchAssets` runs on background thread
- [ ] `HistoryStore.save()` encodes + writes on background queue
- [ ] Computed properties that decode data (thumbnails) are cached
