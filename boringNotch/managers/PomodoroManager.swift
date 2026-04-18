//
//  PomodoroManager.swift
//  boringNotch
//
//  Manages Pomodoro timer state and Live Activity
//

import Foundation
import SwiftUI
import Defaults

final class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()

    @Published var secondsRemaining: Int = 25 * 60
    @Published var isRunning: Bool = false
    @Published var sessionsCompleted: Int = 0
    @Published var isBreak: Bool = false
    @Published var showLiveActivityCompact: Bool = false

    private var timerTask: Task<Void, Never>?

    #if os(iOS)
    private var pomodoroActivity: Any?
    #endif

    let sessionDuration: Int = 25 * 60
    let breakDuration: Int = 5 * 60
    let longBreakDuration: Int = 15 * 60

    private init() {}

    func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func start() {
        isRunning = true
        if Defaults[.showLiveActivity] {
            showLiveActivityCompact = true
        }
        timerTask = Task {
            while !Task.isCancelled && isRunning && secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    await MainActor.run {
                        self.secondsRemaining -= 1
                        if self.secondsRemaining == 0 {
                            self.onSessionComplete()
                        }
                    }
                }
            }
        }
    }

    func pause() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    func reset() {
        pause()
        secondsRemaining = sessionDuration
        isBreak = false
        showLiveActivityCompact = false
    }

    private func onSessionComplete() {
        pause()
        sessionsCompleted += 1

        // Play chime and flash notch border
        AudioPlayer.shared.playChime()
        NotificationCenter.default.post(name: .pomodoroComplete, object: nil)

        #if os(iOS)
        startLiveActivity()
        #endif

        isBreak = sessionsCompleted % 4 == 0
        if sessionsCompleted % 4 == 0 {
            secondsRemaining = longBreakDuration
        } else {
            secondsRemaining = breakDuration
        }
    }

    #if os(iOS)
    private func startLiveActivity() {
        // Live Activity implementation for iOS would go here
        // This is intentionally empty as ActivityKit is iOS-only
    }
    #endif

    var formattedTime: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var progress: Double {
        let totalDuration = isBreak ? (sessionsCompleted % 4 == 0 ? longBreakDuration : breakDuration) : sessionDuration
        return Double(totalDuration - secondsRemaining) / Double(totalDuration)
    }
}

extension Notification.Name {
    static let pomodoroComplete = Notification.Name("pomodoroComplete")
}
