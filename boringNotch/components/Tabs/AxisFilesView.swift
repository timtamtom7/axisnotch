//
//  AxisFilesView.swift
//  boringNotch
//
//  Horizontal clipboard card row for the notch
//

import SwiftUI
import Defaults

struct AxisFilesView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @State private var searchQuery: String = ""

    var body: some View {
        VStack(spacing: 12) {
            // Search bar (non-scrolling)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search clipboard...", text: $searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)

            // Horizontal clipboard cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(filteredItems) { item in
                        AxisClipboardCard(item: item) {
                            clipboardManager.copyToClipboard(item)
                        } onPin: {
                            clipboardManager.togglePinned(item)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)

            // Quick actions as horizontal buttons
            HStack(spacing: 12) {
                AxisQuickAction(icon: "doc.on.clipboard", label: "Copy") {
                    // Copy action
                }
                AxisQuickAction(icon: "folder", label: "Files") {
                    // Files action
                }
                AxisQuickAction(icon: "globe", label: "Search") {
                    // Search action
                }
                AxisQuickAction(icon: "pin", label: "Pinned") {
                    // Show pinned items
                }
            }
        }
        .padding()
    }

    private var filteredItems: [ClipboardItem] {
        if searchQuery.isEmpty {
            return clipboardManager.items
        }
        return clipboardManager.items.filter {
            $0.content.localizedCaseInsensitiveContains(searchQuery)
        }
    }
}

struct AxisClipboardCard: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onPin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Content
            Text(item.content)
                .font(.system(size: 11))
                .lineLimit(3)
                .foregroundColor(.white)
                .frame(width: 120, alignment: .leading)

            Spacer()

            // Bottom row: timestamp + actions
            HStack {
                Text(formatTime(item.timestamp))
                    .font(.system(size: 9))
                    .foregroundColor(.gray)

                Spacer()

                // Pin indicator / button
                if item.isPinned {
                    Button(action: onPin) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                }

                // Copy button
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(item.isPinned ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            onCopy()
        }
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
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AxisFilesView()
        .frame(width: 300, height: 200)
        .background(Color.black)
}