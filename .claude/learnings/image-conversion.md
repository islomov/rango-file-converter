# Image Conversion — Learnings

## FFmpeg-iOS Package (kewlbear/FFmpeg-iOS)

### What It Is
- Pre-built FFmpeg xcframeworks for iOS via SPM
- Exposes `ffmpeg(_ args: [String]) -> Int` function from `FFmpegSupport` module
- FFmpeg version N-109970 (based on ~6.0, built March 2023)

### Thread Safety
- FFmpeg uses **global state** — not thread-safe
- Must serialize all calls via an `actor` (our `FFmpegWrapper`)
- The `ffmpeg()` function is synchronous and blocks until done

### Included Encoders (Image)
Working: `mjpeg`, `png`, `bmp`, `tiff`, `gif`, `targa`, `jpeg2000`, `exr`, `pbm`, `pgm`, `pam`, `pfm`, `sgi`, `xwd`, `sunrast`, `rawvideo`

**NOT included:** `libwebp` (WebP), `libx265`/HEIF muxer (HEIC)

### Format-Specific Gotchas

| Issue | Solution |
|---|---|
| Multi-frame input (GIF/APNG) to still image fails with `image2` muxer error | Add `-frames:v 1 -update 1` for all still image outputs except GIF |
| JPEG output needs explicit codec | Add `-c:v mjpeg` — FFmpeg doesn't always auto-detect from `.jpeg` extension |
| TGA output needs codec name `targa` not `tga` | `-c:v targa` |
| SUNVBM: FFmpeg has no `sun` muxer, and doesn't recognize `.sunvbm` extension | Use `.ras` file extension + `-c:v sunrast` — the `image2` muxer recognizes `.ras` natively |
| YUV raw format needs explicit pixel format | `-c:v rawvideo -pix_fmt yuv420p` |
| JP2 needs explicit codec | `-c:v jpeg2000` |
| SGI/RGB share the same codec | `-c:v sgi` for both |

### The `-y` Flag
Always pass `-y` to overwrite output files without prompting. FFmpeg will hang waiting for stdin otherwise.

## Native iOS Image APIs

### HEIC Encoding
- Works via `CGImageDestinationCreateWithData` + `UTType.heic`
- Available since **iOS 11**
- Supports lossy compression via `kCGImageDestinationLossyCompressionQuality`
- Use data-based API (`CFMutableData`), not URL-based, for reliability

### WebP Encoding
- **iOS does NOT support WebP encoding** via `CGImageDestination`
- `CGImageDestinationCreateWithData` returns `nil` with error: `unsupported output file format 'org.webmproject.webp'`
- iOS only supports WebP **decoding** (read) since iOS 14
- Solution: Use `webp.swift` package (awxkee/webp.swift) which bundles libwebp
- API: `WebPEncoder().encode(uiImage, config: .preset(.picture, quality: Float(quality)))`
- Note: quality parameter is `Float`, not `CGFloat`

### CGImage Transformations
- **Crop:** `cgImage.cropping(to: CGRect)` — returns optional
- **Scale:** Create `CGContext` at target size, draw image into it, call `makeImage()`
- **Load any format:** `CGImageSourceCreateWithURL` reads anything iOS understands (JPEG, PNG, HEIC, WebP, TIFF, BMP, GIF, etc.)

## Architecture: ConversionCoordinator Pattern

```
ViewModel
  → ConversionCoordinator (routes to first engine that canConvert)
    → NativeImageEngine (HEIC via CGImageDestination, WebP via webp.swift)
    → FFmpegConversionEngine (19 other image formats + all video + all audio)
```

- Engines implement `ConversionEngine` protocol with `canConvert(from:to:)` and `convert(job:)`
- Coordinator iterates engines in order — first match wins
- NativeImageEngine is checked first so HEIC/WEBP never hit FFmpeg

## File Handling

### Security-Scoped URLs
- Files from `fileImporter` are security-scoped — access expires after the callback
- Must **copy to temp directory** immediately during import
- FFmpeg cannot access the original URL later

### PhotosPicker Images
- Arrive as `Data` via `PhotosPickerItem.loadTransferable(type: Data.self)`
- Must write to a temp file (e.g., `photo_XXXXXXXX.jpg`) before FFmpeg can process
- The temp file extension matters — FFmpeg uses it to detect input format

## Format Coverage Summary

| Formats | Count | Engine | Status |
|---|---|---|---|
| Image total | 21 | Mixed | 21/21 working |
| → FFmpeg path | 19 | FFmpegConversionEngine | All working |
| → Native path | 2 (HEIC, WEBP) | NativeImageEngine | All working |
| Video | 21 | FFmpegConversionEngine | Not yet tested |
| Audio | 23 | FFmpegConversionEngine | Not yet tested |
| Document | 7 | None (FFmpeg can't do docs) | Not implemented |

## Dependencies

| Package | Purpose | License |
|---|---|---|
| kewlbear/FFmpeg-iOS | FFmpeg xcframeworks + CLI wrapper | LGPL 2.1+ |
| awxkee/webp.swift | WebP encoding via libwebp | MIT |
