//
//  ClipboardManager.swift
//  boringNotch
//
//  Manages clipboard history with UserDefaults persistence
//

import Foundation
import Defaults
import AppKit

// MARK: - ClipboardItemKind

enum ClipboardItemKind: String, Codable, CaseIterable {
    case text
    case image
    case url
    case file
    case code

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .url: return "URL"
        case .file: return "File"
        case .code: return "Code"
        }
    }
}

final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published private(set) var items: [ClipboardItem] = []

    private let maxItems = 50
    private let storageKey = Defaults.Key<[ClipboardItemStored]>("clipboardItems", default: [])
    private var lastChangeCount: Int = 0

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
                isPinned: item.isPinned,
                kind: item.kind
            )
        }
    }

    private func saveItems() {
        let stored = items.map { item in
            ClipboardItemStored(
                id: item.id.uuidString,
                content: item.content,
                timestamp: item.timestamp.timeIntervalSince1970,
                isPinned: item.isPinned,
                kind: item.kind
            )
        }
        Defaults[storageKey] = stored
    }

    private func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        let pasteboard = NSPasteboard.general

        // Check for image data first
        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            handleImageClipboard(imageData: imageData)
            return
        }

        // Check for file URLs
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let fileURL = fileURLs.first {
            handleFileClipboard(fileURL: fileURL)
            return
        }

        // Check for URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first, url.isFileURL == false {
            handleURLClipboard(url: url)
            return
        }

        // Check for string content
        if let string = pasteboard.string(forType: .string),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            handleStringClipboard(string: string)
        }
    }

    private func handleImageClipboard(imageData: Data) {
        let content = "Image (\(imageData.count) bytes)"
        let existing = items.first { $0.content == content && $0.kind == .image }
        if existing == nil {
            addItem(content: content, kind: .image, imageData: imageData)
        }
    }

    private func handleFileClipboard(fileURL: URL) {
        let content = fileURL.path
        let existing = items.first { $0.content == content && $0.kind == .file }
        if existing == nil {
            addItem(content: content, kind: .file)
        }
    }

    private func handleURLClipboard(url: URL) {
        let content = url.absoluteString
        let existing = items.first { $0.content == content && $0.kind == .url }
        if existing == nil {
            addItem(content: content, kind: .url)
        }
    }

    private func handleStringClipboard(string: String) {
        let existing = items.first { $0.content == string }
        if existing == nil {
            let kind = detectStringKind(string)
            addItem(content: string, kind: kind)
        }
    }

    private func detectStringKind(_ string: String) -> ClipboardItemKind {
        // Check if it looks like a file path
        if string.hasPrefix("/") || string.hasPrefix("~") {
            let path = (string as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: path) {
                return .file
            }
        }

        // Check if it looks like a URL
        if let url = URL(string: string), url.scheme != nil {
            return .url
        }

        // Check if it looks like code (contains common code patterns)
        let codePatterns = ["{", "}", "func ", "class ", "struct ", "import ", "var ", "let ", "func", "->", "=>", ";;", "/*", "*/", "//", "def ", "function", "const ", "export ", "async ", "await "]
        let lowercased = string.lowercased()
        let codeScore = codePatterns.filter { lowercased.contains($0) }.count
        if codeScore >= 2 || (codeScore >= 1 && string.contains("{")) {
            return .code
        }

        return .text
    }

    func addItem(content: String, kind: ClipboardItemKind = .text, imageData: Data? = nil) {
        let newItem = ClipboardItem(
            id: UUID(),
            content: content,
            timestamp: Date(),
            isPinned: false,
            kind: kind,
            imageData: imageData
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
                isPinned: !item.isPinned,
                kind: item.kind,
                imageData: item.imageData
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
    var kind: ClipboardItemKind
    var imageData: Data?

    init(id: UUID, content: String, timestamp: Date, isPinned: Bool, kind: ClipboardItemKind = .text, imageData: Data? = nil) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.kind = kind
        self.imageData = imageData
    }
}

struct ClipboardItemStored: Codable, Defaults.Serializable {
    let id: String
    let content: String
    let timestamp: TimeInterval
    let isPinned: Bool
    let kind: ClipboardItemKind

    init(id: String, content: String, timestamp: TimeInterval, isPinned: Bool, kind: ClipboardItemKind = .text) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.kind = kind
    }
}
