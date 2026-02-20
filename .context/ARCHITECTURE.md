# FormatX — iOS Architecture

> Universal File Format Converter · iOS 17+ · Swift 5.9 · SwiftUI

---

## 1. Product Overview

FormatX converts files across **four media categories** — Image, Video, Audio, and Document — supporting **74 total formats**. The app follows a freemium model with ad-supported free tier and two subscription plans (weekly $19.99 with 3-day trial, yearly $49.99). All processing is performed **on-device**.

---

## 2. Supported Formats (Extracted from App)

### Image — 21 Formats
**Formats:** HEIC · JPEG · PNG · JPG · WEBP · TGA · BMP · JP2 · GIF · TIFF · PBM · PGM · EXR · PAM · PFM · RAS · RGB · SGI · SUNVBM · XWD · YUV

**Features:** Format conversion · Puzzle creation · Cropping · Compression · Rotation · Aspect ratio adjustment

### Video — 21 Formats
**Formats:** MP4 · AMV · AVI · MOV · MPG · M4V · MKV · WMV · FLV · MPEG · RM · VOB · TS · WEBM · ASF · 3GP · SWF · MXF · F4V · 3G2 · OGV

**Features:** Format conversion · Merging · Cropping · Compression · Rotation · Ratio adjustment · Audio extraction · Playback speed · Emoji pack generation

### Audio — 25 Formats
**Formats:** MP3 · WAV · FLAC · M4A · AAC · OGG · AC3 · WMA · AMR · OPUS · AIFF · MP2 · GSM · DTS · AU · CAF · WV · OGA · W64 · VOC · SND · SPX · IRCAM

**Features:** Format conversion · Merge · Crop · Compress · Extract audio · Change playback speed

### Document — 7 Formats
**Formats:** DOC · DOCX · PDF · HTML · ODT · RTF · TXT

**Features:** Format conversion · Document merging

---

## 3. Architecture Pattern

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│          SwiftUI Views · Navigation · Theming           │
├─────────────────────────────────────────────────────────┤
│                     ViewModel Layer                      │
│     ObservableObject · @Published · Combine Pipes       │
├─────────────────────────────────────────────────────────┤
│                      Domain Layer                        │
│     Use Cases · Protocols · Entities (pure Swift)       │
├─────────────────────────────────────────────────────────┤
│                       Data Layer                         │
│  Conversion Engines · File I/O · Cache · StoreKit 2     │
├─────────────────────────────────────────────────────────┤
│                    Infrastructure                        │
│      FFmpegKit · AdMob · Firebase · Crash Reporting     │
└─────────────────────────────────────────────────────────┘
```

**Pattern:** MVVM + Coordinator

- **View** → Declarative SwiftUI. No business logic. Observes ViewModel via `@StateObject`.
- **ViewModel** → `ObservableObject` with `@Published` state. Calls domain use cases, publishes results.
- **Model** → Value types (structs/enums): file metadata, conversion options, format definitions, subscription tiers.
- **Coordinator** → Manages `NavigationStack` paths, deep links, tab routing, and modal paywall presentation.

---

## 4. Module Structure (Swift Packages)

```
FormatX/
├── FormatXApp/                    # App entry point, DI container
│   ├── AppDelegate.swift
│   ├── FormatXApp.swift           # @main, WindowGroup, TabView root
│   ├── DependencyContainer.swift  # Swinject / manual DI registration
│   └── Info.plist
│
├── FormatXUI/                     # Presentation layer
│   ├── Navigation/
│   │   ├── AppCoordinator.swift
│   │   ├── TabRouter.swift
│   │   └── DeepLinkHandler.swift
│   ├── Screens/
│   │   ├── Home/
│   │   │   ├── ConversionHomeView.swift
│   │   │   ├── MediaTypePicker.swift      # Image | Video | Audio | File tabs
│   │   │   └── ConversionHomeViewModel.swift
│   │   ├── Conversion/
│   │   │   ├── FilePickerView.swift
│   │   │   ├── FormatSelectorView.swift
│   │   │   ├── OptionsEditorView.swift
│   │   │   ├── ProcessingView.swift
│   │   │   ├── ResultView.swift
│   │   │   └── ConversionFlowViewModel.swift
│   │   ├── Subscription/
│   │   │   ├── PaywallView.swift          # 3-day trial / weekly / yearly
│   │   │   ├── RestorePurchasesView.swift
│   │   │   └── SubscriptionViewModel.swift
│   │   ├── Profile/
│   │   │   ├── ProfileView.swift          # Avatar, subscription badge, history
│   │   │   └── ProfileViewModel.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       └── SettingsViewModel.swift
│   └── Components/
│       ├── FormatGridCell.swift
│       ├── ConversionProgressRing.swift
│       ├── FileSizeComparisonBar.swift
│       └── SubscriptionBadge.swift
│
├── FormatXDomain/                 # Pure Swift — zero dependencies
│   ├── Entities/
│   │   ├── MediaType.swift                # enum: image, video, audio, file
│   │   ├── FileFormat.swift               # id, displayName, extension, UTType, mimeType
│   │   ├── ConversionJob.swift            # source, target, options, state
│   │   ├── ConversionOptions.swift        # quality, codec, resolution, bitrate, crop, speed
│   │   ├── JobState.swift                 # queued | processing(Double) | completed(URL) | failed(Error)
│   │   └── SubscriptionPlan.swift         # weekly, yearly, trial status
│   ├── Protocols/
│   │   ├── ConversionEngine.swift         # canConvert, convert, progress, cancel
│   │   ├── SubscriptionService.swift
│   │   ├── FileImportService.swift
│   │   └── AnalyticsService.swift
│   └── UseCases/
│       ├── ConvertFileUseCase.swift
│       ├── ValidateConversionPathUseCase.swift
│       ├── EstimateOutputSizeUseCase.swift
│       ├── MergeFilesUseCase.swift
│       └── FetchConversionHistoryUseCase.swift
│
├── FormatXConversion/             # Conversion engines
│   ├── Coordinator/
│   │   └── ConversionCoordinator.swift    # Routes jobs → correct engine
│   ├── Engines/
│   │   ├── ImageConversionEngine.swift    # Core Image + vImage + FFmpeg fallback
│   │   ├── VideoConversionEngine.swift    # AVFoundation + FFmpegKit
│   │   ├── AudioConversionEngine.swift    # AVAudioEngine + FFmpegKit
│   │   └── DocumentConversionEngine.swift # PDFKit + WebKit + NSAttributedString
│   ├── FFmpegBridge/
│   │   ├── FFmpegCommandBuilder.swift     # Type-safe command construction
│   │   ├── FFmpegProgressParser.swift     # Parse progress from stderr
│   │   └── FFmpegSessionManager.swift     # Session lifecycle + cancellation
│   ├── Workers/
│   │   ├── ImageBatchWorker.swift         # TaskGroup-based parallel processing
│   │   ├── VideoMergeWorker.swift         # AVMutableComposition pipeline
│   │   ├── AudioExtractWorker.swift       # Extract audio track from video
│   │   └── WaveformGenerator.swift        # PCM sampling for audio visualization
│   └── Registry/
│       └── FormatRegistry.swift           # All 74 format definitions + conversion graph
│
├── FormatXDesign/                 # Design system
│   ├── Tokens/
│   │   ├── Colors.swift                   # Brand palette, semantic colors
│   │   ├── Typography.swift               # Font styles, sizes
│   │   └── Spacing.swift                  # Layout constants
│   ├── Theme/
│   │   └── FormatXTheme.swift             # Light/dark mode, accent color
│   └── Components/
│       ├── FXButton.swift
│       ├── FXCard.swift
│       ├── FXSegmentedPicker.swift
│       └── FXProgressRing.swift
│
├── FormatXInfra/                  # External services
│   ├── StoreKit/
│   │   ├── StoreKitManager.swift          # StoreKit 2, Transaction.updates
│   │   ├── SubscriptionStatusResolver.swift
│   │   └── ReceiptValidator.swift
│   ├── Ads/
│   │   ├── AdService.swift                # Protocol-based ad abstraction
│   │   ├── AdMobAdapter.swift             # Banner + interstitial implementation
│   │   └── AdFrequencyController.swift    # Interstitial every 3rd conversion
│   ├── Analytics/
│   │   ├── AnalyticsManager.swift
│   │   └── FirebaseAnalyticsAdapter.swift
│   ├── FileSystem/
│   │   ├── SandboxFileManager.swift       # tmp/ cleanup, security-scoped bookmarks
│   │   └── ExportManager.swift            # UIDocumentPickerViewController bridge
│   └── BackgroundTasks/
│       └── BGConversionScheduler.swift    # BGProcessingTaskRequest for long jobs
│
└── FormatXTests/
    ├── Unit/
    │   ├── ConversionCoordinatorTests.swift
    │   ├── FormatRegistryTests.swift
    │   ├── ConversionFlowViewModelTests.swift
    │   └── SubscriptionManagerTests.swift
    ├── Integration/
    │   ├── ImageConversionIntegrationTests.swift
    │   ├── VideoConversionIntegrationTests.swift
    │   ├── AudioConversionIntegrationTests.swift
    │   └── DocumentConversionIntegrationTests.swift
    ├── Snapshot/
    │   ├── PaywallSnapshotTests.swift
    │   └── ConversionFlowSnapshotTests.swift
    └── Fixtures/
        ├── sample.heic
        ├── sample.mp4
        ├── sample.mp3
        └── sample.pdf
```

---

## 5. Core Domain Models

### MediaType

```swift
enum MediaType: String, CaseIterable, Identifiable {
    case image, video, audio, file

    var id: String { rawValue }
    var supportedFormats: [FileFormat] { FormatRegistry.formats(for: self) }
    var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        case .file:  return "doc"
        }
    }
}
```

### FileFormat

```swift
struct FileFormat: Identifiable, Hashable {
    let id: String                    // "com.formatx.heic"
    let displayName: String           // "HEIC"
    let fileExtension: String         // "heic"
    let utType: UTType
    let mimeType: String              // "image/heic"
    let mediaType: MediaType
    let supportedTargets: [String]    // IDs of valid output formats
    let requiresFFmpeg: Bool
}
```

### ConversionJob

```swift
struct ConversionJob: Identifiable {
    let id: UUID
    let sourceURL: URL
    let sourceFormat: FileFormat
    let targetFormat: FileFormat
    let mediaType: MediaType
    let options: ConversionOptions
    var state: JobState
    let createdAt: Date
    var outputURL: URL?
}

enum JobState: Equatable {
    case queued
    case processing(progress: Double)  // 0.0 – 1.0
    case completed(URL)
    case failed(Error)
}
```

### ConversionOptions

```swift
struct ConversionOptions {
    // Image
    var quality: Double = 0.85          // 0.0–1.0
    var maxDimension: CGSize?
    var cropRect: CGRect?
    var rotation: RotationAngle = .none

    // Video
    var videoCodec: VideoCodec = .h264
    var videoBitrate: Int?
    var resolution: VideoResolution = .original
    var playbackSpeed: Double = 1.0     // 0.25–4.0
    var trimRange: CMTimeRange?

    // Audio
    var audioCodec: AudioCodec = .aac
    var audioBitrate: Int = 128_000
    var sampleRate: Double = 44100
    var channels: Int = 2

    // Shared
    var shouldCompress: Bool = false
    var mergeInputs: [URL]?             // For merge operations
}
```

---

## 6. Conversion Engine Protocol

```swift
protocol ConversionEngine: Actor {
    var supportedMediaType: MediaType { get }

    func canConvert(from source: FileFormat, to target: FileFormat) -> Bool
    func convert(job: ConversionJob) async throws -> URL
    func progress(for jobId: UUID) -> AsyncStream<Double>
    func cancel(jobId: UUID)
    func estimateOutputSize(for job: ConversionJob) -> UInt64?
}
```

### Engine Routing (ConversionCoordinator)

```swift
actor ConversionCoordinator {
    private let engines: [MediaType: any ConversionEngine]

    init(
        imageEngine: ImageConversionEngine,
        videoEngine: VideoConversionEngine,
        audioEngine: AudioConversionEngine,
        documentEngine: DocumentConversionEngine
    ) {
        engines = [
            .image: imageEngine,
            .video: videoEngine,
            .audio: audioEngine,
            .file: documentEngine
        ]
    }

    func convert(job: ConversionJob) async throws -> URL {
        guard let engine = engines[job.mediaType] else {
            throw ConversionError.unsupportedMediaType
        }
        guard engine.canConvert(from: job.sourceFormat, to: job.targetFormat) else {
            throw ConversionError.unsupportedConversionPath
        }
        return try await engine.convert(job: job)
    }
}
```

---

## 7. Engine Implementations

### ImageConversionEngine

| Format Group | Framework | Hardware Accel |
|---|---|---|
| HEIC, JPEG, PNG, TIFF, GIF, BMP, WEBP (iOS 17+), JP2 | Core Image (`CIImage` → `CIContext`) | GPU via Metal |
| Crop, rotate, compress, resize | vImage | CPU SIMD |
| TGA, PBM, PGM, EXR, PAM, PFM, RAS, RGB, SGI, SUNVBM, XWD, YUV | FFmpegKit | CPU |

**Key implementation notes:**
- Downsample via `CGImageSource` with `kCGImageSourceThumbnailMaxPixelSize` before processing images > 20MP to prevent OOM
- Batch processing uses `TaskGroup` with max concurrency of 4
- Puzzle feature: slice `CIImage` into grid tiles, export individually

### VideoConversionEngine

| Format Group | Framework | Background Support |
|---|---|---|
| MP4, MOV, M4V | `AVAssetExportSession` | `BGProcessingTaskRequest` |
| AVI, MKV, WMV, FLV, WEBM, TS, VOB, OGV, AMV, ASF, MXF, F4V, RM, MPEG, MPG, 3GP, 3G2, SWF | FFmpegKit | `BGProcessingTaskRequest` |

**Key implementation notes:**
- Merging: `AVMutableComposition` with `insertTimeRange` per asset
- Speed change: `scaleTimeRange` on composition + `AVAudioTimePitchAlgorithm.spectral`
- Audio extraction: `AVAssetReader` with `AVAssetReaderAudioMixOutput` → write via `AVAssetWriter`
- Emoji pack: Extract keyframes at 1s intervals → Core Image filter → export as sticker set

### AudioConversionEngine

| Format Group | Framework |
|---|---|
| AAC, M4A, WAV, AIFF, CAF, AU | `AVAudioEngine` + `AVAudioConverter` |
| MP3, FLAC, OGG, OPUS, AC3, WMA, AMR, DTS, WV, OGA, W64, VOC, SND, SPX, GSM, IRCAM | FFmpegKit |

**Key implementation notes:**
- Waveform visualization: Sample `AVAudioPCMBuffer` at display resolution
- Speed change: `AVAudioUnitTimePitch` for pitch-preserving speed adjustment
- Merge: Concatenate PCM buffers with optional crossfade via custom mixing

### DocumentConversionEngine

| Conversion Path | Framework |
|---|---|
| Any → PDF | `WKWebView` offscreen render → `PDFDocument` |
| PDF manipulation | `PDFKit` (`PDFDocument`, `PDFPage`) |
| RTF ↔ anything | `NSAttributedString` with `.rtf` document type |
| TXT | `String` with encoding detection |
| DOC/DOCX read | Basic text extraction; full fidelity via optional server API |
| ODT | Unzip → parse `content.xml` → `NSAttributedString` |

---

## 8. Navigation & Screen Flow

### Tab Structure

```
TabView
├── Home (ConversionHomeView)
│   └── Segmented Picker: [Image] [Video] [Audio] [File]
│       └── Conversion Flow (NavigationStack)
│           ├── FilePickerView
│           ├── FormatSelectorView
│           ├── OptionsEditorView
│           ├── ProcessingView
│           └── ResultView
├── Profile (ProfileView)
│   ├── Avatar + "Jenny" + Subscription Badge
│   └── Conversion History List
└── Premium (SubscriptionView)
    └── PaywallView (also shown as modal for free users)
```

### Conversion Flow State Machine

```
[idle] ──select file──▶ [fileSelected]
   ──choose format──▶ [formatChosen]
   ──configure──▶ [optionsSet]
   ──start──▶ [processing] ──success──▶ [completed]
                  │                          │
                  ├──cancel──▶ [cancelled]   ├──share──▶ [idle]
                  └──error──▶ [failed]       └──save──▶ [idle]
```

---

## 9. Subscription & Monetization

### Plans (StoreKit 2)

| Plan | Product ID | Price | Trial | Renewal |
|---|---|---|---|---|
| Weekly | `com.formatx.weekly` | $19.99/week | 3-day free | Auto-renewing |
| Yearly | `com.formatx.yearly` | $49.99/year | None | Auto-renewing |

### Entitlement Logic

```swift
actor SubscriptionManager {
    @Published private(set) var status: SubscriptionStatus = .free

    enum SubscriptionStatus {
        case free
        case trial(expiresAt: Date)
        case subscribed(plan: Plan, expiresAt: Date)
        case expired
    }

    func observeTransactions() {
        // StoreKit 2: Transaction.updates async sequence
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await updateStatus(from: transaction)
            await transaction.finish()
        }
    }
}
```

### Free vs Subscribed

| Feature | Free | Subscribed |
|---|---|---|
| Conversions | Limited (3/day) | Unlimited |
| Ads | Banner + interstitial every 3rd conversion | None |
| Format access | All 74 formats | All 74 formats |
| Batch processing | No | Yes |
| Background conversion | No | Yes |

---

## 10. Data Flow

```
User Action
    │
    ▼
┌──────────────┐    @Published     ┌────────────┐
│   SwiftUI    │◄──────────────────│  ViewModel │
│    View      │                   │            │
└──────────────┘                   └─────┬──────┘
                                         │ async
                                         ▼
                                   ┌────────────┐
                                   │  Use Case  │
                                   └─────┬──────┘
                                         │
                                         ▼
                                   ┌────────────┐     ┌───────────┐
                                   │ Conversion │────▶│  FFmpeg   │
                                   │ Coordinator│     │  / Native │
                                   └─────┬──────┘     └───────────┘
                                         │
                                         ▼
                                   ┌────────────┐
                                   │  Output    │
                                   │  File URL  │
                                   └────────────┘
```

### State Objects

| Object | Scope | Persistence |
|---|---|---|
| `AppState` | `@EnvironmentObject` (global) | `UserDefaults` + Keychain |
| `ConversionFlowViewModel` | `@StateObject` (per-flow) | None (transient) |
| `SubscriptionManager` | Singleton Actor | StoreKit 2 + Keychain |
| `ConversionHistory` | Global | SwiftData |
| `FormatRegistry` | Static | Compiled |

---

## 11. Format Conversion Matrix

### Native vs FFmpeg Dependency

```
         ┌─────────────────────────────────────────┐
         │            74 Total Formats              │
         ├────────────────────┬────────────────────┤
         │   Native iOS (22)  │  FFmpeg Required   │
         │                    │       (52)         │
         ├────────────────────┼────────────────────┤
  Image  │ HEIC JPEG PNG JPG  │ TGA PBM PGM EXR   │
         │ WEBP BMP JP2 GIF   │ PAM PFM RAS RGB   │
         │ TIFF               │ SGI SUNVBM XWD YUV│
         ├────────────────────┼────────────────────┤
  Video  │ MP4 MOV M4V        │ AVI MKV WMV FLV   │
         │                    │ WEBM TS VOB OGV    │
         │                    │ AMV ASF MXF F4V RM │
         │                    │ MPEG MPG 3GP 3G2   │
         │                    │ SWF                │
         ├────────────────────┼────────────────────┤
  Audio  │ AAC M4A WAV AIFF   │ MP3 FLAC OGG OPUS │
         │ CAF AU             │ AC3 WMA AMR DTS    │
         │                    │ WV OGA W64 VOC SND │
         │                    │ SPX GSM MP2 IRCAM  │
         ├────────────────────┼────────────────────┤
  File   │ PDF TXT RTF HTML   │ DOC DOCX ODT      │
         └────────────────────┴────────────────────┘
```

---

## 12. Dependencies

| Dependency | Purpose | Integration | License |
|---|---|---|---|
| **FFmpegKit** (Full GPL) | Non-native format conversion | SPM / XCFramework | LGPL 3.0 |
| **StoreKit 2** | Subscription management | Native (iOS 15+) | Apple |
| **SwiftData** | Conversion history | Native (iOS 17+) | Apple |
| **Google AdMob** | Ad mediation (free tier) | SPM | Proprietary |
| **Firebase** | Analytics + Crashlytics | SPM | Apache 2.0 |
| **Kingfisher** | Image caching for previews | SPM | MIT |
| **swift-algorithms** | Batch processing utilities | SPM | Apache 2.0 |

---

## 13. Performance Targets

| Metric | Target | Strategy |
|---|---|---|
| Image conversion (< 20MP) | < 2s | Core Image GPU pipeline, `CIContext` with `MTLDevice` |
| Video conversion (1min @ 1080p) | < 30s | Hardware `AVAssetExportSession`, VideoToolbox |
| Audio conversion (5min track) | < 5s | `AVAudioEngine` real-time pipeline |
| Document conversion | < 3s | WebKit offscreen with shared `WKWebView` pool |
| Cold launch | < 1.5s | Lazy module loading, deferred FFmpeg init |
| Memory ceiling | < 200MB | Downsampling, streaming buffers, `autoreleasepool` |

---

## 14. Security

- **On-device only** — no user files uploaded to any server
- **Temp files** — stored in `tmp/`, cleaned on app termination and via `BGAppRefreshTaskRequest`
- **Security-scoped bookmarks** — for files imported from Files app
- **Keychain** — subscription receipt and entitlement tokens
- **App Transport Security** — enforced; only AdMob/Firebase endpoints whitelisted

---

## 15. Background Processing

```swift
// Register in AppDelegate
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.formatx.conversion",
    using: nil
) { task in
    handleBackgroundConversion(task as! BGProcessingTask)
}

// Schedule when conversion starts and app may background
func scheduleBackgroundConversion(job: ConversionJob) {
    let request = BGProcessingTaskRequest(identifier: "com.formatx.conversion")
    request.requiresExternalPower = false
    request.requiresNetworkConnectivity = false
    try? BGTaskScheduler.shared.submit(request)
}
```

Local notification sent on completion via `UNUserNotificationCenter`.

---

## 16. Testing Strategy

| Type | Coverage | Framework | Focus |
|---|---|---|---|
| Unit | 80%+ | XCTest | ViewModels, use cases, format registry, option validation |
| Integration | Key paths | XCTest + fixture files | End-to-end conversion per engine |
| Snapshot | All screens | swift-snapshot-testing | Device sizes, dark/light mode |
| Performance | Critical paths | `XCTest.measure {}` | Conversion benchmarks, memory profiling |
| UI | Happy paths | XCUITest | Full conversion flow, paywall, tabs |

---

## 17. CI/CD

- **CI:** GitHub Actions with self-hosted macOS runners (Xcode 16+)
- **Signing:** Fastlane Match with App Store Connect API key
- **Environments:** Debug (StoreKit sandbox) → Staging (TestFlight) → Production (App Store)
- **Feature flags:** Firebase Remote Config for phased format rollout
- **Crash monitoring:** Firebase Crashlytics with automatic dSYM upload
- **Minimum target:** iOS 17.0

---

## 18. Future Considerations

- **Shortcuts integration** — `AppIntents` for Siri/Shortcuts-driven conversion
- **Share Extension** — convert directly from share sheet without opening app
- **iCloud sync** — conversion history and preferences across devices
- **Widget** — recent conversions + quick-start conversion from home screen
- **visionOS** — spatial UI for drag-and-drop conversion (SwiftUI portability)
- **Server-side fallback** — optional cloud conversion for complex DOCX/DOC fidelity
