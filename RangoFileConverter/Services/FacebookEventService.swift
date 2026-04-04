import Foundation
import FacebookCore

enum FacebookEventService {

    // MARK: - Standard Events

    /// fb_mobile_complete_registration — user completes onboarding
    static func logCompleteRegistration() {
        AppEvents.shared.logEvent(.completedRegistration)
    }

    /// fb_mobile_content_view — user views a category or tool
    static func logContentView(contentType: String, contentID: String) {
        AppEvents.shared.logEvent(.viewedContent, parameters: [
            .contentType: contentType,
            .contentID: contentID
        ])
    }

    /// fb_mobile_add_to_cart — paywall viewed (consideration funnel)
    static func logAddToCart() {
        AppEvents.shared.logEvent(.addedToCart)
    }

    /// fb_mobile_initiated_checkout — user taps Continue to buy a plan
    static func logInitiatedCheckout(planID: String, price: Double, currency: String) {
        AppEvents.shared.logEvent(.initiatedCheckout, valueToSum: price, parameters: [
            .contentID: planID,
            .currency: currency
        ])
    }

    /// fb_mobile_purchase — subscription purchased with revenue for ROAS
    static func logPurchase(amount: Double, currency: String, productID: String) {
        AppEvents.shared.logPurchase(amount: amount, currency: currency, parameters: [
            .contentID: productID
        ])
    }

    // MARK: - Custom Events

    /// First conversion completed — high-value signal for lookalike audiences
    static func logFirstConversion(mediaCategory: String, toolType: String) {
        AppEvents.shared.logEvent(AppEvents.Name("first_conversion_completed"), parameters: [
            .contentType: mediaCategory,
            .contentID: toolType
        ])
    }

    /// Feature/tool used — engagement signal for ad optimization
    static func logFeatureUsed(toolID: String, mediaCategory: String) {
        AppEvents.shared.logEvent(AppEvents.Name("feature_used"), parameters: [
            .contentID: toolID,
            .contentType: mediaCategory
        ])
    }
}
