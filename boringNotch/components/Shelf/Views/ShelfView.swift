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
        VStack(alignment: .leading, spacing: 6) {
            // Files section — fixed height row
            HStack(spacing: 12) {
                FileShareView()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(height: 100)
                    .environmentObject(vm)

                panel
                    .frame(height: 100)
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
                        .font(.system(size: 9))
                        .foregroundColor(.gray)

                    Text("Clipboard")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)

                    Spacer()

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)

                    TextField("", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9))
                        .frame(width: 70)
                        .foregroundColor(.white)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
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

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Rich preview based on item kind
            Group {
                switch item.kind {
                case .image:
                    imagePreview
                case .url:
                    urlPreview
                case .file:
                    filePreview
                case .code:
                    codePreview
                case .text:
                    textPreview
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack {
                // Kind indicator
                Image(systemName: kindIcon)
                    .font(.system(size: 7))
                    .foregroundColor(kindColor)

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
        .padding(6)
        .frame(width: isExpanded ? 150 : 110, height: isExpanded ? 100 : 70)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.isPinned ? Color.orange.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1)
        )
        .onTapGesture {
            onCopy()
        }
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .contextMenu {
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button(action: onPin) {
                Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            Divider()
            Button(role: .destructive, action: {}) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Preview Views

    @ViewBuilder
    private var imagePreview: some View {
        if let imageData = item.imageData,
           let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: isExpanded ? 60 : 40)
                .cornerRadius(4)
        } else {
            Image(systemName: "photo")
                .font(.system(size: 20))
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private var urlPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Favicon placeholder
            Image(systemName: "globe")
                .font(.system(size: 12))
                .foregroundColor(.blue)

            Text(item.content)
                .font(.system(size: 9))
                .foregroundColor(.white)
                .lineLimit(isExpanded ? 3 : 2)
                .truncationMode(.middle)
        }
    }

    @ViewBuilder
    private var filePreview: some View {
        HStack(spacing: 4) {
            Image(nsImage: fileIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(fileName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if isExpanded {
                    Text(filePath)
                        .font(.system(size: 7))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    @ViewBuilder
    private var codePreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(item.content)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color.green.opacity(0.9))
                .lineLimit(isExpanded ? 6 : 3)
        }
    }

    @ViewBuilder
    private var textPreview: some View {
        Text(item.content)
            .font(.system(size: 10))
            .foregroundColor(.white)
            .lineLimit(isExpanded ? 6 : 3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var fileIcon: NSImage {
        let path = (item.content as NSString).expandingTildeInPath
        return NSWorkspace.shared.icon(forFile: path)
    }

    private var fileName: String {
        let path = (item.content as NSString).expandingTildeInPath
        return (path as NSString).lastPathComponent
    }

    private var filePath: String {
        let path = (item.content as NSString).expandingTildeInPath
        let dir = (path as NSString).deletingLastPathComponent
        let homeDir = NSHomeDirectory()
        return dir.replacingOccurrences(of: homeDir, with: "~")
    }

    private var kindIcon: String {
        switch item.kind {
        case .text: return "doc.text"
        case .image: return "photo"
        case .url: return "link"
        case .file: return "folder"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }

    private var kindColor: Color {
        switch item.kind {
        case .text: return .gray
        case .image: return .purple
        case .url: return .blue
        case .file: return .yellow
        case .code: return .green
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
