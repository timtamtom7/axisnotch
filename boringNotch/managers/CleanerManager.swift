//
//  CleanerManager.swift
//  boringNotch
//
//  App cleaner that shows cache sizes and allows one-tap cleaning
//

import Foundation
import Combine
import AppKit
import SwiftUI
import Security

// MARK: - Admin Authorization

final class AdminAuthorization: ObservableObject {
    static let shared = AdminAuthorization()

    @Published var isAuthorized: Bool = false
    private var authRef: AuthorizationRef?

    private init() {}

    @MainActor
    func requestAdminAuthorization(reason: String) async -> Bool {
        var authItem = AuthorizationItem(name: kAuthorizationRightExecute, valueLength: 0, value: nil, flags: 0)
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        let authFlags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]

        var tempAuthRef: AuthorizationRef?
        var status = AuthorizationCreate(nil, nil, [], &tempAuthRef)

        if status == errAuthorizationSuccess, let ref = tempAuthRef {
            status = AuthorizationCopyRights(ref, &authRights, nil, authFlags, nil)
            authRef = ref
        }

        isAuthorized = (status == errAuthorizationSuccess)

        if status == errAuthorizationSuccess {
            return true
        } else if status == errAuthorizationCanceled {
            // User canceled the authorization dialog
            return false
        }

        // Try alternative method using AppleScript for privilege escalation
        return await requestAdminViaAppleScript(reason: reason)
    }

    private func requestAdminViaAppleScript(reason: String) async -> Bool {
        let script = """
        do shell script "echo test" with administrator privileges
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            let success = error == nil
            isAuthorized = success
            return success
        }
        return false
    }

    func releaseAuthorization() {
        if let authRef = authRef {
            AuthorizationFree(authRef, [])
            self.authRef = nil
        }
        isAuthorized = false
    }

    private func sanitizeCommand(_ input: String) -> String {
        return input.replacingOccurrences(of: "\"", with: "\\\"")
                   .replacingOccurrences(of: "\\", with: "\\\\")
    }

    func executeWithAdminPrivileges(command: String) async -> (success: Bool, output: String) {
        let fullCommand = "do shell script \"\(sanitizeCommand(command))\" with administrator privileges"

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: fullCommand) {
            let result = appleScript.executeAndReturnError(&error)
            if error == nil, let output = result.stringValue {
                return (true, output)
            }
        }
        return (false, error?.description ?? "Unknown error")
    }
}

// MARK: - CleanerManager

final class CleanerManager: ObservableObject {
    static let shared = CleanerManager()

    @Published var browserCacheSize: Int64 = 0
    @Published var appCacheSize: Int64 = 0
    @Published var logsSize: Int64 = 0
    @Published var totalSize: Int64 = 0
    @Published var isScanning: Bool = false
    @Published var isCleaning: Bool = false
    @Published var lastCleanDate: Date?
    @Published var requiresAdmin: Bool = false
    @Published var showAuthAlert: Bool = false

    struct CleanerItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let color: String
        var size: Int64
        let paths: [String]
        let requiresAdmin: Bool
    }

    private let adminAuth = AdminAuthorization.shared

    private init() {
        scanCacheSizes()
    }

    func scanCacheSizes() {
        isScanning = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            var browserCache: Int64 = 0
            var appCache: Int64 = 0
            var logs: Int64 = 0

            // Safari/Cache
            let safariCachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("com.apple.Safari")
            browserCache += self.sizeOfDirectory(at: safariCachePath)

            // Chrome cache
            let chromeCachePath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/com.google.Chrome")
            browserCache += self.sizeOfDirectory(at: chromeCachePath)

            // Firefox cache
            let firefoxCachePath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/Mozilla")
            browserCache += self.sizeOfDirectory(at: firefoxCachePath)

            // App caches (Caches directory)
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            appCache += self.sizeOfDirectory(at: cachesDir)

            // Logs
            let logsDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Logs")
            logs += self.sizeOfDirectory(at: logsDir)

            DispatchQueue.main.async {
                self.browserCacheSize = browserCache
                self.appCacheSize = appCache
                self.logsSize = logs
                self.totalSize = browserCache + appCache + logs
                self.isScanning = false
            }
        }
    }

    private func sizeOfDirectory(at url: URL) -> Int64 {
        var size: Int64 = 0
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    size += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }

        return size
    }

    func cleanBrowserCache() {
        cleanCache(at: [
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("com.apple.Safari"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/com.google.Chrome"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/Mozilla")
        ], requiresAdmin: false)
    }

    func cleanAppCache() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cleanCache(at: [cachesDir], requiresAdmin: false)
    }

    func cleanLogs() {
        let logsDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
        cleanCache(at: [logsDir], requiresAdmin: false)
    }

    func cleanAll() {
        isCleaning = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Clean browser cache
            self.cleanBrowserCacheInternal()

            // Clean app cache
            self.cleanAppCacheInternal()

            // Clean logs
            self.cleanLogsInternal()

            DispatchQueue.main.async {
                self.lastCleanDate = Date()
                self.isCleaning = false
                self.scanCacheSizes()
            }
        }
    }

    func cleanAllWithAdminIfNeeded() {
        // Some operations may require admin - show auth alert if needed
        showAuthAlert = true
    }

    private func cleanCache(at urls: [URL], requiresAdmin: Bool) {
        if requiresAdmin && !adminAuth.isAuthorized {
            // Request authorization first
            Task {
                let authorized = await adminAuth.requestAdminAuthorization(reason: "Delete system cache")
                if authorized {
                    await performCleanCache(at: urls)
                }
            }
        } else {
            performCleanCacheSync(at: urls)
        }
    }

    private func performCleanCache(at urls: [URL]) async {
        for url in urls {
            await performCleanCacheItem(at: url)
        }
    }

    private func performCleanCacheItem(at url: URL) async {
        // Use admin privileges if available
        if adminAuth.isAuthorized {
            let command = "rm -rf '\(url.path)' && mkdir -p '\(url.path)'"
            _ = await adminAuth.executeWithAdminPrivileges(command: command)
        } else {
            performCleanCacheSync(at: [url])
        }
    }

    private func performCleanCacheSync(at urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func cleanBrowserCacheInternal() {
        let urls = [
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("com.apple.Safari"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/com.google.Chrome"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/Mozilla")
        ]
        performCleanCacheSync(at: urls)
    }

    private func cleanAppCacheInternal() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        performCleanCacheSync(at: [cachesDir])
    }

    private func cleanLogsInternal() {
        let logsDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
        performCleanCacheSync(at: [logsDir])
    }

    func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Cleaner Card

struct CleanerCard: View {
    @ObservedObject private var cleanerManager = CleanerManager.shared
    @ObservedObject private var adminAuth = AdminAuthorization.shared
    @State private var showConfirmation: Bool = false
    @State private var showCleanResult: Bool = false
    @State private var showAuthError: Bool = false
    @State private var authErrorMessage: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "trash.circle")
                    .font(.system(size: 9))
                    .foregroundColor(.purple)
                Text("Cleaner")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)

                Spacer()

                if adminAuth.isAuthorized {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 7))
                        .foregroundColor(.green)
                }
            }

            Spacer()

            if cleanerManager.isScanning {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                Text(cleanerManager.formatSize(cleanerManager.totalSize))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Circle().fill(Color.blue).frame(width: 4, height: 4)
                        Text("Browser: \(cleanerManager.formatSize(cleanerManager.browserCacheSize))")
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Circle().fill(Color.green).frame(width: 4, height: 4)
                        Text("Apps: \(cleanerManager.formatSize(cleanerManager.appCacheSize))")
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: { showConfirmation = true }) {
                    Text("Clean")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.6))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 130, height: 110)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
        .alert("Clean Cache", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean All", role: .destructive) {
                performCleanWithAuth()
            }
        } message: {
            Text("This will remove browser caches, app caches, and logs. Some data may be recreated on next launch.")
        }
        .alert("Cache Cleaned", isPresented: $showCleanResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Cache cleanup completed successfully.")
        }
        .alert("Authorization Required", isPresented: $showAuthError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authErrorMessage)
        }
    }

    private func performCleanWithAuth() {
        // Request admin authorization if needed for certain operations
        Task {
            if cleanerManager.requiresAdmin && !adminAuth.isAuthorized {
                let authorized = await adminAuth.requestAdminAuthorization(
                    reason: "Admin access required to clean certain system caches"
                )
                if !authorized {
                    await MainActor.run {
                        authErrorMessage = "Administrator authorization is required to clean system caches. Please grant admin privileges and try again."
                        showAuthError = true
                    }
                    return
                }
            }
            await MainActor.run {
                cleanerManager.cleanAll()
                showCleanResult = true
            }
        }
    }
}
