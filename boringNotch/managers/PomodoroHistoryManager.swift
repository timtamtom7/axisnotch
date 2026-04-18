//
//  PomodoroHistoryManager.swift
//  boringNotch
//
//  Tracks completed Pomodoro sessions and provides weekly stats
//

import Foundation
import Combine
import Defaults
import SwiftUI

final class PomodoroHistoryManager: ObservableObject {
    static let shared = PomodoroHistoryManager()

    @Published var todaySessions: Int = 0
    @Published var weeklySessions: [DailySession] = []
    @Published var weeklyGoal: Int = 8

    struct DailySession: Identifiable, Codable {
        let id: UUID
        let date: Date
        var sessionsCompleted: Int

        var dayOfWeek: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }

        var isToday: Bool {
            Calendar.current.isDateInToday(date)
        }
    }

    private let historyKey = "pomodoroHistory"
    private let goalKey = "pomodoroGoalPerDay"

    private init() {
        loadHistory()
        weeklyGoal = UserDefaults.standard.object(forKey: goalKey) as? Int ?? 8
    }

    func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([DailySession].self, from: data) else {
            setupWeeklyHistory()
            return
        }

        updateTodayCount(from: history)
        weeklySessions = history.sorted { $0.date > $1.date }
    }

    private func setupWeeklyHistory() {
        let calendar = Calendar.current
        let today = Date()

        weeklySessions = (0..<7).compactMap { daysAgo -> DailySession? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            return DailySession(id: UUID(), date: date, sessionsCompleted: 0)
        }.sorted { $0.date < $1.date }
    }

    private func updateTodayCount(from history: [DailySession]) {
        let calendar = Calendar.current
        todaySessions = history.first { calendar.isDate($0.date, inSameDayAs: Date()) }?.sessionsCompleted ?? 0
    }

    func recordSession() {
        let calendar = Calendar.current
        let today = Date()

        if let index = weeklySessions.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            weeklySessions[index].sessionsCompleted += 1
            todaySessions = weeklySessions[index].sessionsCompleted
        } else {
            let newSession = DailySession(id: UUID(), date: today, sessionsCompleted: 1)
            weeklySessions.append(newSession)
            todaySessions = 1
        }

        saveHistory()
    }

    private func saveHistory() {
        let sortedHistory = weeklySessions.sorted { $0.date > $1.date }
        if let data = try? JSONEncoder().encode(sortedHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func setWeeklyGoal(_ goal: Int) {
        weeklyGoal = goal
        UserDefaults.standard.set(goal, forKey: goalKey)
    }

    var totalWeeklySessions: Int {
        weeklySessions.reduce(0) { $0 + $1.sessionsCompleted }
    }

    var weeklyProgress: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(Double(todaySessions) / Double(weeklyGoal), 1.0)
    }
}

// MARK: - Pomodoro History Card

struct PomodoroHistoryCard: View {
    @ObservedObject private var historyManager = PomodoroHistoryManager.shared
    @State private var showWeeklyStats: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "timer")
                    .font(.system(size: 9))
                    .foregroundColor(.red)
                Text("Pomodoro")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text("\(historyManager.todaySessions)/\(historyManager.weeklyGoal)")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            ProgressView(value: historyManager.weeklyProgress)
                .tint(.red)
                .frame(height: 4)

            Text("sessions today")
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
        .padding(8)
        .frame(width: 130, height: 110)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
        .onTapGesture {
            showWeeklyStats = true
        }
        .popover(isPresented: $showWeeklyStats, arrowEdge: .bottom) {
            WeeklyPomodoroStats()
        }
    }
}

struct WeeklyPomodoroStats: View {
    @ObservedObject private var historyManager = PomodoroHistoryManager.shared

    var body: some View {
        VStack(spacing: 12) {
            Text("Weekly Progress")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(historyManager.weeklySessions) { session in
                    VStack(spacing: 4) {
                        Text("\(session.sessionsCompleted)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(session.isToday ? .red : .primary)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(session.isToday ? Color.red : Color.gray.opacity(0.3))
                            .frame(width: 24, height: max(CGFloat(session.sessionsCompleted) * 8, 4))

                        Text(session.dayOfWeek)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 80)

            HStack {
                Text("Total:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("\(historyManager.totalWeeklySessions)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
            }

            HStack {
                Text("Daily Goal:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Stepper("\(historyManager.weeklyGoal)", value: Binding(
                    get: { historyManager.weeklyGoal },
                    set: { historyManager.setWeeklyGoal($0) }
                ), in: 1...20)
                .labelsHidden()
                .font(.system(size: 10))
            }
        }
        .padding(16)
        .frame(width: 220)
    }
}
