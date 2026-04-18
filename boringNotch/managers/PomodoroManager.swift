//
//  PomodoroManager.swift
//  boringNotch
//
//  Manages Pomodoro timer state and Live Activity
//

import Foundation
import ActivityKit
import SwiftUI

final class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()

    @Published var secondsRemaining: Int = 25 * 60
    @Published var isRunning: Bool = false
    @Published var sessionsCompleted: Int = 0

    private var timerTask: Task<Void, Never>?
    private var pomodoroActivity: Activity<PomodoroAttributes>?

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
    }

    private func onSessionComplete() {
        pause()
        sessionsCompleted += 1

        // Flash notch border
        NotificationCenter.default.post(name: .pomodoroComplete, object: nil)

        startLiveActivity()

        if sessionsCompleted % 4 == 0 {
            secondsRemaining = longBreakDuration
        } else {
            secondsRemaining = breakDuration
        }
    }

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = PomodoroAttributes(sessionsCompleted: sessionsCompleted)
        let state = PomodoroAttributes.ContentState(timeRemaining: secondsRemaining, isRunning: isRunning)

        do {
            pomodoroActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            print("PomodoroManager: failed to start Live Activity: \(error)")
        }
    }

    func endLiveActivity() {
        Task {
            await pomodoroActivity?.end(nil, dismissalPolicy: .immediate)
        }
    }
}

struct PomodoroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: Int
        var isRunning: Bool
    }

    var sessionsCompleted: Int
}

extension Notification.Name {
    static let pomodoroComplete = Notification.Name("pomodoroComplete")
}