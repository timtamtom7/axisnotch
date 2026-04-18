//
//  AxisTasksView.swift
//  boringNotch
//
//  AI-powered task management + productivity tools for the notch
//

import SwiftUI
import Defaults
import Combine

struct AxisTasksView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @State private var taskInput: String = ""
    @State private var tasks: [AxisTask] = []
    @State private var isProcessing: Bool = false
    @State private var expandedTaskId: UUID? = nil
    @State private var cancellables = Set<AnyCancellable>()
    @State private var pendingDetailTask: AxisTask? = nil
    @State private var detailOverlayVisible: Bool = false

    @Default(.showVoiceInput) private var showVoiceInput
    @Default(.showPomodoro) private var showPomodoro
    @Default(.showStopwatch) private var showStopwatch
    @Default(.showQuickNote) private var showQuickNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Compact input bar
            HStack(spacing: 6) {
                if showVoiceInput {
                    Button(action: { VoiceInputManager.shared.toggle() }) {
                        ZStack {
                            Image(systemName: VoiceInputManager.shared.isListening ? "mic.fill" : "mic")
                                .font(.system(size: 11))
                                .foregroundColor(VoiceInputManager.shared.isListening ? .red : .gray)

                            if VoiceInputManager.shared.isListening {
                                // Pulsing animation
                                Circle()
                                    .stroke(Color.red.opacity(0.5), lineWidth: 2)
                                    .frame(width: 20, height: 20)
                                    .scaleEffect(VoiceInputManager.shared.isListening ? 1.5 : 1)
                                    .opacity(VoiceInputManager.shared.isListening ? 0 : 1)
                                    .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: VoiceInputManager.shared.isListening)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                TextField("Add task...", text: $taskInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)

                Button(action: parseTasks) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(taskInput.isEmpty ? .gray : .white)
                }
                .buttonStyle(.plain)
                .disabled(taskInput.isEmpty || isProcessing)

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.07))
            .cornerRadius(8)

            // Voice transcription display
            if showVoiceInput && !VoiceInputManager.shared.transcription.isEmpty {
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                    Text(VoiceInputManager.shared.transcription)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }

            // Card row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(tasks) { task in
                        AxisTaskCard(
                            task: task,
                            isExpanded: expandedTaskId == task.id,
                            onTap: { toggleExpand(task.id) },
                            onToggle: { toggleTask(task) },
                            onDelete: { deleteTask(task) },
                            onExpandDetails: { showDetailOverlay(task) },
                            onSaveDetails: { updatedTask in
                                updateTaskDetails(updatedTask)
                            }
                        )
                    }

                    if showPomodoro { PomodoroToolCard() }
                    if showStopwatch { StopwatchToolCard() }
                    if showQuickNote { NoteToolCard() }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)

            // Empty state
            if tasks.isEmpty && !showPomodoro && !showStopwatch && !showQuickNote {
                Text("No tasks — speak or type above")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onAppear {
            loadPersistedTasks()
            setupVoiceInputObserver()
        }
        .overlay(alignment: .bottom) {
            if detailOverlayVisible, let task = pendingDetailTask {
                detailPromptOverlay(for: task)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: detailOverlayVisible)
    }

    private func setupVoiceInputObserver() {
        NotificationCenter.default.publisher(for: .voiceInputCompleted)
            .compactMap { $0.userInfo?["transcription"] as? String }
            .sink { transcription in
                Task { await parseTasksFromAI(transcription: transcription) }
            }
            .store(in: &cancellables)
    }

    private func loadPersistedTasks() {
        if let data = UserDefaults.standard.data(forKey: "persistedAxisTasks"),
           let saved = try? JSONDecoder().decode([AxisTask].self, from: data) {
            tasks = saved
        }
    }

    private func persistTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: "persistedAxisTasks")
        }
    }

    private func toggleExpand(_ id: UUID) {
        expandedTaskId = (expandedTaskId == id) ? nil : id
    }

    private func showDetailOverlay(_ task: AxisTask) {
        pendingDetailTask = task
        detailOverlayVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            withAnimation { detailOverlayVisible = false; pendingDetailTask = nil }
        }
    }

    private func parseTasksFromAI(transcription: String) async {
        await MainActor.run { isProcessing = true }
        do {
            let parsed = try await AIParserService.shared.parse(transcription: transcription)
            await MainActor.run {
                for p in parsed {
                    let newTask = AxisTask(title: p.title, priority: p.priority, isCompleted: false, timeEstimate: p.timeEstimate, deadline: p.deadline)
                    tasks.append(newTask)
                }
                persistTasks()
                if let first = parsed.first { showDetailOverlay(tasks[tasks.count - parsed.count]) }
                isProcessing = false
            }
        } catch {
            await MainActor.run { isProcessing = false }
        }
    }

    private func parseTasks() {
        guard !taskInput.isEmpty else { return }
        let parts = taskInput.components(separatedBy: CharacterSet(charactersIn: ",\n")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for p in parts { tasks.append(AxisTask(title: p, priority: .medium, isCompleted: false)) }
        persistTasks()
        taskInput = ""
    }

    private func toggleTask(_ t: AxisTask) {
        if let i = tasks.firstIndex(where: { $0.id == t.id }) { tasks[i].isCompleted.toggle() }
        persistTasks()
    }

    private func deleteTask(_ t: AxisTask) { tasks.removeAll { $0.id == t.id }; persistTasks() }

    private func updateTaskDetails(_ updatedTask: AxisTask) {
        if let i = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            tasks[i] = updatedTask
            persistTasks()
        }
    }

    @ViewBuilder
    private func detailPromptOverlay(for task: AxisTask) -> some View {
        HStack(spacing: 10) {
            Text("'\(task.title)'?")
                .font(.system(size: 11))
                .foregroundColor(.white)
            Button("Details") { expandedTaskId = task.id; detailOverlayVisible = false }
                .buttonStyle(.plain).foregroundColor(.blue).font(.system(size: 11))
            Button("Skip") { detailOverlayVisible = false; pendingDetailTask = nil }
                .buttonStyle(.plain).foregroundColor(.gray).font(.system(size: 11))
        }
        .padding(10).background(Color.black.opacity(0.9)).cornerRadius(8)
    }
}

// MARK: - Model

struct AxisTask: Identifiable, Codable {
    public let id = UUID()
    var title: String
    var priority: TaskPriority = .medium
    var isCompleted: Bool = false
    var timeEstimate: Int?
    var deadline: Date?
}

enum TaskPriority: String, Codable {
    case high, medium, low
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

// MARK: - Task Card (110pt)

struct AxisTaskCard: View {
    let task: AxisTask
    let isExpanded: Bool
    let onTap: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onExpandDetails: () -> Void
    let onSaveDetails: (AxisTask) -> Void

    @State private var editingPriority: TaskPriority
    @State private var editingTimeEstimate: Int
    @State private var editingDeadline: Date
    @State private var showDatePicker: Bool = false

    init(task: AxisTask, isExpanded: Bool, onTap: @escaping () -> Void, onToggle: @escaping () -> Void, onDelete: @escaping () -> Void, onExpandDetails: @escaping () -> Void, onSaveDetails: @escaping (AxisTask) -> Void) {
        self.task = task
        self.isExpanded = isExpanded
        self.onTap = onTap
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.onExpandDetails = onExpandDetails
        self.onSaveDetails = onSaveDetails
        _editingPriority = State(initialValue: task.priority)
        _editingTimeEstimate = State(initialValue: task.timeEstimate ?? 30)
        _editingDeadline = State(initialValue: task.deadline ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(task.priority.color).frame(width: 5, height: 5)
                Text(task.title).font(.system(size: 11, weight: .medium)).foregroundColor(task.isCompleted ? .gray : .white).lineLimit(isExpanded ? 6 : 2)
                Spacer()
                Button(action: onDelete) { Image(systemName: "xmark").font(.system(size: 8)).foregroundColor(.gray.opacity(0.6)) }.buttonStyle(.plain)
            }

            Spacer()

            HStack {
                if let e = task.timeEstimate { Text("\(e)m").font(.system(size: 8)).foregroundColor(.gray) }
                if let d = task.deadline { Text(formatDate(d)).font(.system(size: 8)).foregroundColor(.blue) }
                Spacer()
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").font(.system(size: 11)).foregroundColor(task.isCompleted ? .green : .gray)
                }.buttonStyle(.plain)
            }

            if isExpanded {
                Divider().background(Color.gray.opacity(0.2))

                // Priority selector
                HStack(spacing: 4) {
                    Text("Priority:").font(.system(size: 8)).foregroundColor(.gray)
                    ForEach([TaskPriority.high, .medium, .low], id: \.self) { p in
                        Button(action: {
                            editingPriority = p
                            saveDetails()
                        }) {
                            Circle()
                                .fill(p.color)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(editingPriority == p ? Color.white : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Time estimate slider
                HStack(spacing: 4) {
                    Text("Time:").font(.system(size: 8)).foregroundColor(.gray)
                    Slider(value: Binding(
                        get: { Double(editingTimeEstimate) },
                        set: {
                            editingTimeEstimate = Int($0)
                            saveDetails()
                        }
                    ), in: 5...120, step: 5)
                    .frame(width: 60)
                    Text("\(editingTimeEstimate)m").font(.system(size: 8)).foregroundColor(.white)
                }

                // Deadline picker
                HStack(spacing: 4) {
                    Text("Due:").font(.system(size: 8)).foregroundColor(.gray)
                    DatePicker("", selection: $editingDeadline, displayedComponents: .date)
                        .labelsHidden()
                        .scaleEffect(0.5)
                        .onChange(of: editingDeadline) { _, _ in
                            saveDetails()
                        }
                }
            }
        }
        .padding(8)
        .frame(width: 130, height: isExpanded ? 160 : 110)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func saveDetails() {
        var updatedTask = task
        updatedTask.priority = editingPriority
        updatedTask.timeEstimate = editingTimeEstimate
        updatedTask.deadline = editingDeadline
        onSaveDetails(updatedTask)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Pomodoro Tool Card (110pt)

struct PomodoroToolCard: View {
    @ObservedObject private var p = PomodoroManager.shared
    @ObservedObject private var historyManager = PomodoroHistoryManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "timer").font(.system(size: 9)).foregroundColor(.red)
                Text("Pomodoro").font(.system(size: 9, weight: .semibold)).foregroundColor(.gray)
                Spacer()
                Circle().fill(p.isRunning ? Color.red : Color.clear).frame(width: 5, height: 5)
            }

            Spacer()

            Text(formatTime(p.secondsRemaining)).font(.system(size: 16, weight: .medium, design: .monospaced)).foregroundColor(.white)

            HStack(spacing: 4) {
                Button(action: p.toggle) {
                    Image(systemName: p.isRunning ? "pause.fill" : "play.fill").font(.system(size: 9)).foregroundColor(.white).frame(width: 22, height: 22).background(Color.white.opacity(0.15)).cornerRadius(5)
                }.buttonStyle(.plain)
                Button(action: p.reset) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 8)).foregroundColor(.gray).frame(width: 18, height: 18).background(Color.white.opacity(0.08)).cornerRadius(4)
                }.buttonStyle(.plain)
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { i in Circle().fill(i < p.sessionsCompleted % 4 ? Color.red : Color.gray.opacity(0.3)).frame(width: 4, height: 4) }
                }
            }

            Text("\(historyManager.todaySessions)/\(historyManager.weeklyGoal)")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(width: 130, height: 110)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Stopwatch Tool Card (110pt)

struct StopwatchToolCard: View {
    @State private var s: Int = 0
    @State private var running: Bool = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "stopwatch").font(.system(size: 9)).foregroundColor(.orange)
                Text("Stopwatch").font(.system(size: 9, weight: .semibold)).foregroundColor(.gray)
            }

            Spacer()

            Text(formatTime(s)).font(.system(size: 16, weight: .medium, design: .monospaced)).foregroundColor(.white)

            Button(action: running ? stop : start) {
                Image(systemName: running ? "pause.fill" : "play.fill").font(.system(size: 9)).foregroundColor(.white).frame(width: 22, height: 22).background(Color.white.opacity(0.15)).cornerRadius(5)
            }.buttonStyle(.plain)
        }
        .padding(8)
        .frame(width: 110, height: 110)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
    }

    private func start() {
        running = true
        task = Task {
            while !Task.isCancelled && running {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { s += 1 }
            }
        }
    }

    private func stop() {
        running = false; task?.cancel(); task = nil
    }

    private func formatTime(_ sec: Int) -> String {
        String(format: "%02d:%02d", sec / 60, sec % 60)
    }
}

// MARK: - Note Tool Card (110pt)

struct NoteToolCard: View {
    @State private var notes: [QuickNote] = []
    @State private var expandedNoteId: UUID? = nil
    @State private var showEditor: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "note.text").font(.system(size: 9)).foregroundColor(.yellow)
                Text("Notes").font(.system(size: 9, weight: .semibold)).foregroundColor(.gray)
                Spacer()
                Button(action: { showEditor = true }) {
                    Image(systemName: "plus").font(.system(size: 8)).foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if notes.isEmpty {
                Text("Tap + to add note")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            } else {
                ForEach(notes.prefix(2)) { note in
                    HStack(spacing: 4) {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.orange)
                        }
                        Text(note.title)
                            .font(.system(size: 9))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(8)
        .frame(width: 110, height: 110)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
        .onTapGesture { showEditor = true }
        .popover(isPresented: $showEditor, arrowEdge: .bottom) {
            NoteEditorPopover(notes: $notes)
        }
        .onAppear { loadNotes() }
    }

    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: "quickNotes"),
           let saved = try? JSONDecoder().decode([QuickNote].self, from: data) {
            notes = saved.sorted { $0.isPinned && !$1.isPinned }
        }
    }
}

// MARK: - Quick Note Model

struct QuickNote: Identifiable, Codable {
    public let id = UUID()
    var title: String
    var body: String
    var timestamp: Date
    var isPinned: Bool
}

// MARK: - Note Editor Popover

struct NoteEditorPopover: View {
    @Binding var notes: [QuickNote]
    @Environment(\.dismiss) private var dismiss
    @State private var newTitle: String = ""
    @State private var newBody: String = ""
    @State private var editingNoteId: UUID? = nil

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Notes")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }

            // Note list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(notes) { note in
                        NoteRow(note: note, onEdit: {
                            editingNoteId = note.id
                            newTitle = note.title
                            newBody = note.body
                        }, onDelete: {
                            notes.removeAll { $0.id == note.id }
                            saveNotes()
                        }, onTogglePin: {
                            if let i = notes.firstIndex(where: { $0.id == note.id }) {
                                notes[i].isPinned.toggle()
                                notes.sort { $0.isPinned && !$1.isPinned }
                                saveNotes()
                            }
                        })
                    }
                }
            }
            .frame(height: 150)

            Divider()

            // Add/Edit note
            VStack(spacing: 6) {
                TextField("Title", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))

                TextEditor(text: $newBody)
                    .font(.system(size: 11))
                    .frame(height: 60)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                Button(action: saveNote) {
                    Text(editingNoteId == nil ? "Add Note" : "Update Note")
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTitle.isEmpty && newBody.isEmpty)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    private func saveNote() {
        if let editId = editingNoteId {
            if let i = notes.firstIndex(where: { $0.id == editId }) {
                notes[i].title = newTitle
                notes[i].body = newBody
            }
        } else {
            let note = QuickNote(title: newTitle, body: newBody, timestamp: Date(), isPinned: false)
            notes.insert(note, at: 0)
        }
        saveNotes()
        newTitle = ""
        newBody = ""
        editingNoteId = nil
    }

    private func saveNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: "quickNotes")
        }
    }
}

struct NoteRow: View {
    let note: QuickNote
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.orange)
                }
                Text(note.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Text(formatDate(note.timestamp))
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
            }
            if !note.body.isEmpty {
                Text(note.body)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
        .contextMenu {
            Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
            Button(action: onTogglePin) { Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin") }
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    AxisTasksView()
        .frame(width: 400, height: 180)
        .background(Color.black)
}
