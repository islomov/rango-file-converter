# Fire-and-Forget Conversion Tasks & Unblocking UI

## Problem
Conversion tasks (image/video/audio) were originally `async` methods called from view closures with `Task { await viewModel.convert(...) }`. This caused:
1. Views blocked until conversion finished (user couldn't navigate freely)
2. No way to cancel running tasks from history
3. No parallel task support (one conversion at a time per tab)

## Architecture

### ConversionTaskManager (Singleton)
**File:** `rangofileconverter/Shared/ConversionTaskManager.swift`

- Single global singleton keyed by `ConversionRecord.id` (UUID)
- Stores `Task<Void, Never>` handles for running conversions
- Thread-safe via `NSLock`
- Three methods: `register(id:task:)`, `cancel(id:)`, `remove(id:)`
- NOT per-tab — one global manager is simpler since record IDs are globally unique

### ViewModel Pattern (Fire-and-Forget)

**Before (async, blocking):**
```swift
func convert(to format: FormatDefinition) async {
    isConverting = true
    let record = ConversionRecord(...)
    store.add(record)
    let result = try await coordinator.convert(job: job)
    // ... update record ...
    isConverting = false
}
```

**After (sync, fire-and-forget):**
```swift
func convert(inputURL: URL, fileName: String, to format: FormatDefinition) {
    let record = ConversionRecord(..., status: .converting)
    store.add(record)              // Sync — record appears in history immediately

    let task = Task.detached { [weak self] in
        guard let self else { return }
        defer { self.taskManager.remove(id: record.id) }  // Cleanup on completion

        guard !Task.isCancelled else {
            await MainActor.run { self.failRecord(record, error: "Cancelled") }
            return
        }
        // ... do conversion work ...
        // Update record on MainActor when done
    }

    taskManager.register(id: record.id, task: task)  // Enable cancellation
}
```

**Key changes:**
1. Method is **synchronous** (no `async`)
2. **Pass all needed data as parameters** — don't read from `self` properties inside `Task.detached` (race condition if user starts another conversion)
3. `ConversionRecord` created with `.converting` status and added to store **before** spawning task
4. `Task.detached` used (not `Task {}`) to avoid inheriting actor context
5. `defer { taskManager.remove(id:) }` ensures cleanup
6. `Task.isCancelled` checks at key points for cooperative cancellation
7. Remove `isConverting` property from ViewModel — no longer needed

### View Callback Pattern

**Before (wrapped in Task + DispatchQueue):**
```swift
) { format in
    Task { await viewModel.convert(to: format) }
    DispatchQueue.main.async {
        viewModel.showConversionDetail = false
        showVideoPicker = false
        selectedTab = .history
    }
}
```

**After (direct, synchronous):**
```swift
) { format in
    viewModel.convert(inputURL: fileURL, fileName: name, thumbnail: thumb, to: format)
    viewModel.showConversionDetail = false
    showVideoPicker = false
    selectedTab = .history
}
```

No `Task {}` wrapper needed since the method is sync. No `DispatchQueue.main.async` needed since we're already on main thread. Navigation to history tab happens immediately.

### Detail View Changes

Detail views (ImageDetailView, AudioDetailView) that had `onConvert: (FormatDefinition) async -> Void` changed to `onConvert: (FormatDefinition) -> Void`. Removed:
- `isConverting` state
- `ProgressView` in button
- `.disabled(isConverting)` modifier
- `convertTask` handle

The button just calls `onConvert(targetFormat)` and the parent view handles navigation.

### Wiring Up Cancellation

**HistoryResultSheet** (Cancel button):
```swift
Button(role: .destructive) {
    ConversionTaskManager.shared.cancel(id: record.id)  // Actually cancels the Task
    record.status = .failed
    record.errorMessage = "Cancelled by user"
    historyStore.save()
    dismiss()
}
```

**HistoryStore.remove()** (Delete from history):
```swift
func remove(_ record: ConversionRecord) {
    ConversionTaskManager.shared.cancel(id: record.id)  // Cancel if still running
    // ... existing cleanup ...
}
```

## Method Signature Changes

When converting from async to fire-and-forget, methods that previously read from `self` properties (like `selectedVideoURL`, `selectedFileName`) must take those as **explicit parameters** instead. This prevents race conditions when multiple conversions run in parallel.

| ViewModel | Method | Old Signature | New Signature |
|-----------|--------|--------------|---------------|
| Image | `convert` | `(to: FormatDefinition) async` | `(inputURL: URL, fileName: String, to: FormatDefinition)` |
| Video | `convert` | `(to: FormatDefinition) async` | `(inputURL: URL, fileName: String, thumbnail: UIImage?, to: FormatDefinition)` |
| Video | `extractAudio` | `(to: FormatDefinition) async` | `(inputURL: URL, fileName: String, thumbnail: UIImage?, to: FormatDefinition)` |
| Video | `convertToGif` | `(fps: Int, width: Int) async` | `(inputURL: URL, fileName: String, thumbnail: UIImage?, fps: Int, width: Int)` |
| Video | `convertRatio` | `(aspectRatio:...) async` | `(inputURL: URL, fileName: String, thumbnail: UIImage?, aspectRatio:...)` |
| Audio | `convert` | `(to: FormatDefinition) async` | `(inputURL: URL, fileName: String, to: FormatDefinition)` |

Methods that already took all params as arguments (e.g. `compressVideo`, `changeSpeed`, `clipVideo`, `mergeVideos`) just removed `async`.

## Progress Tracking

Progress tracking (FFmpeg progress file polling) runs as a **nested Task inside the outer Task.detached**. When the outer task is cancelled, `Task.isCancelled` propagates and the polling loop exits. The polling task is also explicitly cancelled after conversion completes.

## Checklist for Adding a New Feature Tool

1. Add ViewModel method as **synchronous** (not async)
2. Create `ConversionRecord` with `.converting` status, add to `store`
3. Spawn `Task.detached` with `[weak self]` capture
4. Add `defer { self.taskManager.remove(id: record.id) }`
5. Add `Task.isCancelled` checks before expensive operations
6. Register task with `taskManager.register(id:task:)`
7. In the view callback: call ViewModel method directly, dismiss views, switch to `.history` tab
8. Pass all needed data as parameters — never read from ViewModel's `@Published` properties inside the task
