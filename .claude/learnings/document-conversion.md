# Document Conversion Architecture

## Overview
Document format conversion uses CloudConvert REST API v2 (cloud-based).
PDF tools (merge, split, reorder, protect) use Apple's PDFKit (on-device).

## CloudConvert Integration
- API client: `rangofileconverter/Networking/CloudConvertClient.swift` (pure URLSession, no Alamofire)
- Models: `rangofileconverter/Networking/CloudConvertModels.swift`
- API key: `rangofileconverter/Networking/CloudConvertAPIKey.swift` (Keychain + plist fallback)
- Engine: `rangofileconverter/Engine/CloudConvertEngine.swift` (ConversionEngine protocol)

## API Flow
1. POST `/v2/jobs` with import/upload + convert + export/url tasks
2. Upload file via multipart form POST to the URL from import task's `result.form`
3. Poll GET `/v2/jobs/{id}` every 2s until status is `finished` or `error`
4. Download result from export task's `result.files[0].url`

## Key Gotchas
- The official CloudConvert Swift SDK is **archived since 2020** — don't use it
- Form parameters from the upload task MUST come before the `file` field in multipart form
- Parameter names/count can vary — never hardcode, always use values from response
- CloudConvert API returns 401 for invalid keys, 429 for rate limits
- Free tier: 10 conversions/day, 25MB file limit

## PDF Tools
- `rangofileconverter/Services/PDFToolsService.swift`
- Merge: PDFDocument page insertion
- Split: extract pages by 0-indexed array
- Reorder: new PDFDocument with pages in specified order
- Protect: CGContext with kCGPDFContextUserPassword/kCGPDFContextOwnerPassword
- PDFKit's PDFDocument.write() does NOT support encryption — must use CGContext approach

## Settings
- API key managed in SettingsView via SecureField + CloudConvertAPIKey.setAPIKey()
- Config plist (CloudConvertConfig.plist) is in .gitignore for dev use
