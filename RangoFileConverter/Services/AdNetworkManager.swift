//
//  AdNetworkManager.swift
//  RangoFileConverter
//
//  Created by Sardor Islomov on 28/03/26.
//

import UIKit
import os.log
import StoreKit
import AppTrackingTransparency
import FacebookCore

final class AdNetworkManager {
    static let shared = AdNetworkManager()

    // MARK: - Placeholder IDs — replace with real values
    private let metaAppID = "958447749986943"
    private let metaClientToken = "22bdabce16c7821c20b10cf954773aec"

    private var isConfigured = false

    private init() {}

    // MARK: - SDK Initialization

    func configure(application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !isConfigured else { return }
        isConfigured = true

        configureMeta(application: application, launchOptions: launchOptions)
        registerSKAdNetworkConversion()
    }

    // MARK: - Meta (Facebook)

    private func configureMeta(application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        Settings.shared.appID = metaAppID
        Settings.shared.clientToken = metaClientToken
        Settings.shared.isAdvertiserTrackingEnabled = (ATTrackingManager.trackingAuthorizationStatus == .authorized)
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func handleMetaOpenURL(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        ApplicationDelegate.shared.application(app, open: url, options: options)
    }

    // MARK: - ATT Status Update

    func updateTrackingConsent(authorized: Bool) {
        Settings.shared.isAdvertiserTrackingEnabled = authorized
    }

    // MARK: - SKAdNetwork Conversion Values

    private func registerSKAdNetworkConversion() {
        // Value 0 = app installed
        if #available(iOS 16.1, *) {
            SKAdNetwork.updatePostbackConversionValue(0, coarseValue: .low, lockWindow: false) { error in
                if let error {
                    os_log("[AdNetworkManager] SKAdNetwork postback error: %{public}@", log: .default, type: .error, error.localizedDescription)
                }
            }
        } else {
            SKAdNetwork.updatePostbackConversionValue(0) { error in
                if let error {
                    os_log("[AdNetworkManager] SKAdNetwork postback error: %{public}@", log: .default, type: .error, error.localizedDescription)
                }
            }
        }
    }
}
