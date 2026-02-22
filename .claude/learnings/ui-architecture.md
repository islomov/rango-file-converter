# UI Architecture — Learnings

## Image Tab Structure

### Two Sub-Tabs via Segmented Picker
- `ImageConverterView` uses a segmented `Picker` to toggle between **Tools** and **History** tabs
- `ImageTab` enum: `.tools`, `.history`
- Tools tab shows a 2-column `LazyVGrid` of tool cards (Convert, Compress, Rotate, Resize, Crop, Stitch, Make GIF)
- History tab shows conversion records via `HistoryRowView` in a `List`
- Only "Convert" is active; others show "Coming Soon" alert with a badge

### Tool Card Pattern
- `ImageTool` struct: `id`, `title`, `icon` (SF Symbol), `isAvailable` flag
- Cards show `.secondary` foreground when unavailable
- "Soon" capsule badge in top-right corner for unavailable tools

## AssetPicker — Custom Photo Grid

### Why Not PhotosPicker
- Apple's `PhotosPicker` is a system modal with no customization
- Custom `AssetPickerView` gives full control over the UI and flow
- Pushed as a NavigationStack destination (full screen), not a sheet

### PHAsset-Based Gallery Grid
- `PhotoLibraryViewModel` (`@Observable`) manages all photo library interaction
- Uses `PHCachingImageManager` for efficient thumbnail loading
- `PHAsset.fetchAssets(with:)` + `PHFetchOptions` sorted by `creationDate` descending
- 3-column `LazyVGrid` with square cells (`aspectRatio(1, contentMode: .fit)`)
- Thumbnails loaded lazily via `.onAppear` on placeholder cells
- Full-resolution image loaded via `requestImageDataAndOrientation(for:options:)` — async wrapper with `withCheckedContinuation`

### Authorization Handling
- `PHPhotoLibrary.requestAuthorization(for: .readWrite)` on first appear
- States handled: `.authorized`, `.limited`, `.denied`, `.restricted`, `.notDetermined`
- Denied state shows "Open Settings" button linking to `UIApplication.openSettingsURLString`
- Requires `NSPhotoLibraryUsageDescription` in Info.plist (added via `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` in pbxproj build settings)

### Source Switching
- Bottom bar with "Gallery" and "Files" buttons
- Gallery = custom PHAsset grid (default)
- Files = placeholder view with "Open File Browser" button triggering `.fileImporter`
- File import handles security-scoped URLs: copy to temp dir immediately

### UTI to File Extension Mapping
When loading full images from PHAsset, the UTI string needs mapping:
- `public.jpeg` → `jpg`
- `public.png` → `png`
- `public.heic` / `public.heif` → `heic`
- `com.compuserve.gif` → `gif`
- `public.tiff` → `tiff`
- `com.microsoft.bmp` → `bmp`
- `org.webmproject.webp` → `webp`
- Default fallback → `jpg`

## Navigation Flow

### Current Flow (Image Tab)
```
ImageConverterView (Tools tab)
  → tap tool card (e.g., "Convert")
  → navigationDestination → AssetPickerView
      → user picks photo from gallery grid OR file from file browser
      → callback: (UIImage, fileName, tempURL)
      → viewModel.selectImage() sets state + triggers navigation
  → navigationDestination → ImageDetailView
      → user picks target format + taps Convert
      → viewModel.convert(to:) → ConversionCoordinator
      → dismiss back to ImageConverterView
      → history updated with result
```

### Key State Management
- `ImageConverterViewModel` is `@Observable` (iOS 17+), not `ObservableObject`
- `showAssetPicker` (Bool) → triggers AssetPicker navigation
- `showConversionDetail` (Bool) → triggers ImageDetailView navigation
- Both use `navigationDestination(isPresented:)` on the NavigationStack
- ViewModel's `selectImage()` method centralizes the image selection from any source

## Xcode Project Patterns

### Auto-Generated Info.plist
- Project uses `GENERATE_INFOPLIST_FILE = YES`
- Privacy keys added via `INFOPLIST_KEY_*` build settings in pbxproj
- No standalone Info.plist file exists
- Must add keys to **both** Debug and Release configurations

### File Discovery
- Project doesn't list individual Swift files in build phases
- Xcode auto-discovers files in the project directory
- New `.swift` files are picked up automatically without pbxproj edits
