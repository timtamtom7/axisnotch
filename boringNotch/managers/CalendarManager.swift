//
//  CalendarManager.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import Defaults
import EventKit
import SwiftUI
import UserNotifications

// MARK: - CalendarManager

@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    @Published var currentWeekStartDate: Date
    @Published var events: [EventModel] = []
    @Published var allCalendars: [CalendarModel] = []
    @Published var eventCalendars: [CalendarModel] = []
    @Published var reminderLists: [CalendarModel] = []
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var upcomingAlertEvent: EventModel?
    @Published var countdownEvent: EventModel?
    @Published var showCalendarAlert: Bool = false

    private var selectedCalendars: [CalendarModel] = []
    private let calendarService = CalendarService()
    private var eventStoreChangedObserver: NSObjectProtocol?
    private var alertCheckTask: Task<Void, Never>?
    private var dismissedAlertEventIds: Set<String> = []

    private init() {
        self.currentWeekStartDate = CalendarManager.startOfDay(Date())
        setupEventStoreChangedObserver()
        Task {
            await reloadCalendarAndReminderLists()
            await requestNotificationPermission()
            startMonitoringForAlerts()
        }
    }

    deinit {
        if let observer = eventStoreChangedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        alertCheckTask?.cancel()
    }

    private func setupEventStoreChangedObserver() {
        eventStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.reloadCalendarAndReminderLists()
            }
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("📅 Notification permission granted: \(granted)")
        } catch {
            print("📅 Notification permission error: \(error)")
        }
    }

    func startMonitoringForAlerts() {
        alertCheckTask?.cancel()
        alertCheckTask = Task {
            while !Task.isCancelled {
                await checkForUpcomingEvents()
                try? await Task.sleep(for: .seconds(30)) // Check every 30 seconds
            }
        }
    }

    private func checkForUpcomingEvents() async {
        guard Defaults[.showCalendarAlerts] else {
            await MainActor.run {
                self.upcomingAlertEvent = nil
                self.countdownEvent = nil
                self.showCalendarAlert = false
            }
            return
        }

        let now = Date()
        let fifteenMinutesFromNow = now.addingTimeInterval(15 * 60)
        let oneHourFromNow = now.addingTimeInterval(60 * 60)

        // Find events that are starting within 15 minutes (for alert)
        let upcomingAlert = events.first { event in
            guard !event.isAllDay, !event.type.isReminder else { return false }
            let eventStart = event.start
            let isStartingSoon = eventStart > now && eventStart <= fifteenMinutesFromNow
            let notDismissed = !dismissedAlertEventIds.contains(event.id)
            return isStartingSoon && notDismissed
        }

        // Find events starting within 1 hour (for countdown)
        let countdown = events.first { event in
            guard !event.isAllDay, !event.type.isReminder else { return false }
            let eventStart = event.start
            let isWithinHour = eventStart > now && eventStart <= oneHourFromNow
            return isWithinHour
        }

        await MainActor.run {
            if let alert = upcomingAlert, alert.id != upcomingAlertEvent?.id {
                // New alert event detected
                upcomingAlertEvent = alert
                showCalendarAlert = true
                scheduleNotification(for: alert)
            } else if upcomingAlert == nil {
                upcomingAlertEvent = nil
                if countdown == nil {
                    showCalendarAlert = false
                }
            }

            countdownEvent = countdown
        }
    }

    private func scheduleNotification(for event: EventModel) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Event"
        content.body = "\(event.title) starts in \(timeUntil(event.start))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("📅 Failed to schedule notification: \(error)")
            }
        }
    }

    private func timeUntil(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        let minutes = Int(interval / 60)

        if minutes < 1 {
            return "less than a minute"
        } else if minutes == 1 {
            return "1 minute"
        } else if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
    }

    func dismissAlert() {
        if let event = upcomingAlertEvent {
            dismissedAlertEventIds.insert(event.id)
        }
        showCalendarAlert = false
        upcomingAlertEvent = nil
    }

    func openCalendarApp() {
        if let url = URL(string: "x-apple-system://calendar") {
            NSWorkspace.shared.open(url)
        }
        dismissAlert()
    }

    @MainActor
    func reloadCalendarAndReminderLists() async {
        let all = await calendarService.calendars()
        self.eventCalendars = all.filter { !$0.isReminder }
        self.reminderLists = all.filter { $0.isReminder }
        self.allCalendars = all // for legacy compatibility, can be removed if not needed
        updateSelectedCalendars()
    }

    func checkCalendarAuthorization() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        DispatchQueue.main.async {
            print("📅 Current calendar authorization status: \(status)")
            self.calendarAuthorizationStatus = status
        }

        switch status {
        case .notDetermined:
            guard let granted = try? await calendarService.requestAccess(to: .event) else {
                self.calendarAuthorizationStatus = .notDetermined
                return
            }
            self.calendarAuthorizationStatus = granted ? .fullAccess : .denied
            if granted {
                await reloadCalendarAndReminderLists()
                events = await calendarService.events(
                    from: currentWeekStartDate,
                    to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
                    calendars: selectedCalendars.map { $0.id })
            }
        case .restricted, .denied:
            NSLog("Calendar access denied or restricted")
        case .fullAccess:
            NSLog("Full access")
            await reloadCalendarAndReminderLists()
            events = await calendarService.events(
                from: currentWeekStartDate,
                to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
                calendars: selectedCalendars.map { $0.id })
        case .writeOnly:
            NSLog("Write only")
        @unknown default:
            print("Unknown authorization status")
        }
    }

    func checkReminderAuthorization() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        DispatchQueue.main.async {
            print("📅 Current reminder authorization status: \(status)")
            self.reminderAuthorizationStatus = status
        }

        switch status {
        case .notDetermined:
            guard let granted = try? await calendarService.requestAccess(to: .reminder) else {
                self.reminderAuthorizationStatus = .notDetermined
                return
            }
            self.reminderAuthorizationStatus = granted ? .fullAccess : .denied
            if granted {
                await reloadCalendarAndReminderLists()
            }
        case .restricted, .denied:
            NSLog("Reminder access denied or restricted")
        case .fullAccess:
            NSLog("Full access")
            await reloadCalendarAndReminderLists()
        case .writeOnly:
            NSLog("Write only")
        @unknown default:
            print("Unknown authorization status")
        }
    }


    func updateSelectedCalendars() {
        // Populate selectedCalendarIDs based on Defaults calendar selection state
        switch Defaults[.calendarSelectionState] {
        case .all:
            selectedCalendarIDs = Set(allCalendars.map { $0.id })
        case .selected(let identifiers):
            selectedCalendarIDs = identifiers
        }

        // Update the local calendar objects that correspond to the selected ids
        selectedCalendars = allCalendars.filter { selectedCalendarIDs.contains($0.id) }
    }

    func getCalendarSelected(_ calendar: CalendarModel) -> Bool {
        return selectedCalendarIDs.contains(calendar.id)
    }

    func setCalendarSelected(_ calendar: CalendarModel, isSelected: Bool) async {
        var selectionState = Defaults[.calendarSelectionState]

        switch selectionState {
        case .all:
            if !isSelected {
                let identifiers = Set(allCalendars.map { $0.id }).subtracting([calendar.id])
                selectionState = .selected(identifiers)
            }

        case .selected(var identifiers):
            if isSelected {
                identifiers.insert(calendar.id)
            } else {
                identifiers.remove(calendar.id)
            }

            selectionState =
                identifiers.isEmpty
                ? .all : identifiers.count == allCalendars.count ? .all : .selected(identifiers)  // if empty, select all
        }

        Defaults[.calendarSelectionState] = selectionState
        updateSelectedCalendars()
        await updateEvents()
    }

    static func startOfDay(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }

    func updateCurrentDate(_ date: Date) async {
        currentWeekStartDate = Calendar.current.startOfDay(for: date)
        await updateEvents()
    }

    private func updateEvents() async {
        let calendarIDs = selectedCalendars.map { $0.id }
        let eventsResult = await calendarService.events(
            from: currentWeekStartDate,
            to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
            calendars: calendarIDs
        )
        self.events = eventsResult
    }

    func setReminderCompleted(reminderID: String, completed: Bool) async {
        await calendarService.setReminderCompleted(reminderID: reminderID, completed: completed)
        // Refresh events after updating
        events = await calendarService.events(
            from: currentWeekStartDate,
            to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
            calendars: selectedCalendars.map { $0.id })
    }
}
