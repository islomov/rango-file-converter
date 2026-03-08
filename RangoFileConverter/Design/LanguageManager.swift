import SwiftUI
import Combine

// MARK: - Language Manager

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguageCode: String {
        didSet {
            UserDefaults.standard.set(currentLanguageCode, forKey: "app_language")
            UserDefaults.standard.set([currentLanguageCode], forKey: "AppleLanguages")
            loadBundle(for: currentLanguageCode)
        }
    }

    /// The bundle for the currently selected language, used by the swizzled Bundle.main.
    private(set) var currentBundle: Bundle?

    /// Unique ID that changes on language switch — attach to root view via `.id()` to force refresh.
    @Published var refreshID = UUID()

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
        loadBundle(for: saved)
        Self.activateBundleSwizzle()
    }

    func setLanguage(_ code: String) {
        guard code != currentLanguageCode else { return }
        currentLanguageCode = code
        refreshID = UUID()
    }

    // MARK: - Bundle Loading

    private func loadBundle(for code: String) {
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            currentBundle = bundle
        } else {
            currentBundle = nil
        }
    }

    // MARK: - Bundle Swizzle

    private static var swizzled = false

    private static func activateBundleSwizzle() {
        guard !swizzled else { return }
        swizzled = true
        object_setClass(Bundle.main, OverrideBundle.self)
    }
}

// MARK: - Language Model

struct AppLanguage: Identifiable {
    let code: String
    let nativeName: String
    let englishName: String

    var id: String { code }
}

// MARK: - Bundle Override

private class OverrideBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = LanguageManager.shared.currentBundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
