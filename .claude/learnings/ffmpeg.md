# FFmpeg Gotchas (kewlbear/FFmpeg-iOS v0.0.5)

## General
- Always pass `-y` to overwrite without prompting (hangs on stdin otherwise)
- FFmpeg uses global C state — serialize all calls via `FFmpegWrapper` actor (one conversion at a time)
- `-filter_complex` and `-vf` cannot be used together

## Missing Codecs
Not included: `libvpx`, `libtheora`, `libvorbis`, `libmp3lame`, `libx264`, `libx265`, `libfdk-aac`, `libwebp`, HEIF muxer

## Unsupported Output Formats
- **WEBM** (needs libvpx), **OGV** (needs libtheora+libvorbis), **SWF** (needs libmp3lame, deprecated), **AMV** (encoder broken)
- Blocked in both `FFmpegConversionEngine.unsupportedFormats` and `VideoDetailView.unsupportedFormats`

## Format-Specific Flags
| Format | Required Args |
|--------|--------------|
| JPEG | `-c:v mjpeg` |
| TGA | `-c:v targa` |
| SUNVBM | Use `.ras` extension + `-c:v sunrast` (no sun muxer) |
| YUV | `-c:v rawvideo -pix_fmt yuv420p` |
| JP2 | `-c:v jpeg2000` |
| SGI/RGB | `-c:v sgi` |
| FLV | `-c:v flv1 -c:a aac -ar 44100` |
| RM | `-f rm -c:v rv20 -c:a ac3` (real_144 encoder not available) |
| VOB | `-f vob -c:v mpeg2video -c:a ac3` |
| TS | `-f mpegts -c:v mpeg2video -c:a mp2` |
| ASF | `-f asf -c:v wmv2 -c:a wmav2` |
| 3GP | `-f 3gp -c:v mpeg4 -c:a aac -ar 44100` |
| MXF | `-f mxf -c:v mpeg2video -c:a pcm_s16le` |
| F4V | `-f f4v -c:v mpeg4 -c:a aac` |
| 3G2 | `-f 3g2 -c:v mpeg4 -c:a aac -ar 44100` |
| Multi-frame→still | `-frames:v 1 -update 1` (except GIF output) |

## Native Engines (bypass FFmpeg)
- **HEIC**: `CGImageDestinationCreateWithData` + `UTType.heic` — use data-based API, not URL-based
- **WebP**: iOS only supports decoding. Encoding uses `awxkee/webp.swift` package. Quality param is `Float`, not `CGFloat`
- **MP3**: iOS cannot encode MP3 natively. Uses `Phisto/swift-lame` (LAME C library via SPM). `NativeAudioEngine` reads audio via `AVAudioFile`, encodes with LAME. MP3 is in FFmpegConversionEngine's `nativeOnlyFormats` to prevent FFmpeg from claiming it.
- **M4A**: `NativeAudioEngine` uses `AVAssetExportSession` with `AVAssetExportPresetAppleM4A` — handles both audio and video inputs (strips video automatically). Declines speed-change jobs via `canHandle(job:)` so FFmpeg handles those.

## GIF Output (single-pass palette)
Filter: `[0:v] fps=N,scale=W:-1:flags=lanczos,split [a][b]; [a] palettegen [p]; [b][p] paletteuse`
- GIF branch in `buildFFmpegArgs` returns early, skipping normal `-vf` chain
- Add `-loop 0` for infinite loop
- GIF is `mediaType: .image` in FormatRegistry but `mediaCategory: "video"` in ConversionRecord

## Progress Tracking
- No callbacks available — use `-progress <absolute_filepath>` + poll file every 500ms
- Probe duration with `AVAsset.load(.duration)` (no ffprobe)
- Parse last `out_time_us` by reverse-iterating lines; `out_time_us` can be negative early — check `> 0`
- Cap at 0.99 during polling; set 1.0 only after FFmpeg completes
- Speed change: denominator = `totalDurationUs / speed`
- Time clip (`-c copy`) is too fast for progress — use indeterminate spinner

## Stream-Copy Clipping (audio & video)
```
-ss <start> -to <end> -c copy
```
Nearly instant, preserves format. Used by both video time clip and audio crop.

## Document Conversion
- Uses CloudConvert REST API v2, NOT the archived Swift SDK
- Custom client: `Networking/CloudConvertClient.swift` (pure URLSession)
- Multipart upload: form params MUST come before `file` field
- Free tier: 10 conversions/day, 25MB limit
- PDF tools (merge/split/reorder/protect) use PDFKit on-device
- `PDFDocument.write()` does NOT support encryption — use `CGContext` with `kCGPDFContextUserPassword`/`kCGPDFContextOwnerPassword`
