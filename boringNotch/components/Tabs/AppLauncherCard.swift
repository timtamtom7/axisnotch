//
//  AppLauncherCard.swift
//  boringNotch
//
//  App launcher card with quick access buttons and recent files
//

import SwiftUI
import AppKit
import Combine
import Defaults

// MARK: - App Launcher Card

struct AppLauncherCard: View {
    @State private var apps: [LauncherApp] = LauncherApp.defaultApps
    @State private var editingApps: Bool = false
    @State private var showAddApp: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "apps.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 10))
                Text("Apps")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)

                Spacer()

                if editingApps {
                    Button(action: { showAddApp = true }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { editingApps.toggle() }) {
                    Image(systemName: editingApps ? "checkmark.circle.fill" : "gearshape")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if editingApps {
                editingView
            } else {
                normalView
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .popover(isPresented: $showAddApp, arrowEdge: .bottom) {
            AddAppPopover(apps: $apps)
        }
        .onAppear {
            loadApps()
        }
    }

    private var normalView: some View {
        HStack(spacing: 6) {
            ForEach(apps.prefix(3)) { app in
                AxisAppButton(icon: app.icon, name: app.name) {
                    openApp(app)
                }
                .contextMenu {
                    if let recentFiles = getRecentFiles(for: app), !recentFiles.isEmpty {
                        Divider()
                        Text("Recent Files")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        ForEach(recentFiles.prefix(5), id: \.self) { file in
                            Button(file.lastPathComponent) {
                                NSWorkspace.shared.open(file)
                            }
                        }
                    }
                    Divider()
                    Button("Remove from Launcher", role: .destructive) {
                        removeApp(app)
                    }
                }
            }
        }
    }

    private var editingView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(apps) { app in
                    VStack(spacing: 2) {
                        Image(systemName: app.icon)
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                            .onTapGesture {
                                removeApp(app)
                            }

                        Text(app.name)
                            .font(.system(size: 6))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func openApp(_ app: LauncherApp) {
        NSWorkspace.shared.launchApplication(app.name)
    }

    private func removeApp(_ app: LauncherApp) {
        apps.removeAll { $0.id == app.id }
        saveApps()
    }

    private func loadApps() {
        if let data = UserDefaults.standard.data(forKey: "launcherApps"),
           let saved = try? JSONDecoder().decode([LauncherApp].self, from: data) {
            apps = saved.isEmpty ? LauncherApp.defaultApps : saved
        }
    }

    private func saveApps() {
        if let data = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(data, forKey: "launcherApps")
        }
    }

    private func getRecentFiles(for app: LauncherApp) -> [URL]? {
        // Note: Accessing recent documents is limited by sandboxing
        // Recent files feature requires more complex implementation with security-scoped bookmarks
        return nil
    }
}

// MARK: - Launcher App Model

struct LauncherApp: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var bundleIdentifier: String?

    init(id: UUID = UUID(), name: String, icon: String, bundleIdentifier: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.bundleIdentifier = bundleIdentifier
    }

    static let defaultApps: [LauncherApp] = [
        LauncherApp(name: "Safari", icon: "safari"),
        LauncherApp(name: "Terminal", icon: "terminal"),
        LauncherApp(name: "Finder", icon: "folder"),
        LauncherApp(name: "Notes", icon: "note.text"),
        LauncherApp(name: "Reminders", icon: "checklist")
    ]
}

// MARK: - Axis App Button

struct AxisAppButton: View {
    let icon: String
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(name)
                    .font(.system(size: 7))
            }
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add App Popover

struct AddAppPopover: View {
    @Binding var apps: [LauncherApp]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 8) {
            Text("Add App")
                .font(.system(size: 12, weight: .semibold))

            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(filteredInstalledApps) { app in
                        Button(action: {
                            addApp(app)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "app.fill")
                                    .foregroundColor(.blue)
                                Text(app.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if apps.contains(where: { $0.name == app.name }) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                        .font(.system(size: 10))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 200)
        }
        .padding(12)
        .frame(width: 240)
    }

    private var filteredInstalledApps: [LauncherApp] {
        let allApps = ["Safari", "Terminal", "Finder", "Notes", "Reminders", "Calendar", "Mail", "Messages", "Photos", "Music", "Podcasts", "App Store", "System Settings", "Activity Monitor", "Console", "Script Editor"]
        return allApps
            .filter { searchText.isEmpty || $0.localizedCaseInsensitiveContains(searchText) }
            .map { LauncherApp(name: $0, icon: iconForApp($0)) }
    }

    private func iconForApp(_ name: String) -> String {
        switch name {
        case "Safari": return "safari"
        case "Terminal": return "terminal"
        case "Finder": return "folder"
        case "Notes": return "note.text"
        case "Reminders": return "checklist"
        case "Calendar": return "calendar"
        case "Mail": return "envelope"
        case "Messages": return "message"
        case "Photos": return "photo"
        case "Music": return "music.note"
        case "Podcasts": return "waveform"
        case "App Store": return "app.badge"
        case "System Settings": return "gearshape"
        case "Activity Monitor": return "chart.bar"
        case "Console": return "terminal"
        case "Script Editor": return "doc.text"
        default: return "app"
        }
    }

    private func addApp(_ app: LauncherApp) {
        guard !apps.contains(where: { $0.name == app.name }) else { return }
        apps.append(app)
        if let data = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(data, forKey: "launcherApps")
        }
    }
}
