//
//  ShelfView.swift
//  boringNotch
//
//  Shelf tab: file drop zone + clipboard history
//

import SwiftUI
import AppKit
import Defaults

struct ShelfView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject var tvm = ShelfStateViewModel.shared
    @StateObject var selection = ShelfSelectionModel.shared
    @StateObject private var quickLookService = QuickLookService()
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @State private var searchQuery: String = ""

    @Default(.showClipboardHistory) private var showClipboardHistory

    private let spacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Files section
            HStack(spacing: 12) {
                FileShareView()
                    .aspectRatio(1, contentMode: .fit)
                    .environmentObject(vm)

                panel
                    .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                        handleDrop(providers: providers)
                    }
            }

            if showClipboardHistory {
                Divider()
                    .background(Color.white.opacity(0.1))

                // Clipboard section
                HStack(spacing: 6) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)

                    Text("Clipboard")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)

                    Spacer()

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)

                    TextField("", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .frame(width: 80)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filteredClipboard) { item in
                            ClipboardCard(item: item) {
                                clipboardManager.copyToClipboard(item)
                            } onPin: {
                                clipboardManager.togglePinned(item)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: selection.selectedIDs) {
            updateQuickLookSelection()
        }
        .quickLookPresenter(using: quickLookService)
    }

    private var filteredClipboard: [ClipboardItem] {
        if searchQuery.isEmpty {
            return clipboardManager.items
        }
        return clipboardManager.items.filter {
            $0.content.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !selection.isDragging else { return false }
        vm.dropEvent = true
        ShelfStateViewModel.shared.load(providers)
        return true
    }

    private func updateQuickLookSelection() {
        guard quickLookService.isQuickLookOpen && !selection.selectedIDs.isEmpty else { return }
        let selectedItems = selection.selectedItems(in: tvm.items)
        let urls: [URL] = selectedItems.compactMap { item in
            if let fileURL = item.fileURL { return fileURL }
            if case .link(let url) = item.kind { return url }
            return nil
        }
        if !urls.isEmpty {
            quickLookService.updateSelection(urls: urls)
        }
    }

    var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                vm.dragDetectorTargeting
                    ? Color.accentColor.opacity(0.9)
                    : Color.white.opacity(0.1),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
            )
            .overlay {
                content
                    .padding()
            }
            .transaction { transaction in
                transaction.animation = vm.animation
            }
            .contentShape(Rectangle())
            .onTapGesture { selection.clear() }
    }

    var content: some View {
        Group {
            if tvm.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .symbolVariant(.fill)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white, .gray)
                        .imageScale(.large)
                    Text("Drop files here")
                        .foregroundStyle(.gray)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.medium)
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: spacing) {
                        ForEach(tvm.items) { item in
                            ShelfItemView(item: item)
                                .environmentObject(quickLookService)
                        }
                    }
                }
                .padding(-spacing)
                .scrollIndicators(.never)
                .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                    handleDrop(providers: providers)
                }
            }
        }
        .onAppear {
            ShelfStateViewModel.shared.cleanupInvalidItems()
        }
    }
}

// MARK: - Clipboard Card (compact, for Shelf tab)

struct ClipboardCard: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onPin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.content)
                .font(.system(size: 10))
                .foregroundColor(.white)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack {
                Text(formatTime(item.timestamp))
                    .font(.system(size: 8))
                    .foregroundColor(.gray)

                Spacer()

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 120, height: 80)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
