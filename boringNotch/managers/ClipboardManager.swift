//
//  ClipboardManager.swift
//  boringNotch
//
//  Manages clipboard history with UserDefaults persistence
//

import Foundation
import Defaults
import AppKit

final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published private(set) var items: [ClipboardItem] = []

    private let maxItems = 50
    private let storageKey = Defaults.Key<[ClipboardItemStored]>("clipboardItems", default: [])

    private init() {
        loadItems()
        startMonitoring()
    }

    private func loadItems() {
        let stored = Defaults[storageKey]
        items = stored.map { item in
            ClipboardItem(
                id: UUID(uuidString: item.id) ?? UUID(),
                content: item.content,
                timestamp: Date(timeIntervalSince1970: item.timestamp),
                isPinned: item.isPinned
            )
        }
    }

    private func saveItems() {
        let stored = items.map { item in
            ClipboardItemStored(
                id: item.id.uuidString,
                content: item.content,
                timestamp: item.timestamp.timeIntervalSince1970,
                isPinned: item.isPinned
            )
        }
        Defaults[storageKey] = stored
    }

    private func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string),
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let existing = items.first { $0.content == string }
        if existing == nil {
            addItem(content: string)
        }
    }

    func addItem(content: String) {
        let newItem = ClipboardItem(
            id: UUID(),
            content: content,
            timestamp: Date(),
            isPinned: false
        )

        items.insert(newItem, at: 0)
        pruneIfNeeded()
        saveItems()
    }

    private func pruneIfNeeded() {
        if items.count > maxItems {
            // Remove oldest non-pinned items
            var toRemove = items.count - maxItems
            items = items.filter { item in
                if toRemove > 0 && !item.isPinned {
                    toRemove -= 1
                    return false
                }
                return true
            }
        }
    }

    func copyToClipboard(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
    }

    func togglePinned(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = ClipboardItem(
                id: item.id,
                content: item.content,
                timestamp: item.timestamp,
                isPinned: !item.isPinned
            )
            saveItems()
        }
    }
}

struct ClipboardItem: Identifiable {
    public let id: UUID
    let content: String
    let timestamp: Date
    var isPinned: Bool
}

struct ClipboardItemStored: Codable, Defaults.Serializable {
    let id: String
    let content: String
    let timestamp: TimeInterval
    let isPinned: Bool
}
