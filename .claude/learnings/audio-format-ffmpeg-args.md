# Audio Formats — FFmpeg Codec Availability

The kewlbear/FFmpeg-iOS v0.0.5 build does NOT include these external audio libraries:
- `libopencore_amrnb` (needed for AMR encoding)
- `libspeex` (needed for SPX/Speex encoding)
- `libgsm` (needed for GSM encoding)
- `libopus` (but the native experimental `opus` encoder works with `-strict -2`)

## Working Formats (with explicit args)

| Format | Required Args | Notes |
|--------|--------------|-------|
| OPUS | `-strict -2 -c:a opus -ar 48000` | Native encoder is experimental |
| DTS | `-strict -2 -f dts -c:a dca` | DCA encoder is experimental |
| SND | `-f au` | FFmpeg doesn't recognize `.snd` extension as AU |

## Unsupported Formats (no encoder in build)

- **AMR** — needs `libopencore_amrnb`
- **SPX** — needs `libspeex`
- **GSM** — needs `libgsm`

All three are blocked in `FFmpegConversionEngine.unsupportedFormats` and filtered from format pickers in `AudioDetailView` and `ExtractAudioDetailView`.
