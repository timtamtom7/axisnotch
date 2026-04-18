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

final class CleanerManager: ObservableObject {
    static let shared = CleanerManager()

    @Published var browserCacheSize: Int64 = 0
    @Published var appCacheSize: Int64 = 0
    @Published var logsSize: Int64 = 0
    @Published var totalSize: Int64 = 0
    @Published var isScanning: Bool = false
    @Published var isCleaning: Bool = false
    @Published var lastCleanDate: Date?

    struct CleanerItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let color: String
        var size: Int64
        let paths: [String]
    }

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
        ])
    }

    func cleanAppCache() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cleanCache(at: [cachesDir])
    }

    func cleanLogs() {
        let logsDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
        cleanCache(at: [logsDir])
    }

    func cleanAll() {
        isCleaning = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Clean browser cache
            self.cleanBrowserCache()

            // Clean app cache
            self.cleanAppCache()

            // Clean logs
            self.cleanLogs()

            DispatchQueue.main.async {
                self.lastCleanDate = Date()
                self.isCleaning = false
                self.scanCacheSizes()
            }
        }
    }

    private func cleanCache(at urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
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
    @State private var showConfirmation: Bool = false
    @State private var showCleanResult: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "trash.circle")
                    .font(.system(size: 9))
                    .foregroundColor(.purple)
                Text("Cleaner")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
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
                cleanerManager.cleanAll()
                showCleanResult = true
            }
        } message: {
            Text("This will remove browser caches, app caches, and logs. Some data may be recreated on next launch.")
        }
        .alert("Cache Cleaned", isPresented: $showCleanResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Cache cleanup completed successfully.")
        }
    }
}
