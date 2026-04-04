//
//  RemoteConfigManager.swift
//  RangoFileConverter
//
//  Created by Sardor Islomov on 08/03/26.
//

import Foundation
import Combine
import os.log
import FirebaseRemoteConfig

final class RemoteConfigManager: ObservableObject {

    static let shared = RemoteConfigManager()

    private var remoteConfig: RemoteConfig?

    // MARK: - Published values

    @Published private(set) var cloudConvertAPIKey: String = ""
    @Published private(set) var requiresForceUpdate: Bool = false

    // MARK: - Init

    private init() {}

    // MARK: - Configure (call after FirebaseApp.configure())

    func configure() {
        let rc = RemoteConfig.remoteConfig()
        self.remoteConfig = rc

        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        rc.configSettings = settings

        rc.setDefaults([
            "cloud_convert_api_key": "" as NSObject,
            "appstore_version": "" as NSObject,
        ])
    }

    // MARK: - Fetch

    func fetchAndActivate() {
        guard let remoteConfig else { return }
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self else { return }
            if let error {
                os_log("[RemoteConfig] Fetch failed: %{public}@", log: .default, type: .error, error.localizedDescription)
                return
            }
            DispatchQueue.main.async {
                self.applyValues()
            }
        }
    }

    private func applyValues() {
        guard let remoteConfig else { return }
        cloudConvertAPIKey = remoteConfig.configValue(forKey: "cloud_convert_api_key").stringValue ?? ""
        if !cloudConvertAPIKey.isEmpty {
            CloudConvertAPIKey.setAPIKey(cloudConvertAPIKey)
        }
        let appStoreVersion = remoteConfig.configValue(forKey: "appstore_version").stringValue ?? ""
        requiresForceUpdate = Self.isVersion(appStoreVersion, greaterThan: Self.currentAppVersion)

        #if DEBUG
        os_log("[RemoteConfig] appstore_version: %{public}@, local: %{public}@, force_update: %{public}@",
               log: .default, type: .debug,
               appStoreVersion.isEmpty ? "(empty)" : appStoreVersion,
               Self.currentAppVersion,
               String(describing: requiresForceUpdate))
        #endif
    }

    // MARK: - Version comparison

    static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static func isVersion(_ remote: String, greaterThan local: String) -> Bool {
        guard !remote.isEmpty else { return false }
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }
        let count = max(remoteParts.count, localParts.count)
        for i in 0..<count {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    // MARK: - Accessors

    func string(forKey key: String) -> String {
        remoteConfig?.configValue(forKey: key).stringValue ?? ""
    }

    func bool(forKey key: String) -> Bool {
        remoteConfig?.configValue(forKey: key).boolValue ?? false
    }

    func number(forKey key: String) -> NSNumber {
        remoteConfig?.configValue(forKey: key).numberValue ?? 0
    }
}
