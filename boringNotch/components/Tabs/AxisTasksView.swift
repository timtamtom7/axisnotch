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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Voice input bar
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))

                TextField("Add task or tap mic...", text: $taskInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)

                Button(action: parseTasks) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(taskInput.isEmpty || isProcessing)

                Button(action: {
                    VoiceInputManager.shared.toggle()
                }) {
                    Image(systemName: VoiceInputManager.shared.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 12))
                        .foregroundColor(VoiceInputManager.shared.isListening ? .red : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)

            // Horizontal scroll: tasks + productivity tools
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    // Task cards
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

                    // Pomodoro card
                    CompactPomodoroCard()

                    // Stopwatch card
                    CompactStopwatchCard()

                    // Note card
                    CompactNoteCard()
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .sensoryFeedback(.alignment, trigger: 0)

            if tasks.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                        Text("No tasks — tap mic or type above")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        .overlay(alignment: .bottom) {
            if detailOverlayVisible, let task = pendingDetailTask {
                detailPromptOverlay(for: task)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: detailOverlayVisible)
    }

    private func toggleExpand(_ taskId: UUID) {
        expandedTaskId = (expandedTaskId == taskId) ? nil : taskId
    }

    private func showDetailOverlay(_ task: AxisTask) {
        pendingDetailTask = task
        detailOverlayVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                self.detailOverlayVisible = false
                self.pendingDetailTask = nil
            }
        }
    }

    private func parseTasksFromAI(transcription: String) async {
        await MainActor.run { isProcessing = true }
        do {
            let parsedTasks = try await AIParserService.shared.parse(transcription: transcription)
            await MainActor.run {
                let startIndex = tasks.count
                for parsed in parsedTasks {
                    tasks.append(AxisTask(
                        title: parsed.title,
                        priority: parsed.priority,
                        isCompleted: false,
                        timeEstimate: parsed.timeEstimate
                    ))
                }
                if !parsedTasks.isEmpty {
                    showDetailOverlay(tasks[startIndex])
                }
                isProcessing = false
            }
        } catch {
            await MainActor.run { isProcessing = false }
        }
    }

    private func parseTasks() {
        guard !taskInput.isEmpty else { return }
        isProcessing = true
        let parts = taskInput.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for (index, part) in parts.enumerated() {
            tasks.append(AxisTask(
                title: part,
                priority: index == 0 ? .high : .medium,
                isCompleted: false
            ))
        }
        taskInput = ""
        isProcessing = false
    }

    private func toggleTask(_ task: AxisTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
        }
    }

    private func deleteTask(_ task: AxisTask) {
        tasks.removeAll { $0.id == task.id }
    }

    @ViewBuilder
    private func detailPromptOverlay(for task: AxisTask) -> some View {
        HStack(spacing: 12) {
            Text("'\(task.title)'?")
                .font(.system(size: 11))
                .foregroundColor(.white)
            Button("Yes") {
                expandedTaskId = task.id
                detailOverlayVisible = false
            }
            .buttonStyle(.plain)
            .foregroundColor(.green)
            .font(.system(size: 11))
            Button("No") {
                detailOverlayVisible = false
                pendingDetailTask = nil
            }
            .buttonStyle(.plain)
            .foregroundColor(.gray)
            .font(.system(size: 11))
        }
        .padding(10)
        .background(Color.black.opacity(0.85))
        .cornerRadius(8)
    }
}

// MARK: - Task Model

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

// MARK: - Compact Pomodoro Card (120pt, for Tasks tab)

struct CompactPomodoroCard: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.red)
                    .font(.system(size: 10))
                Text("Pomodoro")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Circle()
                    .fill(pomodoro.isRunning ? Color.red : Color.clear)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            Text(formatTime(pomodoro.secondsRemaining))
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                Button(action: pomodoro.toggle) {
                    Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: pomodoro.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                // Session dots
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < pomodoro.sessionsCompleted % 4 ? Color.red : Color.white.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }

    private var progress: Double {
        Double(pomodoro.secondsRemaining) / Double(pomodoro.sessionDuration)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Compact Stopwatch Card (100pt)

struct CompactStopwatchCard: View {
    @State private var seconds: Int = 0
    @State private var running: Bool = false
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "stopwatch")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                Text("Stopwatch")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(formatTime(seconds))
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            Button(action: running ? stop : start) {
                Image(systemName: running ? "pause.fill" : "play.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 120, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }

    private func start() {
        running = true
        timerTask = Task {
            while !Task.isCancelled && running {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    seconds += 1
                }
            }
        }
    }

    private func stop() {
        running = false
        timerTask?.cancel()
        timerTask = nil
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - Compact Note Card (120pt, collapsed by default)

struct CompactNoteCard: View {
    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.yellow)
                    .font(.system(size: 10))
                Text("Note")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(text.isEmpty ? "Tap to note..." : text)
                .font(.system(size: 11))
                .foregroundColor(text.isEmpty ? .gray : .white)
                .lineLimit(3)
        }
        .padding(10)
        .frame(width: 120, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .onTapGesture {
            // Could expand to full note editor
        }
        .onChange(of: text) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "quickNote")
        }
        .onAppear {
            text = UserDefaults.standard.string(forKey: "quickNote") ?? ""
        }
    }
}

#Preview {
    AxisTasksView()
        .frame(width: 400, height: 200)
        .background(Color.black)
}
