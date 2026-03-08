# Localization & Live Language Switching

## What works: `.environment(\.locale, ...)`
- Use `.environment(\.locale, Locale(identifier: langCode))` on the root view
- SwiftUI automatically re-renders all `Text()` views using `LocalizedStringKey` when the locale changes
- No view tree destruction — navigation state, scroll position preserved
- Works with `.xcstrings` (String Catalogs) out of the box

## What doesn't work: Bundle swizzling
- `object_setClass(Bundle.main, OverrideBundle.self)` to override `localizedString(forKey:value:table:)` does NOT work reliably with `.xcstrings` String Catalogs
- Using `.id(refreshID)` to force re-render destroys the entire view tree, resetting navigation to the home tab — bad UX

## Key gotchas
- `Text("literal")` auto-converts to `LocalizedStringKey` and responds to `.locale` changes
- `Text(stringVariable)` calls the `StringProtocol` initializer — does NOT localize. Use `Text(LocalizedStringKey(stringVariable))` instead
- No `NSLocalizedString` calls exist in this codebase — everything is pure SwiftUI `Text()`
- The app has 21+ places using `Text(LocalizedStringKey(dynamicValue))` for enum rawValues etc.

## Implementation (PR #120)
- `LanguageManager` stores `currentLanguageCode` in UserDefaults (`"app_language"`)
- Exposes `var locale: Locale` computed from the code
- Root view applies `.environment(\.locale, languageManager.locale)`
- `setLanguage(_:)` just updates `@Published currentLanguageCode` — SwiftUI handles the rest
