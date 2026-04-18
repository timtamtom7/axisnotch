# Axis Design Specification

> **Project:** Axis — Personal Command Center for the MacBook Notch
> **Date:** 2026-04-18
> **Status:** Approved

## Overview

Axis transforms the MacBook notch into a personal command center. It adds voice input, AI task parsing, clipboard history, and quick tools — all living in the notch without app-switching. Built on top of boring.notch (GPLv3).

---

## Bug Fixes

### Bug 1: Scroll-to-Close Blocks Files Tab

**Root Cause:** `ScrollMonitor` in `PanGesture.swift` registers a local `NSEvent` monitor for `.scrollWheel` events on the notch window. It intercepts ALL vertical scroll events before SwiftUI's ScrollView can consume them. When the notch is open on Files/Tasks/Tools tabs, any two-finger vertical swipe triggers the close gesture.

**Fix:** Replace all vertical `ScrollView` content with **horizontal card rows** using the same scroll pattern as the calendar date picker. Horizontal scroll does not conflict with the swipe-to-close gesture (which is vertical).

**Files:**
- Modify: `boringNotch/components/Tabs/AxisFilesView.swift`
- Modify: `boringNotch/components/Tabs/AxisTasksView.swift`
- Modify: `boringNotch/components/Tabs/AxisToolsView.swift`

---

### Bug 2: Battery Percentage Text Wraps

**Root Cause:** `BoringBatteryView` at line 197 renders `Text("\(Int32(levelBattery))%")` without `lineLimit(1)` or constrained frame width. At 100% charge, the text can wrap to two lines inside the battery popover.

**Fix:**
- Add `.lineLimit(1)` to the percentage text
- Ensure parent HStack provides fixed width or `frame(width:)` constraint

**Files:**
- Modify: `boringNotch/components/Live activities/BoringBattery.swift:196-200`

---

## Core UX: Horizontal Card Rows

### Pattern

All tab content that was vertical `ScrollView` is replaced with horizontal `ScrollView` card rows:

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 12) {
        ForEach(items) { item in
            CardView(item: item)
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.viewAligned)
.sensoryFeedback(.alignment, trigger: haptics)
```

- **Swipe left/right** → snap to adjacent card
- **Haptic feedback** on each snap via `sensoryFeedback(.alignment)`
- **Tap card** → expand inline or toggle
- No vertical scrolling → no conflict with swipe-to-close

---

## Tab Content

### Tasks Tab (AxisTasksView)

**Cards:** Each task is a horizontal card:

```
┌─────────────────────────┐
│ ○  Finish report by Fri │
│    🔴                    │
└─────────────────────────┘
```

- Left: checkbox (tap to toggle completion)
- Center: task title, strikethrough when done
- Right: priority dot (🔴 red = high, 🟠 orange = medium, 🟢 green = low)
- Card width: ~140pt, fixed height ~50pt

**Expanded state (tap card):**
- Card grows to show: title, priority picker, time estimate input, deadline picker
- Neighboring cards slide in from sides (fluid masonry)
- Card clips at notch boundary, notch does not resize
- Tap outside or tap again to collapse

**Input:** Text field + sparkle button (or voice input) for new tasks. Sparkle button triggers AI parser.

### Files Tab (AxisFilesView)

**Cards:** Two card types in one horizontal row:

**Clipboard cards:**
```
┌───────────────────┐
│ Buy groceries...  │
│ 2m ago     📋     │
└───────────────────┘
```
- Truncated text preview (1 line)
- Relative timestamp
- Tap → copies to clipboard, brief checkmark confirmation

**Quick Action cards:**
```
┌─────┐ ┌─────┐ ┌─────┐
│  📋 │ │ �耐烦 │ │ 🔍  │
│Copy │ │Files│ │Search│
└─────┘ └─────┘ └─────┘
```
- Icon + label
- Tap → action (copy last clipboard, open Files app, open Spotlight)

### Tools Tab (AxisToolsView)

**Cards (horizontal row):**

1. **Quick Note card** — tap to expand, shows TextEditor, auto-saves
2. **Timer card** — stopwatch (existing stub), tap to expand for Pomodoro
3. **Pomodoro card:**
   - Circle progress ring, 25:00 countdown
   - Tap → starts/pauses
   - Long-press → reset
   - End: notch border flashes red, chime plays, Live Activity appears
4. **App Launcher card** — icon grid (Safari, Terminal, Finder), tap to launch
5. **Water Tracker card** — drop icon + "3/8 glasses", tap to increment

**Card expansion (Tools tab):**
- Tap any card → expands inline with animation
- Neighboring cards slide in smoothly
- Content clips at notch edge, notch does not grow
- Same pattern as Tasks tab expansion

---

## Voice Input

### Trigger
- **Button:** Mic icon in notch header (BoringHeader area)
- **Hotkey:** User-configurable keyboard shortcut via `KeyboardShortcuts` framework

### Behavior (Toggle Mode)
1. User taps mic (or presses hotkey) → mic button pulses/glows, `SFSpeechRecognizer` begins continuous on-device recognition
2. User taps mic again (or presses hotkey) → listening stops, transcription sent to AI parser
3. If no speech detected after 10s timeout → listening auto-stops

### Visual Feedback
- Mic icon: pulses with opacity animation while listening
- Optional: real-time transcription preview text below mic

### Implementation
- Framework: `Speech` (SFSpeechRecognizer), on-device mode
- Audio session: `AVAudioSession` configured for recording
- Privacy: microphone permission required, shown once by system

**Files:**
- Create: `boringNotch/managers/VoiceInputManager.swift`
- Modify: `boringNotch/components/Notch/BoringHeader.swift` (add mic button)

---

## AI Task Parsing

### Flow
1. Voice input completes → raw transcription string
2. Send to AI parser → returns structured tasks
3. Tasks inserted into task list
4. Overlay notification: "Add details?" per task

### Parsing Rules
- Split input by commas and newlines
- Each segment → one task
- **Priority detection:** if "by [day/date]" or "urgent" or "asap" → high; else medium
- **Deadline detection:** parse "by Friday", "by tomorrow", "by Monday" → set deadline
- All other fields (timeEstimate, notes) → nil/blank

### Detail Overlay
- Small non-intrusive corner notification (bottom-right of notch)
- Per-task: "Add details to '[task title]'?" with Yes/No
- Yes → inline edit mode on that task card
- No → dismiss, task saved with blanks

### AI Tier Architecture

```
VoiceInputManager
       │
       ▼
  AIParserService (protocol)
       │
   ┌───┴──────────────┐
   │                  │
AppleIntelligenceProvider  OllamaProvider  CloudAPIProvider
(FoundationModels)    (localhost:11434)  (user-configured)
```

**Priority order:** Apple Intelligence → Ollama → Cloud API → error

**Apple Intelligence (Default):**
- Framework: `FoundationModels` / `AppleIntelligence`
- Mode: on-device
- Requires: macOS 26 Tahoe+, Apple Silicon

**Ollama (Local Fallback):**
- Endpoint: `http://localhost:11434/api/generate`
- Model: user-configurable (default: `llama3.2`)
- Triggered: when Apple Intelligence unavailable

**Cloud API (Remote Fallback):**
- Provider: user-configurable (OpenAI / Anthropic / OpenAI-compatible)
- Auth: API key stored in Keychain
- Triggered: when Apple Intelligence and Ollama both unavailable

**Settings panel (in SettingsView):**
- Dropdown: AI provider order (enable/disable each tier)
- API key field (masked) for cloud providers
- Ollama endpoint URL field
- Test connection button

**Files:**
- Create: `boringNotch/services/ai/AIParserService.swift` (protocol + factory)
- Create: `boringNotch/services/ai/AppleIntelligenceProvider.swift`
- Create: `boringNotch/services/ai/OllamaProvider.swift`
- Create: `boringNotch/services/ai/CloudAPIProvider.swift`
- Modify: `boringNotch/managers/VoiceInputManager.swift`

---

## Clipboard History

### Storage
- **Database:** SQLite.swift
- **Table:** `clipboard_items (id TEXT PRIMARY KEY, content TEXT, timestamp INTEGER, pinned INTEGER)`
- **Limit:** 50 items, prune oldest on insert

### Display
- Horizontal card row (same as other Files tab cards)
- Each card: truncated text + relative time ("2m ago", "Yesterday")
- Pinned items float to front

### Interaction
- Tap → copy to `NSPasteboard.general`, show brief checkmark animation
- Swipe left on card → pin/unpin
- No delete for now (pinned items stay)

**Files:**
- Create: `boringNotch/managers/ClipboardManager.swift`
- Modify: `boringNotch/components/Tabs/AxisFilesView.swift`

---

## Pomodoro Timer

### UI
- Circular progress ring (stroke, not fill)
- Countdown text in center: "25:00"
- States: idle, running, paused, break

### Break Support
- After 4 pomodoros → suggest 15-min break
- Break timer: separate card state

### End Trigger
- Border flash: `Color.red` pulse animation on notch (2 flashes, 200ms each)
- Chime: short (~0.5s), soft attack, pleasant tone — design TBD with user testing (target: CleanMyMac-style clean sound)
- Live Activity: `ActivityKit` token appears in menu bar with countdown

### Live Activity
- `PomodoroLiveActivity` widget in menu bar
- Shows: timer icon + remaining time
- Tap → opens notch to Pomodoro card
- Dismisses when timer resets or completes

**Files:**
- Create: `boringNotch/managers/PomodoroManager.swift`
- Create: `boringNotch/components/Live activities/PomodoroLiveActivity.swift`
- Modify: `boringNotch/components/Tabs/AxisToolsView.swift`

---

## Calendar Integration

### Today's Events
- Already present in `NotchHomeView` via `CalendarManager` + `EventKit`
- Events shown in home tab below calendar date picker
- No changes needed for v1

### Countdown Timers
- For events within next 2 hours: show "in 45m" countdown next to event
- Implemented in `EventListView` event row

**Files:**
- Modify: `boringNotch/components/Calendar/BoringCalendar.swift`

---

## File Structure

```
boringNotch/
├── managers/
│   ├── VoiceInputManager.swift       [NEW]
│   ├── ClipboardManager.swift        [NEW]
│   └── PomodoroManager.swift         [NEW]
├── services/ai/
│   ├── AIParserService.swift         [NEW - protocol]
│   ├── AppleIntelligenceProvider.swift [NEW]
│   ├── OllamaProvider.swift           [NEW]
│   └── CloudAPIProvider.swift         [NEW]
├── components/
│   ├── Tabs/
│   │   ├── AxisTasksView.swift       [MODIFY - horizontal cards]
│   │   ├── AxisFilesView.swift       [MODIFY - horizontal cards]
│   │   └── AxisToolsView.swift       [MODIFY - horizontal cards]
│   ├── Live activities/
│   │   ├── PomodoroLiveActivity.swift [NEW]
│   │   └── (existing LiveActivityModifier)
│   └── Notch/
│       └── BoringHeader.swift        [MODIFY - add mic button]
├── extensions/
│   └── PanGesture.swift              [MODIFY - no change needed, bug is in usage pattern]
└── boringNotchApp.swift              [MODIFY - register Live Activity]
```

---

## Out of Scope for v1

- Work profiles (Work/Personal/Focus tab configs)
- Gesture tab-switching (swipe left/right to change tabs)
- Blueprint grid background
- AirDrop integration
- Reminders sync
- Backend proxy for AI calls

---

## Dependencies

| Package | Use |
|---------|-----|
| SQLite.swift | Clipboard persistence |
| KeyboardShortcuts | Voice input hotkey |
| Defaults | Settings storage |
| (existing Speech framework) | Voice recognition |
| (existing EventKit) | Calendar |
| (existing ActivityKit) | Pomodoro Live Activity |
| (existing FoundationModels) | Apple Intelligence |

---

## Privacy

- All AI tier options are local or user-configured external service
- Clipboard history stored locally only
- Voice transcription on-device via SFSpeechRecognizer
- No telemetry or external data collection
