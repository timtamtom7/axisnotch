//
//  NotificationManager.swift
//  boringNotch
//
//  Handles notification display in the notch area
//

import Foundation
import UserNotifications
import Combine
import Defaults
import SwiftUI

final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var currentNotification: NotchNotification?
    @Published var isNotificationVisible: Bool = false

    private var dismissTimer: Timer?

    struct NotchNotification: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let subtitle: String?
        let appIcon: NSImage?
        let timestamp: Date
    }

    private override init() {
        super.init()
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("NotificationManager: Permission error: \(error)")
            }
        }
        UNUserNotificationCenter.current().delegate = self
    }

    private func isDNDEnabled() -> Bool {
        // Note: Checking DND status properly requires using private APIs or Screen Time
        // For now, we don't check DND and just show notifications
        return false
    }

    private func startDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.dismissNotification()
        }
    }

    func dismissNotification() {
        DispatchQueue.main.async {
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isNotificationVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.currentNotification = nil
            }
        }
    }

    func removeNotification(withIdentifier: String) {
        // Note: removeDeliveredNotification is not available on macOS
        dismissNotification()
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Check Do Not Disturb status
        if isDNDEnabled() {
            completionHandler([])
            return
        }

        let content = notification.request.content

        let notchNotif = NotchNotification(
            title: content.title,
            body: content.body,
            subtitle: content.subtitle,
            appIcon: nil,
            timestamp: Date()
        )

        DispatchQueue.main.async {
            self.currentNotification = notchNotif
            self.isNotificationVisible = true
            self.startDismissTimer()
        }

        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        dismissNotification()
        completionHandler()
    }
}

// MARK: - Notification Banner View for Notch

struct NotificationBannerView: View {
    @ObservedObject var notificationManager = NotificationManager.shared

    var body: some View {
        if let notification = notificationManager.currentNotification {
            HStack(spacing: 8) {
                if let appIcon = notification.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(notification.body)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                Spacer()

                Button(action: { notificationManager.dismissNotification() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.85))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if abs(value.translation.width) > 50 {
                            notificationManager.dismissNotification()
                        }
                    }
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
