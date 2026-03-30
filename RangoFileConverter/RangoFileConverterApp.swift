//
//  RangoFileConverterApp.swift
//  RangoFileConverter
//
//  Created by Sardor Islomov on 20/02/26.
//

import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseCrashlytics

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        AnalyticsService.log(AnalyticsService.Event.appLaunched, parameters: [
            AnalyticsService.Param.appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])
        RemoteConfigManager.shared.configure()
        RemoteConfigManager.shared.fetchAndActivate()
        AdNetworkManager.shared.configure(application: application, launchOptions: launchOptions)
        UNUserNotificationCenter.current().delegate = self
        DailyReminderManager.shared.rescheduleIfNeeded()
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AdNetworkManager.shared.handleMetaOpenURL(app, open: url, options: options)
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle tap on notification → navigate to home tab
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationCenter.default.post(name: .didTapDailyReminder, object: nil)
        completionHandler()
    }
}

extension Notification.Name {
    static let didTapDailyReminder = Notification.Name("didTapDailyReminder")
}

// MARK: - App Entry Point

@main
struct RangoFileConverterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var historyStore = HistoryStore.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject private var remoteConfig = RemoteConfigManager.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.locale, languageManager.locale)
                    .environment(\.layoutDirection, languageManager.layoutDirection)
                    .environmentObject(historyStore)
                    .environmentObject(themeManager)
                    .environmentObject(languageManager)
                    .preferredColorScheme(themeManager.colorScheme)

                if showSplash {
                    SplashScreenView()
                        .ignoresSafeArea()
                        .preferredColorScheme(themeManager.colorScheme)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                showSplash = false
                            }
                        }
                }

                if remoteConfig.requiresForceUpdate {
                    ForceUpdateView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: remoteConfig.requiresForceUpdate)
        }
    }
}
