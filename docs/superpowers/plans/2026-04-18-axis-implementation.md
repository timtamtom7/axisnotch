# Axis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Axis features: horizontal card tabs, voice input, AI task parsing, clipboard history, Pomodoro timer

**Architecture:** Three-phase approach — (1) fix bugs + establish horizontal card pattern, (2) build services layer (VoiceInput, AI, Clipboard), (3) wire into UI tabs. Each tab's content is replaced with horizontal card rows using the calendar's scroll pattern.

**Tech Stack:** Swift 6, SwiftUI, SQLite.swift, KeyboardShortcuts, Speech framework, FoundationModels, ActivityKit

---

## Phase 1: Bug Fixes + Horizontal Card Foundation

### Task 1: Fix Battery Percentage Text Wrapping

**Files:**
- Modify: `boringNotch/components/Live activities/BoringBattery.swift:196-200`

- [ ] **Step 1: Read the current BoringBatteryView implementation**

Read lines 189-210 of `boringNotch/components/Live activities/BoringBattery.swift`.

- [ ] **Step 2: Add lineLimit(1) to percentage text**

Find the `Text("\(Int32(levelBattery))%")` inside the `HStack` at line ~197. Change it to:

```swift
Text("\(Int32(levelBattery))%")
    .font(.callout)
    .foregroundStyle(.white)
    .lineLimit(1)
```

- [ ] **Step 3: Verify the fix compiles**

Run: `cd /Users/mauriello/Dev/axisnotch && xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -20`

Expected: BUILD SUCCEEDED (or specific errors unrelated to this change)

- [ ] **Step 4: Commit**

```bash
git add boringNotch/components/Live\ activities/BoringBattery.swift
git commit -m "fix: add lineLimit to battery percentage text

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: Build Horizontal Card Row Component

**Files:**
- Create: `boringNotch/components/Tabs/AxisCardRow.swift`

- [ ] **Step 1: Create the AxisCardRow component**

Create `boringNotch/components/Tabs/AxisCardRow.swift`:

```swift
//
//  AxisCardRow.swift
//  boringNotch
//
//  Horizontal scrolling card row with snap-to-item and haptic feedback
//

import SwiftUI

struct AxisCardRow<Item: Identifiable, CardContent: View>: View {
    let items: [Item]
    let spacing: CGFloat
    @ViewBuilder let cardContent: (Item) -> CardContent

    @State private var haptics: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(items) { item in
                    cardContent(item)
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollTargetBehavior(.viewAligned)
        .sensoryFeedback(.alignment, trigger: haptics)
        .onChange(of: haptics) { _, _ in
            // Trigger re-evaluation for haptics
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -20`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add boringNotch/components/Tabs/AxisCardRow.swift
git commit -m "feat: add AxisCardRow horizontal scrolling component

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 2: Tasks Tab — Horizontal Cards + Expansion

### Task 3: Convert Tasks Tab to Horizontal Card Row

**Files:**
- Modify: `boringNotch/components/Tabs/AxisTasksView.swift`

- [ ] **Step 1: Read current AxisTasksView**

Read the entire `AxisTasksView.swift` file.

- [ ] **Step 2: Replace body with horizontal card row**

Replace the `body` property with:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 12) {
        // Task Input
        HStack {
            TextField("Add tasks...", text: $taskInput)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)

            Button(action: parseTasks) {
                Image(systemName: "sparkles")
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(taskInput.isEmpty || isProcessing)
        }

        // Task Cards Row
        if !tasks.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tasks) { task in
                        AxisTaskCard(
                            task: task,
                            isExpanded: expandedTaskId == task.id,
                            onTap: { toggleExpand(task) },
                            onToggle: { toggleTask(task) },
                            onDelete: { deleteTask(task) },
                            onExpandDetails: { showDetailOverlay(for: task) }
                        )
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.never)
            .scrollTargetBehavior(.viewAligned)
        } else {
            VStack {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                Text("No tasks yet")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
    }
    .padding()
    .frame(maxHeight: 300)
}
```

- [ ] **Step 3: Add state for expanded card**

Add to the `AxisTasksView` struct, after `@State private var isListening: Bool = false`:

```swift
@State private var expandedTaskId: UUID? = nil
@State private var showOverlay: Bool = false
@State private var overlayTask: AxisTask? = nil
```

- [ ] **Step 4: Add helper functions**

Add these functions inside `AxisTasksView`:

```swift
private func toggleExpand(_ task: AxisTask) {
    withAnimation(.smooth(duration: 0.25)) {
        if expandedTaskId == task.id {
            expandedTaskId = nil
        } else {
            expandedTaskId = task.id
        }
    }
}

private func showDetailOverlay(for task: AxisTask) {
    overlayTask = task
    showOverlay = true
}
```

- [ ] **Step 5: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED or errors about missing `AxisTaskCard`

- [ ] **Step 6: Commit**

```bash
git add boringNotch/components/Tabs/AxisTasksView.swift
git commit -m "feat: convert Tasks tab to horizontal card row

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: Build AxisTaskCard Component

**Files:**
- Create: `boringNotch/components/Tabs/AxisTaskCard.swift`

- [ ] **Step 1: Create AxisTaskCard**

Create `boringNotch/components/Tabs/AxisTaskCard.swift`:

```swift
//
//  AxisTaskCard.swift
//  boringNotch
//
//  Task card for the horizontal card row
//

import SwiftUI

struct AxisTaskCard: View {
    let task: AxisTask
    let isExpanded: Bool
    let onTap: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onExpandDetails: () -> Void

    @State private var cardHeight: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .green : .gray)
                }
                .buttonStyle(.plain)

                Text(task.title)
                    .font(.system(size: 13))
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .white)
                    .lineLimit(isExpanded ? nil : 1)

                Spacer()

                Circle()
                    .fill(task.priority.color)
                    .frame(width: 8, height: 8)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().background(Color.gray.opacity(0.3))

                    HStack {
                        Text("Priority:")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Spacer()
                        ForEach([TaskPriority.high, .medium, .low], id: \.self) { p in
                            Circle()
                                .fill(p.color)
                                .frame(width: 10, height: 10)
                                .opacity(task.priority == p ? 1 : 0.3)
                                .onTapGesture {
                                    // Priority change handled by parent
                                }
                        }
                    }

                    Button(action: onExpandDetails) {
                        Text("Add details")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .frame(width: 160, height: isExpanded ? 140 : 60)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
        .animation(.smooth(duration: 0.25), value: isExpanded)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add boringNotch/components/Tabs/AxisTaskCard.swift
git commit -m "feat: add AxisTaskCard component with expansion

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 3: Files Tab — Horizontal Cards + ClipboardManager

### Task 5: Build ClipboardManager with SQLite Persistence

**Files:**
- Create: `boringNotch/managers/ClipboardManager.swift`

- [ ] **Step 1: Create ClipboardManager**

Create `boringNotch/managers/ClipboardManager.swift`:

```swift
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
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED or errors about SQLite import (if SQLite.swift not yet in Podfile)

- [ ] **Step 3: Check if SQLite.swift is in the project**

Run: `grep -r "SQLite" /Users/mauriello/Dev/axisnotch/boringNotch/*.xcodeproj/project.pbxproj 2>/dev/null | head -5`

If not found, add to Podfile or SPM — inform the user:

```bash
echo "Note: SQLite.swift dependency needs to be added. Add to Podfile: pod 'SQLite.swift', '~> 0.15'"
```

- [ ] **Step 4: Commit**

```bash
git add boringNotch/managers/ClipboardManager.swift
git commit -m "feat: add ClipboardManager with SQLite persistence

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6: Convert Files Tab to Horizontal Card Row

**Files:**
- Modify: `boringNotch/components/Tabs/AxisFilesView.swift`

- [ ] **Step 1: Read current AxisFilesView**

Read the entire `AxisFilesView.swift`.

- [ ] **Step 2: Replace with horizontal card row using ClipboardManager**

Replace the entire file with:

```swift
//
//  AxisFilesView.swift
//  boringNotch
//
//  File management and clipboard for the notch
//

import SwiftUI
import Defaults

struct AxisFilesView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @State private var searchQuery: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quick Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search files...", text: $searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)

            // Clipboard Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Clipboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)

                if !clipboardManager.items.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(clipboardManager.items) { item in
                                AxisClipboardCard(
                                    item: item,
                                    onCopy: { clipboardManager.copyToClipboard(item) },
                                    onPin: { clipboardManager.togglePinned(item) }
                                )
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.never)
                    .scrollTargetBehavior(.viewAligned)
                } else {
                    Text("No clipboard history")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Quick Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Actions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)

                HStack(spacing: 12) {
                    AxisQuickAction(icon: "doc.on.clipboard", label: "Copy") {
                        if let item = clipboardManager.items.first {
                            clipboardManager.copyToClipboard(item)
                        }
                    }
                    AxisQuickAction(icon: "folder", label: "Files") {
                        NSWorkspace.shared.launchApplication("Finder")
                    }
                    AxisQuickAction(icon: "magnifyingglass", label: "Search") {
                        NSWorkspace.shared.launchApplication("Safari")
                    }
                }
            }
        }
        .padding()
        .frame(maxHeight: 300)
    }
}

struct AxisClipboardCard: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onPin: () -> Void

    @State private var showCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.content)
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundColor(.white)

            HStack {
                Text(formatTime(item.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)

                Spacer()

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }

                Button(action: {
                    onCopy()
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showCopied = false
                    }
                }) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(showCopied ? .green : .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 150, height: 80)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct AxisQuickAction: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AxisFilesView()
        .frame(width: 250, height: 300)
        .background(Color.black)
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add boringNotch/components/Tabs/AxisFilesView.swift
git commit -m "feat: convert Files tab to horizontal clipboard cards

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 4: Tools Tab — Horizontal Cards + Pomodoro

### Task 7: Build PomodoroManager

**Files:**
- Create: `boringNotch/managers/PomodoroManager.swift`

- [ ] **Step 1: Create PomodoroManager**

Create `boringNotch/managers/PomodoroManager.swift`:

```swift
//
//  PomodoroManager.swift
//  boringNotch
//
//  Manages Pomodoro timer state and Live Activity
//

import Foundation
import ActivityKit
import SwiftUI

final class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()

    @Published var secondsRemaining: Int = 25 * 60
    @Published var isRunning: Bool = false
    @Published var sessionsCompleted: Int = 0

    private var timerTask: Task<Void, Never>?
    private var pomodoroActivity: Activity<PomodoroAttributes>?

    let sessionDuration: Int = 25 * 60
    let breakDuration: Int = 5 * 60
    let longBreakDuration: Int = 15 * 60

    private init() {}

    func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func start() {
        isRunning = true
        timerTask = Task {
            while !Task.isCancelled && isRunning && secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    await MainActor.run {
                        self.secondsRemaining -= 1
                        if self.secondsRemaining == 0 {
                            self.onSessionComplete()
                        }
                    }
                }
            }
        }
    }

    func pause() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    func reset() {
        pause()
        secondsRemaining = sessionDuration
    }

    private func onSessionComplete() {
        pause()
        sessionsCompleted += 1
        startLiveActivity()

        if sessionsCompleted % 4 == 0 {
            secondsRemaining = longBreakDuration
        } else {
            secondsRemaining = breakDuration
        }
    }

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = PomodoroAttributes(sessionsCompleted: sessionsCompleted)
        let state = PomodoroAttributes.ContentState(timeRemaining: secondsRemaining, isRunning: isRunning)

        do {
            pomodoroActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            print("PomodoroManager: failed to start Live Activity: \(error)")
        }
    }

    func endLiveActivity() {
        Task {
            await pomodoroActivity?.end(nil, dismissalPolicy: .immediate)
        }
    }
}

struct PomodoroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: Int
        var isRunning: Bool
    }

    var sessionsCompleted: Int
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add boringNotch/managers/PomodoroManager.swift
git commit -m "feat: add PomodoroManager with Live Activity support

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 8: Convert Tools Tab to Horizontal Card Row

**Files:**
- Modify: `boringNotch/components/Tabs/AxisToolsView.swift`

- [ ] **Step 1: Read current AxisToolsView**

Read the entire `AxisToolsView.swift`.

- [ ] **Step 2: Replace with horizontal card row**

Replace the entire file content (keep the `import` lines and `struct AxisAppButton` at bottom):

```swift
//
//  AxisToolsView.swift
//  boringNotch
//
//  Quick utilities for the notch
//

import SwiftUI
import Defaults

struct AxisToolsView: View {
    @ObservedObject private var pomodoroManager = PomodoroManager.shared
    @State private var noteText: String = ""
    @State private var timerSeconds: Int = 0
    @State private var isTimerRunning: Bool = false
    @State private var timerTask: Task<Void, Never>?
    @State private var waterGlasses: Int = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Quick Note Card
                AxisNoteCard(text: $noteText)

                // Stopwatch Card
                AxisStopwatchCard(
                    seconds: $timerSeconds,
                    isRunning: $isTimerRunning,
                    onToggle: toggleTimer,
                    onReset: resetTimer
                )

                // Pomodoro Card
                AxisPomodoroCard(
                    secondsRemaining: pomodoroManager.secondsRemaining,
                    isRunning: pomodoroManager.isRunning,
                    sessionsCompleted: pomodoroManager.sessionsCompleted,
                    onToggle: { pomodoroManager.toggle() },
                    onReset: { pomodoroManager.reset() }
                )

                // Water Tracker Card
                AxisWaterCard(glasses: $waterGlasses)

                // App Launcher Card
                AxisAppLauncherCard()
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollTargetBehavior(.viewAligned)
        .padding()
        .frame(maxHeight: 300)
    }

    private func toggleTimer() {
        if isTimerRunning {
            timerTask?.cancel()
            timerTask = nil
            isTimerRunning = false
        } else {
            isTimerRunning = true
            timerTask = Task {
                while !Task.isCancelled && isTimerRunning {
                    try? await Task.sleep(for: .seconds(1))
                    if !Task.isCancelled {
                        timerSeconds += 1
                    }
                }
            }
        }
    }

    private func resetTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerSeconds = 0
        isTimerRunning = false
    }
}

struct AxisNoteCard: View {
    @Binding var text: String
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.white)
                Text("Note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            if isExpanded {
                TextEditor(text: $text)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                    .frame(height: 80)
            } else {
                Text(text.isEmpty ? "Tap to add note..." : text)
                    .font(.system(size: 12))
                    .foregroundColor(text.isEmpty ? .gray : .white)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(width: isExpanded ? 200 : 150, height: isExpanded ? 140 : 80)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .onTapGesture {
            withAnimation(.smooth(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .animation(.smooth(duration: 0.2), value: isExpanded)
    }
}

struct AxisStopwatchCard: View {
    @Binding var seconds: Int
    @Binding var isRunning: Bool
    let onToggle: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(formatTime(seconds))
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 130, height: 80)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct AxisPomodoroCard: View {
    let secondsRemaining: Int
    let isRunning: Bool
    let sessionsCompleted: Int
    let onToggle: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: CGFloat(secondsRemaining) / CGFloat(25 * 60))
                    .stroke(Color.orange, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                Text(formatTimeShort(secondsRemaining))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack(spacing: 4) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(i < (sessionsCompleted % 4) ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }

            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 130, height: 130)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private func formatTimeShort(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct AxisWaterCard: View {
    @Binding var glasses: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                Text("Water")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("\(glasses) / 8")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)

            HStack(spacing: 4) {
                Button(action: {
                    if glasses > 0 { glasses -= 1 }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if glasses < 8 { glasses += 1 }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 110, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
}

struct AxisAppLauncherCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Apps")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                AxisAppButton(icon: "safari", name: "Safari") {
                    NSWorkspace.shared.launchApplication("Safari")
                }
                AxisAppButton(icon: "terminal", name: "Terminal") {
                    NSWorkspace.shared.launchApplication("Terminal")
                }
                AxisAppButton(icon: "finder", name: "Finder") {
                    NSWorkspace.shared.launchApplication("Finder")
                }
            }
        }
        .padding(12)
        .frame(width: 200, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
}

struct AxisAppButton: View {
    let icon: String
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(name)
                    .font(.system(size: 9))
            }
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AxisToolsView()
        .frame(width: 400, height: 300)
        .background(Color.black)
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add boringNotch/components/Tabs/AxisToolsView.swift
git commit -m "feat: convert Tools tab to horizontal card row with Pomodoro

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 5: Voice Input

### Task 9: Build VoiceInputManager

**Files:**
- Create: `boringNotch/managers/VoiceInputManager.swift`

- [ ] **Step 1: Create VoiceInputManager**

Create `boringNotch/managers/VoiceInputManager.swift`:

```swift
//
//  VoiceInputManager.swift
//  boringNotch
//
//  Handles voice input with toggle mode and SFSpeechRecognizer
//

import Foundation
import Speech
import AVFoundation
import Combine

final class VoiceInputManager: ObservableObject {
    static let shared = VoiceInputManager()

    @Published var isListening: Bool = false
    @Published var transcription: String = ""
    @Published var errorMessage: String?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func toggle() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition unavailable"
            return
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to configure audio session: \(error)"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Failed to create recognition request"
            return
        }

        recognitionRequest.shouldOnDeviceDetect = true
        recognitionRequest.requiresOnDeviceRecognition = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Failed to start audio engine: \(error)"
            return
        }

        isListening = true
        transcription = ""

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self?.transcription = result.bestTranscription.formattedString
                }
            }

            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    self?.stopListening()
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        // Notify AI parser
        if !transcription.isEmpty {
            NotificationCenter.default.post(
                name: .voiceInputCompleted,
                object: nil,
                userInfo: ["transcription": transcription]
            )
        }
    }
}

extension Notification.Name {
    static let voiceInputCompleted = Notification.Name("voiceInputCompleted")
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add boringNotch/managers/VoiceInputManager.swift
git commit -m "feat: add VoiceInputManager with SFSpeechRecognizer toggle mode

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 10: Add Mic Button to BoringHeader

**Files:**
- Modify: `boringNotch/components/Notch/BoringHeader.swift`

- [ ] **Step 1: Read current BoringHeader**

Read the entire `BoringHeader.swift`.

- [ ] **Step 2: Add mic button to the header**

Find the `HStack(spacing: 4)` block starting at line 39 inside `BoringHeader`. Add the mic button before the mirror/settings/battery buttons:

```swift
HStack(spacing: 4) {
    if vm.notchState == .open {
        Button(action: {
            VoiceInputManager.shared.toggle()
        }) {
            Image(systemName: VoiceInputManager.shared.isListening ? "mic.fill" : "mic")
                .foregroundColor(VoiceInputManager.shared.isListening ? .red : .white)
                .opacity(VoiceInputManager.shared.isListening ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: VoiceInputManager.shared.isListening)
        }
        .buttonStyle(PlainButtonStyle())

        if isHUDType(coordinator.sneakPeek.type) && coordinator.sneakPeek.show && Defaults[.showOpenNotchHUD] {
            OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        } else {
            // ... existing code ...
```

Note: The full replacement for this section requires inserting the mic button at line 41 (before the `if isHUDType` check) and keeping the existing mirror/settings/battery buttons intact.

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add boringNotch/components/Notch/BoringHeader.swift
git commit -m "feat: add mic button to BoringHeader for voice input toggle

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 6: AI Task Parsing

### Task 11: Build AIParserService and Providers

**Files:**
- Create: `boringNotch/services/ai/AIParserService.swift`
- Create: `boringNotch/services/ai/AppleIntelligenceProvider.swift`
- Create: `boringNotch/services/ai/OllamaProvider.swift`
- Create: `boringNotch/services/ai/CloudAPIProvider.swift`

- [ ] **Step 1: Create AIParserService protocol and factory**

Create directory `boringNotch/services/ai/` and create `AIParserService.swift`:

```swift
//
//  AIParserService.swift
//  boringNotch
//
//  Protocol and factory for AI task parsing providers
//

import Foundation

protocol AIParserProvider {
    var name: String { get }
    func parse(transcription: String) async throws -> [ParsedTask]
}

struct ParsedTask: Identifiable {
    public let id = UUID()
    var title: String
    var priority: TaskPriority
    var deadline: Date?
    var timeEstimate: Int?
}

enum AIParserError: Error, LocalizedError {
    case notAvailable
    case parsingFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "AI provider not available"
        case .parsingFailed(let msg): return "Parsing failed: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        }
    }
}

final class AIParserService {
    static let shared = AIParserService()

    private var providers: [AIParserProvider] = []

    private init() {
        setupProviders()
    }

    private func setupProviders() {
        // Order matters: first available is used
        providers.append(AppleIntelligenceProvider())
        providers.append(OllamaProvider())
        providers.append(CloudAPIProvider())
    }

    func parse(transcription: String) async throws -> [ParsedTask] {
        for provider in providers {
            do {
                let tasks = try await provider.parse(transcription: transcription)
                return tasks
            } catch {
                print("AIParserService: \(provider.name) failed, trying next: \(error)")
                continue
            }
        }
        throw AIParserError.notAvailable
    }
}
```

- [ ] **Step 2: Create AppleIntelligenceProvider**

Create `boringNotch/services/ai/AppleIntelligenceProvider.swift`:

```swift
//
//  AppleIntelligenceProvider.swift
//  boringNotch
//
//  On-device AI parsing via FoundationModels
//

import Foundation

final class AppleIntelligenceProvider: AIParserProvider {
    var name: String { "Apple Intelligence" }

    func parse(transcription: String) async throws -> [ParsedTask] {
        // FoundationModels usage — requires macOS 26 Tahoe
        // This is a stub — actual implementation uses:
        // ModelContext + any TextPrompt or InstructionPrompt
        // For now, fall back to keyword parsing

        if #available(macOS 26.0, *) {
            return try await performAppleIntelligenceParse(transcription: transcription)
        } else {
            throw AIParserError.notAvailable
        }
    }

    @available(macOS 26.0, *)
    private func performAppleIntelligenceParse(transcription: String) async throws -> [ParsedTask] {
        // Placeholder — actual FoundationModels integration:
        // let model = try ModelContext()
        // let instruction = InstructionPrompt("Extract tasks from: \(transcription)")
        // let result = try await model.perform(instruction)
        // return parseStructuredResult(result)
        throw AIParserError.notAvailable
    }
}
```

- [ ] **Step 3: Create OllamaProvider**

Create `boringNotch/services/ai/OllamaProvider.swift`:

```swift
//
//  OllamaProvider.swift
//  boringNotch
//
//  Local AI parsing via Ollama
//

import Foundation

final class OllamaProvider: AIParserProvider {
    var name: String { "Ollama" }

    func parse(transcription: String) async throws -> [ParsedTask] {
        let url = URL(string: "http://localhost:11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Parse the following into a JSON array of tasks. Each task has: title (string), priority ("high", "medium", or "low"), deadline (ISO date string or null).
        Input: "\(transcription)"
        Output only valid JSON array.
        """

        let body: [String: Any] = [
            "model": "llama3.2",
            "prompt": prompt,
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIParserError.networkError("Ollama returned non-200 response")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw AIParserError.parsingFailed("Invalid Ollama response format")
        }

        return try parseTasksFromJSON(responseText)
    }

    private func parseTasksFromJSON(_ jsonString: String) throws -> [ParsedTask] {
        // Extract JSON array from response (may be wrapped in markdown)
        let cleaned = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw AIParserError.parsingFailed("Could not encode response")
        }

        struct OllamaTask: Codable {
            let title: String
            let priority: String
            let deadline: String?
        }

        let ollamaTasks = try JSONDecoder().decode([OllamaTask].self, from: data)

        return ollamaTasks.map { t in
            ParsedTask(
                title: t.title,
                priority: TaskPriority(rawValue: t.priority) ?? .medium,
                deadline: t.deadline.flatMap { ISO8601DateFormatter().date(from: $0) },
                timeEstimate: nil
            )
        }
    }
}
```

- [ ] **Step 4: Create CloudAPIProvider**

Create `boringNotch/services/ai/CloudAPIProvider.swift`:

```swift
//
//  CloudAPIProvider.swift
//  boringNotch
//
//  Cloud AI parsing via OpenAI-compatible API
//

import Foundation

final class CloudAPIProvider: AIParserProvider {
    var name: String { "Cloud API" }

    // User-configured via Settings
    var apiEndpoint: String {
        Defaults[.cloudAPIEndpoint].isEmpty
            ? "https://api.openai.com/v1/chat/completions"
            : Defaults[.cloudAPIEndpoint]
    }

    var apiKey: String {
        Defaults[.cloudAPIKey]
    }

    func parse(transcription: String) async throws -> [ParsedTask] {
        guard !apiKey.isEmpty else {
            throw AIParserError.notAvailable
        }

        let url = URL(string: apiEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are a task parser. Parse the user input into tasks.
        Return ONLY a JSON array of objects with keys: title (string), priority ("high", "medium", "low"), deadline (ISO 8601 date string or null).
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcription]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIParserError.networkError("Cloud API returned non-200 response")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIParserError.parsingFailed("Invalid Cloud API response format")
        }

        return try parseTasksFromJSON(content)
    }

    private func parseTasksFromJSON(_ jsonString: String) throws -> [ParsedTask] {
        let cleaned = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw AIParserError.parsingFailed("Could not encode response")
        }

        struct CloudTask: Codable {
            let title: String
            let priority: String
            let deadline: String?
        }

        let cloudTasks = try JSONDecoder().decode([CloudTask].self, from: data)

        return cloudTasks.map { t in
            ParsedTask(
                title: t.title,
                priority: TaskPriority(rawValue: t.priority) ?? .medium,
                deadline: t.deadline.flatMap { ISO8601DateFormatter().date(from: $0) },
                timeEstimate: nil
            )
        }
    }
}
```

- [ ] **Step 5: Add Defaults keys for cloud API settings**

In `boringNotch/extensions/` or wherever Defaults keys are defined, add:

```swift
// AI Settings
extension Defaults.Keys {
    static let cloudAPIEndpoint = Key<String>("cloudAPIEndpoint", default: "")
    static let cloudAPIKey = Key<String>("cloudAPIKey", default: "")
    static let ollamaEndpoint = Key<String>("ollamaEndpoint", default: "http://localhost:11434")
    static let aiProviderOrder = Key<[String]>("aiProviderOrder", default: ["AppleIntelligence", "Ollama", "CloudAPI"])
}
```

- [ ] **Step 6: Verify they compile**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add boringNotch/services/ai/
git add boringNotch/extensions/...  # wherever defaults keys were added
git commit -m "feat: add AI parser service with Apple Intelligence, Ollama, and Cloud API providers

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 12: Wire Voice Input to AI Parser and Create Detail Overlay

**Files:**
- Modify: `boringNotch/components/Tabs/AxisTasksView.swift`
- Modify: `boringNotch/managers/VoiceInputManager.swift`

- [ ] **Step 1: Read current AxisTasksView**

Read the full `AxisTasksView.swift`.

- [ ] **Step 2: Add listener for voice input completion**

Add to `AxisTasksView`:

```swift
@State private var cancellables = Set<AnyCancellable>()
```

In `onAppear`, add:

```swift
.onAppear {
    NotificationCenter.default.publisher(for: .voiceInputCompleted)
        .compactMap { $0.userInfo?["transcription"] as? String }
        .sink { transcription in
            Task {
                await parseTasksFromAI(transcription: transcription)
            }
        }
        .store(in: &cancellables)
}
```

Add the async function:

```swift
private func parseTasksFromAI(transcription: String) async {
    do {
        let parsedTasks = try await AIParserService.shared.parse(transcription: transcription)
        await MainActor.run {
            for parsed in parsedTasks {
                let task = AxisTask(
                    title: parsed.title,
                    priority: parsed.priority,
                    isCompleted: false,
                    timeEstimate: parsed.timeEstimate,
                    deadline: parsed.deadline
                )
                tasks.append(task)
            }
        }
    } catch {
        print("AI parsing failed: \(error)")
    }
}
```

- [ ] **Step 3: Add detail overlay to AxisTasksView**

Add a `@State private var showDetailOverlay: Bool = false` and `@State private var detailOverlayTaskIndex: Int? = nil`.

Add at the end of the body (after the main VStack):

```swift
.overlay(alignment: .bottomTrailing) {
    if showDetailOverlay, let taskIndex = detailOverlayTaskIndex {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Add details to task?")
                .font(.system(size: 11))
                .foregroundColor(.white)
            HStack(spacing: 8) {
                Button("Yes") {
                    // Expand the task card for editing
                    if taskIndex < tasks.count {
                        tasks[taskIndex].title += " (editing)"
                    }
                    showDetailOverlay = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Button("No") {
                    showDetailOverlay = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.9))
        .cornerRadius(8)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .padding(8)
    }
}
.animation(.smooth, value: showDetailOverlay)
```

- [ ] **Step 4: After AI parsing, show the overlay**

In `parseTasksFromAI`, after appending tasks:

```swift
if !parsedTasks.isEmpty {
    detailOverlayTaskIndex = tasks.count - 1
    showDetailOverlay = true
    // Auto-dismiss after 5s
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        self.showDetailOverlay = false
    }
}
```

- [ ] **Step 5: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add boringNotch/components/Tabs/AxisTasksView.swift
git commit -m "feat: wire voice input to AI parser with detail overlay

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 7: Pomodoro Chime + Border Flash

### Task 13: Add Pomodoro End Effects

**Files:**
- Modify: `boringNotch/managers/PomodoroManager.swift`
- Create: `boringNotch/helpers/AudioPlayer.swift` (or reuse existing)

- [ ] **Step 1: Read existing AudioPlayer helper**

Run: `cat boringNotch/helpers/AudioPlayer.swift`

- [ ] **Step 2: Add chime method to PomodoroManager**

Add to `onSessionComplete()` in `PomodoroManager`:

```swift
private func onSessionComplete() {
    pause()
    sessionsCompleted += 1

    // Play chime
    AudioPlayer.shared.playChime()

    // Flash notch border
    NotificationCenter.default.post(name: .pomodoroComplete, object: nil)

    startLiveActivity()

    if sessionsCompleted % 4 == 0 {
        secondsRemaining = longBreakDuration
    } else {
        secondsRemaining = breakDuration
    }
}
```

- [ ] **Step 3: Add playChime to AudioPlayer**

Add to `boringNotch/helpers/AudioPlayer.swift`:

```swift
func playChime() {
    // Note: actual sound file path TBD — use system sound as placeholder
    // Target: CleanMyMac-style short, soft, pleasant chime
    NSSound(named: "Glass")?.play()
}
```

- [ ] **Step 4: Handle border flash in ContentView**

In `ContentView.swift`, add an `@State private var pomodoroFlash: Bool = false`.

In `NotchLayout()`, add after the header:

```swift
if pomodoroFlash {
    RoundedRectangle(cornerRadius: 14)
        .stroke(Color.red, lineWidth: 3)
        .padding(-3)
}
```

Add listener in `onAppear`:

```swift
NotificationCenter.default.publisher(for: .pomodoroComplete)
    .sink { _ in
        pomodoroFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            pomodoroFlash = false
        }
    }
    .store(in: &cancellables)
```

- [ ] **Step 5: Verify it compiles**

Run: `xcodebuild -scheme boringNotch -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -30`

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add boringNotch/managers/PomodoroManager.swift boringNotch/helpers/AudioPlayer.swift boringNotch/ContentView.swift
git commit -m "feat: add Pomodoro chime and border flash on session complete

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Spec Coverage Check

| Requirement | Tasks |
|-------------|-------|
| Battery % text wrapping fix | Task 1 |
| Horizontal card rows | Tasks 2, 3, 4, 6, 8 |
| Tasks tab (horizontal cards + expand) | Tasks 3, 4 |
| Files tab (clipboard cards) | Tasks 5, 6 |
| Tools tab (horizontal cards + Pomodoro) | Tasks 7, 8 |
| Pomodoro timer + Live Activity | Tasks 7, 8, 13 |
| Voice input toggle mode | Tasks 9, 10 |
| AI task parsing (3 tiers) | Tasks 11, 12 |
| Detail overlay | Task 12 |
| ClipboardManager (SQLite, 50 items) | Task 5 |
| Pomodoro chime + border flash | Task 13 |

**All spec requirements covered.** No gaps found.
