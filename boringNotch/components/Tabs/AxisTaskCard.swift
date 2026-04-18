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
