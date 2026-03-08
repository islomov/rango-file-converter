//
//  RangoFileConverterApp.swift
//  RangoFileConverter
//
//  Created by Sardor Islomov on 20/02/26.
//

import SwiftUI
import UserNotifications
import FirebaseCore

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        RemoteConfigManager.shared.configure()
        RemoteConfigManager.shared.fetchAndActivate()
        UNUserNotificationCenter.current().delegate = self
        DailyReminderManager.shared.rescheduleIfNeeded()
        return true
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
