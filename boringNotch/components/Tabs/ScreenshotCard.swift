//
//  ScreenshotCard.swift
//  boringNotch
//
//  Screenshot card with mode selection and capture functionality
//

import SwiftUI
import Defaults

// MARK: - Screenshot Mode

enum ScreenshotMode: String, CaseIterable {
    case screen = "Screen"
    case selection = "Selection"
    case window = "Window"
}

// MARK: - Screenshot Card

struct ScreenshotCard: View {
    @State private var selectedMode: ScreenshotMode = .screen
    @State private var isCapturing: Bool = false
    @State private var lastCaptureTime: Date?
    @Default(.screenshotDestination) private var destination

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))
                Text("Screenshot")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Mode selector
            Picker("", selection: $selectedMode) {
                ForEach(ScreenshotMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .scaleEffect(0.6)
            .frame(height: 24)

            // Capture button
            Button(action: takeScreenshot) {
                HStack(spacing: 4) {
                    Image(systemName: isCapturing ? "checkmark" : "camera")
                        .font(.system(size: 12))
                    Text(isCapturing ? "Captured!" : "Capture")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white)
                .frame(width: 80, height: 28)
                .background(isCapturing ? Color.green.opacity(0.6) : Color.blue.opacity(0.4))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(isCapturing)
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func takeScreenshot() {
        isCapturing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCapturing = false
        }

        let modeFlag: String
        switch selectedMode {
        case .screen:
            modeFlag = "-m"
        case .selection:
            modeFlag = "-s"
        case .window:
            modeFlag = "-w"
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

        if destination == "clipboard" {
            task.arguments = [modeFlag, "-x", "-c"]
        } else {
            let timestamp = Int(Date().timeIntervalSince1970)
            let filename = "Screenshot_\(timestamp).png"
            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let filePath = desktopURL.appendingPathComponent(filename).path
            task.arguments = [modeFlag, filePath]
        }

        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            if destination == "clipboard" {
                AudioPlayer.shared.play(fileName: "shutter", fileExtension: "aiff")
            }
        } catch {
            print("Screenshot error: \(error)")
        }
    }
}
