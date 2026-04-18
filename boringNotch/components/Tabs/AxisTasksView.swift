//
//  AxisTasksView.swift
//  boringNotch
//
//  AI-powered task management for the notch
//

import SwiftUI
import Defaults

struct AxisTasksView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @State private var taskInput: String = ""
    @State private var tasks: [AxisTask] = []
    @State private var isProcessing: Bool = false
    @State private var isListening: Bool = false
    @State private var expandedTaskId: UUID? = nil

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

            // Horizontal Task Cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(tasks) { task in
                        AxisTaskCard(
                            task: task,
                            isExpanded: expandedTaskId == task.id,
                            onTap: {
                                toggleExpand(task.id)
                            },
                            onToggle: {
                                toggleTask(task)
                            },
                            onDelete: {
                                deleteTask(task)
                            },
                            onExpandDetails: {
                                showDetailOverlay(task)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollTargetBehavior(.viewAligned)

            if tasks.isEmpty {
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
    }

    private func toggleExpand(_ taskId: UUID) {
        if expandedTaskId == taskId {
            expandedTaskId = nil
        } else {
            expandedTaskId = taskId
        }
    }

    private func showDetailOverlay(_ task: AxisTask) {
        // Placeholder for detail overlay
    }

    private func parseTasks() {
        guard !taskInput.isEmpty else { return }
        isProcessing = true

        // Simple parsing - split by comma or new line
        let parts = taskInput.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for (index, part) in parts.enumerated() {
            let task = AxisTask(
                title: part,
                priority: index == 0 ? .high : .medium,
                isCompleted: false
            )
            tasks.append(task)
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
}

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

struct AxisTaskRow: View {
    let task: AxisTask
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
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

            Spacer()

            Circle()
                .fill(task.priority.color)
                .frame(width: 8, height: 8)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AxisTasksView()
        .frame(width: 200, height: 300)
        .background(Color.black)
}
