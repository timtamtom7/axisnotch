//
//  CalendarAlertView.swift
//  boringNotch
//
//  Calendar alert component shown when an event is approaching
//

import SwiftUI
import Defaults

struct CalendarAlertView: View {
    @ObservedObject var calendarManager = CalendarManager.shared
    @EnvironmentObject var vm: BoringViewModel
    @State private var isExpanded: Bool = false
    @State private var timeRemaining: Int = 0
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        if calendarManager.showCalendarAlert, let event = calendarManager.upcomingAlertEvent {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(event.calendar.color))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(timeString)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }

                Spacer()

                HStack(spacing: 4) {
                    Button(action: {
                        calendarManager.dismissAlert()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        calendarManager.openCalendarApp()
                    }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.effectiveAccent)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(event.calendar.color).opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                updateTimeRemaining()
                timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        updateTimeRemaining()
                    }
            }
            .onDisappear {
                timerCancellable?.cancel()
                timerCancellable = nil
            }
        }
    }

    private var timeString: String {
        let minutes = timeRemaining
        if minutes < 1 {
            return "Starting now"
        } else if minutes == 1 {
            return "In 1 minute"
        } else if minutes < 60 {
            return "In \(minutes) minutes"
        } else {
            let hours = minutes / 60
            return hours == 1 ? "In 1 hour" : "In \(hours) hours"
        }
    }

    private func updateTimeRemaining() {
        guard let event = calendarManager.upcomingAlertEvent else {
            timeRemaining = 0
            return
        }
        let interval = event.start.timeIntervalSinceNow
        timeRemaining = max(0, Int(interval / 60))
    }
}

struct CalendarCountdownView: View {
    @ObservedObject var calendarManager = CalendarManager.shared

    var body: some View {
        if let event = calendarManager.countdownEvent,
           calendarManager.upcomingAlertEvent == nil,
           Defaults[.showCalendarAlerts] {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)

                Text(event.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("-")
                    .foregroundColor(.gray)

                Text(countdownString)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private var countdownString: String {
        guard let event = calendarManager.countdownEvent else { return "" }
        let interval = event.start.timeIntervalSinceNow
        let minutes = Int(interval / 60)

        if minutes < 1 {
            return "Now"
        } else if minutes == 1 {
            return "1m"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            if remainingMins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMins)m"
        }
    }
}

#Preview {
    VStack {
        CalendarAlertView()
        Spacer()
        CalendarCountdownView()
    }
    .padding()
    .background(Color.black)
    .environmentObject(BoringViewModel())
}