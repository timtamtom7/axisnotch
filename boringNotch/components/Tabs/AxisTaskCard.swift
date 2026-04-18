//
//  AxisTaskCard.swift
//  boringNotch
//
//  Compact task card for horizontal card row (100pt height)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                        .foregroundColor(task.isCompleted ? .green : .gray)
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(task.priority.color)
                    .frame(width: 6, height: 6)

                Text(task.title)
                    .font(.system(size: 11))
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .white)
                    .lineLimit(isExpanded ? 4 : 2)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Spacer()
                Button(action: onExpandDetails) {
                    Text("Add details")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                Spacer()
            } else {
                Spacer()
                if let estimate = task.timeEstimate {
                    Text("\(estimate)m")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
