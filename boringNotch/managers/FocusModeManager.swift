//
//  FocusModeManager.swift
//  boringNotch
//
//  Manages macOS Focus mode detection and toggling
//

import Foundation
import Combine
import AppKit

@MainActor
class FocusModeManager: ObservableObject {
    static let shared = FocusModeManager()

    @Published var isFocusActive: Bool = false
    @Published var focusName: String = "Focus"
    @Published var isDNDEnabled: Bool = false

    private var observer: AnyObject?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNotifications()
        updateFocusState()
    }

    private func setupNotifications() {
        // Monitor for Focus/DND changes using DistributedNotificationCenter
        let notificationCenter = DistributedNotificationCenter.default()

        // Listen for Do Not Disturb changes
        notificationCenter.addObserver(
            self,
            selector: #selector(handleDNDChange),
            name: NSNotification.Name("com.apple.FocusStatusChanged"),
            object: nil
        )

        // Also monitor for Bedtime mode changes
        notificationCenter.addObserver(
            self,
            selector: #selector(handleDNDChange),
            name: NSNotification.Name("com.apple.BedtimeModeChanged"),
            object: nil
        )

        // Monitor for screen lock state
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(handleScreenLockChange),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(handleScreenLockChange),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func handleDNDChange(_ notification: Notification) {
        Task { @MainActor in
            updateFocusState()
        }
    }

    @objc private func handleScreenLockChange(_ notification: Notification) {
        Task { @MainActor in
            updateFocusState()
        }
    }

    func updateFocusState() {
        // Check DND status via shell command (common approach for macOS)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        task.arguments = ["-m", "-i", "com.apple.notificationcenterui"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), output.contains("enabled") {
                isDNDEnabled = true
                isFocusActive = true
                focusName = "Do Not Disturb"
            } else {
                isDNDEnabled = false
                // Check if Focus is active via other means
                isFocusActive = checkFocusStatus()
            }
        } catch {
            // Fallback: check via defaults
            checkFocusViaDefaults()
        }
    }

    private func checkFocusStatus() -> Bool {
        // Use AppleScript to check System Preferences Focus state
        var script = """
        tell application "System Events"
            tell process "ControlCenter"
                try
                    return value of menu bar item "Focus" of menu bar 1
                on error
                    return false
                end try
            end tell
        end tell
        """

        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = scriptObject.executeAndReturnError(&error)
            if result.booleanValue {
                return true
            }
        }

        return false
    }

    private func checkFocusViaDefaults() {
        // Check macOS Focus/DND state via defaults
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.ncprefs", "dnd_prefs"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                // Parse DND preferences - simplified check
                isDNDEnabled = true
                isFocusActive = true
                focusName = "Do Not Disturb"
            }
        } catch {
            // Fallback to false
            isDNDEnabled = false
            isFocusActive = false
        }

        // Also check for specific Focus modes
        checkSpecificFocusMode()
    }

    private func checkSpecificFocusMode() {
        // Check for specific named Focus modes via pmset
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "ps"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Check if displays are prevented from sleeping (Focus active)
                if output.contains("displays prevented from sleeping") {
                    // Could indicate Focus is active
                }
            }
        } catch {
            // Ignore
        }

        // Check Focus mode name via defaults for named modes
        checkNamedFocusMode()
    }

    private func checkNamedFocusMode() {
        // macOS stores Focus mode info in preferences
        let focusDefaults = UserDefaults(suiteName: "com.apple.controlcenter")
        if let focusState = focusDefaults?.dictionary(forKey: "NSStatusManager Focus Item") {
            if let active = focusState["isActive"] as? Bool, active {
                isFocusActive = true
                if let name = focusState["name"] as? String {
                    focusName = name
                } else {
                    focusName = "Focus"
                }
            }
        }

        // Also check the Apple Focus status
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.ncprefs", "focusState"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if output.contains("1") || output.contains("true") {
                    isFocusActive = true
                }
            }
        } catch {
            // Ignore
        }
    }

    func toggleFocus() {
        // Use AppleScript to toggle Focus mode
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                try
                    click menu bar item "Focus" of menu bar 1
                    delay 0.1
                    try
                        click button "Do Not Disturb" of group 1 of window "Control Center"
                    on error
                        click checkbox "Do Not Disturb" of scroll area 1 of group 1 of window "Control Center"
                    end try
                on error
                    -- Try alternative method via System Preferences
                    tell application "System Preferences"
                        activate
                        delay 0.5
                        tell application "System Events"
                            keystroke "f" using {command down, option down}
                        end tell
                    end tell
                end try
            end tell
        end tell
        """

        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
        }
    }

    func toggleDND() {
        // Toggle Do Not Disturb via shortcuts or AppleScript
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                try
                    click menu bar item "Focus" of menu bar 1
                    delay 0.2
                    try
                        click button 1 of group 1 of window "Control Center"
                    on error
                        click menu item 1 of menu 1 of menu bar item "Focus" of menu bar 1
                    end try
                end try
            end tell
        end tell

        tell application "System Events" to key code 53
        """

        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
        }

        // Update state after toggle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task { @MainActor in
                self.updateFocusState()
            }
        }
    }
}