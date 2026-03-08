//
//  DailyReminderManager.swift
//  RangoFileConverter
//
//  Created by Sardor Islomov on 08/03/26.
//

import UserNotifications
import Foundation
import Combine

final class DailyReminderManager: ObservableObject {

    static let shared = DailyReminderManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let identifier = "com.rango.daily-reminder"
    private let enabledKey = "daily_reminders_enabled"

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if isEnabled {
                requestAndSchedule()
            } else {
                cancelReminder()
            }
        }
    }

    // 7 messages based on popular features
    private let reminders: [(title: String, body: String)] = [
        (
            "Convert Images Instantly",
            "Turn your HEIC photos into JPEG, PNG, or WEBP with a single tap. Try it now!"
        ),
        (
            "Video Conversion Made Easy",
            "Need to convert a video to MP4, MOV, or AVI? Rango handles it all on your device."
        ),
        (
            "Extract Audio from Videos",
            "Pull the audio from any video and save it as MP3, WAV, or FLAC in seconds."
        ),
        (
            "Compress Files, Save Space",
            "Reduce your photo and video file sizes without losing quality. Free up storage today!"
        ),
        (
            "PDF Tools at Your Fingertips",
            "Merge, split, reorder, or password-protect your PDFs right from your phone."
        ),
        (
            "Create GIFs from Videos",
            "Turn your favorite video clips into fun GIFs. It only takes a few taps!"
        ),
        (
            "Trim & Speed Up Videos",
            "Clip the best moments or speed up your videos. All processing stays on your device."
        ),
    ]

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    }

    // MARK: - Public

    /// Re-schedule if reminders are enabled (call on app launch).
    func rescheduleIfNeeded() {
        guard isEnabled else { return }
        scheduleDailyReminder()
    }

    // MARK: - Private

    private func requestAndSchedule() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.scheduleDailyReminder()
                } else {
                    self.isEnabled = false
                }
            }
        }
    }

    private func scheduleDailyReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

        let reminder = reminders[dayIndex()]

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request)
    }

    private func cancelReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private func dayIndex() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date()) // 1-7
        return (weekday - 1) % reminders.count
    }
}
