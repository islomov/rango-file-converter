//
//  RemoteConfigManager.swift
//  RangoFileConverter
//
//  Created by Sardor Islomov on 08/03/26.
//

import Foundation
import Combine
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
                print("[RemoteConfig] Fetch failed: \(error.localizedDescription)")
                return
            }
            print("[RemoteConfig] Fetch status: \(status.rawValue)")
            DispatchQueue.main.async {
                self.applyValues()
            }
        }
    }

    private func applyValues() {
        guard let remoteConfig else { return }
        cloudConvertAPIKey = remoteConfig.configValue(forKey: "cloud_convert_api_key").stringValue ?? ""
        let appStoreVersion = remoteConfig.configValue(forKey: "appstore_version").stringValue ?? ""
        requiresForceUpdate = Self.isVersion(appStoreVersion, greaterThan: Self.currentAppVersion)

        print("[RemoteConfig] ──────────────────────────────")
        print("[RemoteConfig] appstore_version : \(appStoreVersion.isEmpty ? "(empty)" : appStoreVersion)")
        print("[RemoteConfig] local app version: \(Self.currentAppVersion)")
        print("[RemoteConfig] force update     : \(requiresForceUpdate)")
        print("[RemoteConfig] cloud_convert_key: \(cloudConvertAPIKey.isEmpty ? "(empty)" : String(cloudConvertAPIKey.prefix(8)) + "...")")
        print("[RemoteConfig] ──────────────────────────────")
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
