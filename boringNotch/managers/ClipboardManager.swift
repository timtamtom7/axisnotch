//
//  ClipboardManager.swift
//  boringNotch
//
//  Manages clipboard history with SQLite persistence
//

import Foundation
import SQLite
import AppKit

final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published private(set) var items: [ClipboardItem] = []

    private var db: Connection?
    private let clipboardItems = Table("clipboard_items")
    private let id = SQLite.Expression<String>("id")
    private let content = SQLite.Expression<String>("content")
    private let timestamp = SQLite.Expression<Int64>("timestamp")
    private let pinned = SQLite.Expression<Bool>("pinned")

    private let maxItems = 50

    private init() {
        setupDatabase()
        loadItems()
        startMonitoring()
    }

    private func setupDatabase() {
        do {
            let path = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Axis/axis.sqlite3")
            try FileManager.default.createDirectory(
                at: path.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            db = try Connection(path.path)
            try db?.run(clipboardItems.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(content)
                t.column(timestamp)
                t.column(pinned, defaultValue: false)
            })
        } catch {
            print("ClipboardManager: failed to setup database: \(error)")
        }
    }

    private func loadItems() {
        guard let db = db else { return }
        do {
            var loadedItems: [ClipboardItem] = []
            let query = clipboardItems.order(pinned.desc, timestamp.desc).limit(maxItems)
            for row in try db.prepare(query) {
                let item = ClipboardItem(
                    id: UUID(uuidString: row[id]) ?? UUID(),
                    content: row[content],
                    timestamp: Date(timeIntervalSince1970: TimeInterval(row[timestamp])),
                    isPinned: row[pinned]
                )
                loadedItems.append(item)
            }
            DispatchQueue.main.async {
                self.items = loadedItems
            }
        } catch {
            print("ClipboardManager: failed to load items: \(error)")
        }
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

        guard let db = db else { return }
        do {
            try db.run(clipboardItems.insert(
                id <- newItem.id.uuidString,
                content <- newItem.content,
                timestamp <- Int64(newItem.timestamp.timeIntervalSince1970),
                pinned <- false
            ))
            pruneIfNeeded()
            DispatchQueue.main.async {
                self.items.insert(newItem, at: 0)
                self.items = Array(self.items.prefix(self.maxItems))
            }
        } catch {
            print("ClipboardManager: failed to add item: \(error)")
        }
    }

    private func pruneIfNeeded() {
        guard let db = db else { return }
        do {
            let count = try db.scalar(clipboardItems.count)
            if count > maxItems {
                let excess = count - maxItems
                let oldestNonPinned = clipboardItems
                    .filter(pinned == false)
                    .order(timestamp.asc)
                    .limit(excess)
                try db.run(oldestNonPinned.delete())
            }
        } catch {
            print("ClipboardManager: failed to prune: \(error)")
        }
    }

    func copyToClipboard(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
    }

    func togglePinned(_ item: ClipboardItem) {
        guard let db = db else { return }
        do {
            let target = clipboardItems.filter(id == item.id.uuidString)
            try db.run(target.update(pinned <- !item.isPinned))
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = ClipboardItem(
                    id: item.id,
                    content: item.content,
                    timestamp: item.timestamp,
                    isPinned: !item.isPinned
                )
            }
        } catch {
            print("ClipboardManager: failed to toggle pinned: \(error)")
        }
    }
}

struct ClipboardItem: Identifiable {
    public let id: UUID
    let content: String
    let timestamp: Date
    var isPinned: Bool
}