//
//  AdTrackingManager.swift
//  RangoFileConverter
//
//  Created by Sardor Islomov on 14/03/26.
//

import AppTrackingTransparency
import AdSupport
import Combine

final class AdTrackingManager: ObservableObject {
    static let shared = AdTrackingManager()

    @Published private(set) var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    @Published private(set) var advertisingId: String?

    private init() {
        trackingStatus = ATTrackingManager.trackingAuthorizationStatus
        updateAdvertisingId()
    }

    /// Call before any conversion. Shows the ATT dialog if not yet determined, then returns.
    /// Safe to call repeatedly — only prompts once.
    @MainActor
    func ensureTrackingRequested() async {
        guard trackingStatus == .notDetermined else { return }

        let status = await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        trackingStatus = status
        updateAdvertisingId()
        AdNetworkManager.shared.updateTrackingConsent(authorized: status == .authorized)
    }

    /// Returns the IDFA if authorized, otherwise nil.
    var idfa: String? {
        guard trackingStatus == .authorized else { return nil }
        let id = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        guard id != "00000000-0000-0000-0000-000000000000" else { return nil }
        return id
    }

    private func updateAdvertisingId() {
        advertisingId = idfa
    }
}
