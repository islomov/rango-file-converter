//
//  AppReviewManager.swift
//  RangoFileConverter
//

import StoreKit
import UIKit

final class AppReviewManager {
    static let shared = AppReviewManager()

    private let successCountKey = "appReview_successCount"
    private let lastPromptDateKey = "appReview_lastPromptDate"

    private let requiredSuccesses = 3
    private let minimumDaysBetweenPrompts = 90

    private init() {}

    func recordSuccess() {
        let count = UserDefaults.standard.integer(forKey: successCountKey) + 1
        UserDefaults.standard.set(count, forKey: successCountKey)

        guard count >= requiredSuccesses else { return }
        guard !wasPromptedRecently else { return }

        UserDefaults.standard.set(0, forKey: successCountKey)
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)

        requestReview()
    }

    private var wasPromptedRecently: Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date else {
            return false
        }
        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return daysSince < minimumDaysBetweenPrompts
    }

    private func requestReview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                return
            }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
