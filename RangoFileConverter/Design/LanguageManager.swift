import SwiftUI
import Combine

// MARK: - Language Manager

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguageCode: String {
        didSet {
            UserDefaults.standard.set(currentLanguageCode, forKey: "app_language")
            UserDefaults.standard.set([currentLanguageCode], forKey: "AppleLanguages")
        }
    }

    /// The locale derived from the current language code — pass to `.environment(\.locale, ...)`.
    var locale: Locale {
        Locale(identifier: currentLanguageCode)
    }

    /// Layout direction for the current language (RTL for Arabic, Hebrew).
    var layoutDirection: LayoutDirection {
        Locale.characterDirection(forLanguage: currentLanguageCode) == .rightToLeft
            ? .rightToLeft : .leftToRight
    }

    static let supportedLanguages: [AppLanguage] = [
        AppLanguage(code: "en", nativeName: "English", englishName: "English"),
        AppLanguage(code: "ar", nativeName: "العربية", englishName: "Arabic"),
        AppLanguage(code: "bn", nativeName: "বাংলা", englishName: "Bengali"),
        AppLanguage(code: "cs", nativeName: "Čeština", englishName: "Czech"),
        AppLanguage(code: "da", nativeName: "Dansk", englishName: "Danish"),
        AppLanguage(code: "de", nativeName: "Deutsch", englishName: "German"),
        AppLanguage(code: "el", nativeName: "Ελληνικά", englishName: "Greek"),
        AppLanguage(code: "es", nativeName: "Español", englishName: "Spanish"),
        AppLanguage(code: "fi", nativeName: "Suomi", englishName: "Finnish"),
        AppLanguage(code: "fr", nativeName: "Français", englishName: "French"),
        AppLanguage(code: "he", nativeName: "עברית", englishName: "Hebrew"),
        AppLanguage(code: "hi", nativeName: "हिन्दी", englishName: "Hindi"),
        AppLanguage(code: "hu", nativeName: "Magyar", englishName: "Hungarian"),
        AppLanguage(code: "id", nativeName: "Bahasa Indonesia", englishName: "Indonesian"),
        AppLanguage(code: "it", nativeName: "Italiano", englishName: "Italian"),
        AppLanguage(code: "ja", nativeName: "日本語", englishName: "Japanese"),
        AppLanguage(code: "ko", nativeName: "한국어", englishName: "Korean"),
        AppLanguage(code: "ms", nativeName: "Bahasa Melayu", englishName: "Malay"),
        AppLanguage(code: "nb", nativeName: "Norsk bokmål", englishName: "Norwegian"),
        AppLanguage(code: "nl", nativeName: "Nederlands", englishName: "Dutch"),
        AppLanguage(code: "pl", nativeName: "Polski", englishName: "Polish"),
        AppLanguage(code: "pt-BR", nativeName: "Português (Brasil)", englishName: "Portuguese (Brazil)"),
        AppLanguage(code: "ro", nativeName: "Română", englishName: "Romanian"),
        AppLanguage(code: "ru", nativeName: "Русский", englishName: "Russian"),
        AppLanguage(code: "sv", nativeName: "Svenska", englishName: "Swedish"),
        AppLanguage(code: "th", nativeName: "ไทย", englishName: "Thai"),
        AppLanguage(code: "tr", nativeName: "Türkçe", englishName: "Turkish"),
        AppLanguage(code: "uk", nativeName: "Українська", englishName: "Ukrainian"),
        AppLanguage(code: "vi", nativeName: "Tiếng Việt", englishName: "Vietnamese"),
        AppLanguage(code: "zh-Hans", nativeName: "简体中文", englishName: "Chinese (Simplified)"),
        AppLanguage(code: "zh-Hant", nativeName: "繁體中文", englishName: "Chinese (Traditional)")
    ]

    var currentLanguage: AppLanguage {
        Self.supportedLanguages.first { $0.code == currentLanguageCode }
            ?? Self.supportedLanguages[0]
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? "en"
        self.currentLanguageCode = saved
        UserDefaults.standard.set([saved], forKey: "AppleLanguages")
    }

    func setLanguage(_ code: String) {
        guard code != currentLanguageCode else { return }
        currentLanguageCode = code
    }
}

// MARK: - Language Model

struct AppLanguage: Identifiable {
    let code: String
    let nativeName: String
    let englishName: String

    var id: String { code }
}

