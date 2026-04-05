import Foundation
import FirebaseAnalytics

enum AnalyticsService {

    // MARK: - Event Names

    enum Event {
        static let appLaunched          = "app_launched"
        static let categorySelected     = "category_selected"
        static let tabSelected          = "tab_selected"
        static let conversionStarted    = "conversion_started"
        static let conversionCompleted  = "conversion_completed"
        static let conversionFailed     = "conversion_failed"
        static let saveToPhotosTapped   = "save_to_photos_tapped"
        static let saveToFilesTapped    = "save_to_files_tapped"
        static let deleteTapped         = "delete_tapped"
        static let historySearched      = "history_searched"
        static let historyFiltered      = "history_filtered"
        static let themeChanged         = "theme_changed"
        static let languageChanged      = "language_changed"
        static let rateAppTapped        = "rate_app_tapped"
        static let storageCleared       = "storage_cleared"

        // Paywall funnel
        static let paywallViewed        = "paywall_viewed"
        static let paywallDismissed     = "paywall_dismissed"
        static let paywallPlanSelected  = "paywall_plan_selected"

        // Subscription lifecycle
        static let subscriptionPurchased = "subscription_purchased"
        static let subscriptionFailed    = "subscription_failed"
        static let subscriptionRestored  = "subscription_restored"

        // Onboarding & engagement
        static let onboardingCompleted  = "onboarding_completed"
        static let fileImported         = "file_imported"
        static let shareTapped          = "share_tapped"
    }

    // MARK: - Parameter Keys

    enum Param {
        static let category      = "category"
        static let toolType      = "tool_type"
        static let sourceFormat  = "source_format"
        static let targetFormat  = "target_format"
        static let mediaCategory = "media_category"
        static let tabName       = "tab_name"
        static let theme         = "theme"
        static let language      = "language"
        static let appVersion    = "app_version"
        static let errorMessage  = "error_message"
        static let planID        = "plan_id"
        static let price         = "price"
        static let currency      = "currency"
        static let source        = "source"
        static let productID     = "product_id"
        static let isPro         = "is_pro"
    }

    // MARK: - Log

    static func log(_ event: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(event, parameters: parameters)
    }
}
