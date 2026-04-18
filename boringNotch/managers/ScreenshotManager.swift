//
//  ScreenshotManager.swift
//  boringNotch
//
//  Monitors Desktop for new screenshots and manages screenshot history
//

import Foundation
import AppKit
import Combine
import Defaults
import SwiftUI

final class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()

    @Published var screenshots: [ScreenshotItem] = []
    @Published var isMonitoring: Bool = false

    private var monitorStream: DispatchSourceFileSystemObject?
    private var desktopPath: URL
    private let maxScreenshots = 5

    struct ScreenshotItem: Identifiable, Codable {
        let id: UUID
        let path: String
        let filename: String
        let timestamp: Date

        var url: URL { URL(fileURLWithPath: path) }
        var thumbnail: NSImage? {
            guard let image = NSImage(contentsOf: url) else { return nil }
            let thumbnailSize = NSSize(width: 80, height: 60)
            let thumbnail = NSImage(size: thumbnailSize)
            thumbnail.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: thumbnailSize),
                      from: NSRect(origin: .zero, size: image.size),
                      operation: .copy,
                      fraction: 1.0)
            thumbnail.unlockFocus()
            return thumbnail
        }
    }

    private let screenshotsKey = "savedScreenshots"

    private init() {
        desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        loadSavedScreenshots()
        startMonitoring()
    }

    func loadSavedScreenshots() {
        guard let data = UserDefaults.standard.data(forKey: screenshotsKey),
              let saved = try? JSONDecoder().decode([ScreenshotItem].self, from: data) else {
            return
        }
        screenshots = saved.filter { FileManager.default.fileExists(atPath: $0.path) }
        trimToMax()
    }

    private func saveScreenshots() {
        let paths = screenshots.map { ScreenshotItem(id: $0.id, path: $0.path, filename: $0.filename, timestamp: $0.timestamp) }
        if let data = try? JSONEncoder().encode(paths) {
            UserDefaults.standard.set(data, forKey: screenshotsKey)
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let descriptor = open(desktopPath.path, O_EVTONLY)
        guard descriptor != -1 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.checkForNewScreenshots()
        }

        source.setCancelHandler {
            close(descriptor)
        }

        source.resume()
        monitorStream = source

        // Initial scan
        checkForNewScreenshots()
    }

    func stopMonitoring() {
        monitorStream?.cancel()
        monitorStream = nil
        isMonitoring = false
    }

    private func checkForNewScreenshots() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: self.desktopPath,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )

                let screenshotFiles = contents.filter { url in
                    let filename = url.lastPathComponent
                    return filename.hasPrefix("Screenshot") &&
                           (filename.hasSuffix(".png") || filename.hasSuffix(".jpg") || filename.hasSuffix(".jpeg"))
                }

                let existingPaths = Set(self.screenshots.map { $0.path })
                let newFiles = screenshotFiles.filter { !existingPaths.contains($0.path) }
                    .sorted { url1, url2 in
                        let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                        let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                        return date1 > date2
                    }

                if !newFiles.isEmpty {
                    DispatchQueue.main.async {
                        for fileURL in newFiles.prefix(self.maxScreenshots) {
                            let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey])
                            let item = ScreenshotItem(
                                id: UUID(),
                                path: fileURL.path,
                                filename: fileURL.lastPathComponent,
                                timestamp: resourceValues?.creationDate ?? Date()
                            )
                            self.screenshots.insert(item, at: 0)
                        }
                        self.trimToMax()
                        self.saveScreenshots()
                    }
                }
            } catch {
                print("ScreenshotManager: Failed to scan Desktop: \(error)")
            }
        }
    }

    private func trimToMax() {
        if screenshots.count > maxScreenshots {
            screenshots = Array(screenshots.prefix(maxScreenshots))
        }
    }

    func copyToClipboard(_ item: ScreenshotItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let image = NSImage(contentsOf: item.url) {
            pasteboard.writeObjects([image])
        }
    }

    func share(_ item: ScreenshotItem) {
        guard let image = NSImage(contentsOf: item.url) else { return }
        let picker = NSSharingServicePicker(items: [image])
        if let button = NSApp.keyWindow?.contentView?.subviews.first(where: { $0.acceptsFirstResponder }) {
            picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func delete(_ item: ScreenshotItem) {
        do {
            try FileManager.default.removeItem(at: item.url)
            screenshots.removeAll { $0.id == item.id }
            saveScreenshots()
        } catch {
            print("ScreenshotManager: Failed to delete screenshot: \(error)")
        }
    }
}

// MARK: - Screenshot History Card

struct ScreenshotHistoryCard: View {
    @ObservedObject private var screenshotManager = ScreenshotManager.shared
    @State private var selectedScreenshot: ScreenshotManager.ScreenshotItem?
    @State private var showActionMenu: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
                Text("Screenshots")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            if screenshotManager.screenshots.isEmpty {
                Text("No screenshots")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(screenshotManager.screenshots) { item in
                            ScreenshotThumbnail(item: item)
                                .onTapGesture {
                                    selectedScreenshot = item
                                    showActionMenu = true
                                }
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(width: 140, height: 90)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
        .popover(isPresented: $showActionMenu, arrowEdge: .bottom) {
            if let item = selectedScreenshot {
                ScreenshotActionMenu(item: item)
            }
        }
    }
}

struct ScreenshotThumbnail: View {
    let item: ScreenshotManager.ScreenshotItem

    var body: some View {
        Group {
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 38)
                    .clipped()
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 38)
                    .cornerRadius(4)
            }
        }
    }
}

struct ScreenshotActionMenu: View {
    let item: ScreenshotManager.ScreenshotItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            Text(item.filename)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)

            HStack(spacing: 12) {
                Button("Copy") {
                    ScreenshotManager.shared.copyToClipboard(item)
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Share") {
                    ScreenshotManager.shared.share(item)
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Delete") {
                    ScreenshotManager.shared.delete(item)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(12)
    }
}
