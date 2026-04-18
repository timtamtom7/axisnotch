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
                        Image(systemName: VoiceInputManager.shared.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 11))
                            .foregroundColor(VoiceInputManager.shared.isListening ? .red : .gray)
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
                            onExpandDetails: { showDetailOverlay(task) }
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
            NotificationCenter.default.publisher(for: .voiceInputCompleted)
                .compactMap { $0.userInfo?["transcription"] as? String }
                .sink { transcription in
                    Task { await parseTasksFromAI(transcription: transcription) }
                }
                .store(in: &cancellables)
        }
        .overlay(alignment: .bottom) {
            if detailOverlayVisible, let task = pendingDetailTask {
                detailPromptOverlay(for: task)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: detailOverlayVisible)
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
                    tasks.append(AxisTask(title: p.title, priority: p.priority, isCompleted: false, timeEstimate: p.timeEstimate))
                }
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
        taskInput = ""
    }

    private func toggleTask(_ t: AxisTask) {
        if let i = tasks.firstIndex(where: { $0.id == t.id }) { tasks[i].isCompleted.toggle() }
    }

    private func deleteTask(_ t: AxisTask) { tasks.removeAll { $0.id == t.id } }

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

struct AxisTask: Identifiable {
    public let id = UUID()
    var title: String
    var priority: TaskPriority = .medium
    var isCompleted: Bool = false
    var timeEstimate: Int?
}

enum TaskPriority: String {
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
                Spacer()
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").font(.system(size: 11)).foregroundColor(task.isCompleted ? .green : .gray)
                }.buttonStyle(.plain)
            }

            if isExpanded {
                Divider().background(Color.gray.opacity(0.2))
                Button(action: onExpandDetails) { Text("Add details").font(.system(size: 10)).foregroundColor(.blue) }.buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 130, height: 110)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Pomodoro Tool Card (110pt)

struct PomodoroToolCard: View {
    @ObservedObject private var p = PomodoroManager.shared

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
    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "note.text").font(.system(size: 9)).foregroundColor(.yellow)
                Text("Note").font(.system(size: 9, weight: .semibold)).foregroundColor(.gray)
            }

            Spacer()

            Text(text.isEmpty ? "Tap to note..." : text)
                .font(.system(size: 10))
                .foregroundColor(text.isEmpty ? .gray : .white)
                .lineLimit(4)
        }
        .padding(8)
        .frame(width: 110, height: 110)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
        .onTapGesture { }
        .onChange(of: text) { _, n in UserDefaults.standard.set(n, forKey: "quickNote") }
        .onAppear { text = UserDefaults.standard.string(forKey: "quickNote") ?? "" }
    }
}

#Preview {
    AxisTasksView()
        .frame(width: 400, height: 180)
        .background(Color.black)
}
