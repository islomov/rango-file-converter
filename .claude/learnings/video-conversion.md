# Video Conversion Learnings

## FFmpeg-iOS Build (kewlbear/FFmpeg-iOS v0.0.5)

The current FFmpeg-iOS SPM package does **not** include these external codec libraries:
- `libvpx` (VP8/VP9 encoding)
- `libtheora` (Theora encoding)
- `libvorbis` (Vorbis encoding)
- `libmp3lame` (MP3 encoding)
- `libx264`, `libx265`, `libfdk-aac`

## Unsupported Video Output Formats (4)

| Format | Reason | Required Library |
|--------|--------|-----------------|
| **WEBM** | VP8/VP9 encoding not available | `libvpx` |
| **OGV** | Theora + Vorbis encoding not available | `libtheora` + `libvorbis` |
| **SWF** | MP3 audio encoding not available, SWF muxer deprecated | `libmp3lame` |
| **AMV** | AMV encoder/muxer fails in this build | Built-in but non-functional |

These formats are blocked in both `FFmpegConversionEngine.unsupportedFormats` and `VideoDetailView.unsupportedFormats`.

## Supported Video Output Formats (17)

MP4, AVI, MOV, MPG, M4V, MKV, WMV, FLV, MPEG, RM, VOB, TS, ASF, 3GP, MXF, F4V, 3G2

## Format-Specific Codec Requirements

Formats that work only with explicit codec flags (in `formatSpecificArgs`):
- **FLV**: `-c:v flv1 -c:a aac -ar 44100` (uses native AAC, not mp3)
- **RM**: `-f rm -c:v rv20 -c:a real_144`
- **3GP**: `-f 3gp -c:v mpeg4 -c:a aac`
- **3G2**: `-f 3g2 -c:v mpeg4 -c:a aac`

Formats that work with FFmpeg defaults (no explicit codec needed):
MP4, AVI, MOV, MPG, M4V, MKV, WMV, MPEG, VOB, TS, ASF, MXF, F4V

## Potential Fix: FFmpeg-iOS-Lame

The same author offers [FFmpeg-iOS-Lame](https://github.com/kewlbear/FFmpeg-iOS-Lame) (v0.0.6-b) which is a drop-in replacement adding `libmp3lame`. This would fix SWF audio encoding. Same API (`import FFmpegSupport`, `ffmpeg([...])` function).

For WEBM/OGV, a custom FFmpeg build with `--extra-options "--enable-libvpx --enable-libtheora --enable-libvorbis"` would be needed via the kewlbear build tool, but requires cross-compiling those C libraries for iOS first.
