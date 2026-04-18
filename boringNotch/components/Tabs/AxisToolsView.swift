//
//  AxisToolsView.swift
//  boringNotch
//
//  Quick utilities for the notch
//

import SwiftUI
import Defaults

struct AxisToolsView: View {
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                NoteCard()
                StopwatchCard()
                PomodoroCard()
                WaterTrackerCard()
                AppLauncherCard()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollTargetBehavior(.viewAligned)
        .sensoryFeedback(.alignment, trigger: 0)
    }
}

// MARK: - Note Card

struct NoteCard: View {
    @State private var isExpanded: Bool = false
    @State private var noteText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.yellow)
                Text("Note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }

            if isExpanded {
                TextEditor(text: $noteText)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                    .frame(height: 80)
                    .focused($isFocused)
                    .onChange(of: noteText) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "quickNote")
                    }
            } else {
                Text(noteText.isEmpty ? "Tap to add note..." : noteText)
                    .font(.system(size: 11))
                    .foregroundColor(noteText.isEmpty ? .gray : .white)
                    .lineLimit(2)
                    .frame(height: 36)
            }
        }
        .padding(12)
        .frame(width: 160, height: isExpanded ? 140 : 80)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
            if isExpanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
        .onAppear {
            noteText = UserDefaults.standard.string(forKey: "quickNote") ?? ""
        }
    }
}

// MARK: - Stopwatch Card

struct StopwatchCard: View {
    @State private var timerSeconds: Int = 0
    @State private var isRunning: Bool = false
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "stopwatch")
                    .foregroundColor(.orange)
                Text("Stopwatch")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Text(formatTime(timerSeconds))
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                Button(action: toggleTimer) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: resetTimer) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.gray)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 160, height: 120)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private func toggleTimer() {
        if isRunning {
            timerTask?.cancel()
            timerTask = nil
            isRunning = false
        } else {
            isRunning = true
            timerTask = Task {
                while !Task.isCancelled && isRunning {
                    try? await Task.sleep(for: .seconds(1))
                    if !Task.isCancelled {
                        timerSeconds += 1
                    }
                }
            }
        }
    }

    private func resetTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerSeconds = 0
        isRunning = false
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Pomodoro Card

struct PomodoroCard: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.red)
                Text("Pomodoro")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text(formatTime(pomodoro.secondsRemaining))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)

            // Session dots
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < pomodoro.sessionsCompleted % 4 ? Color.red : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Button(action: pomodoro.toggle) {
                    Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: pomodoro.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.gray)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(width: 160, height: 160)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private var progress: Double {
        Double(pomodoro.secondsRemaining) / Double(pomodoro.sessionDuration)
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Water Tracker Card

struct WaterTrackerCard: View {
    @State private var glasses: Int = 0
    private let maxGlasses = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                Text("Water")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
            }

            HStack(spacing: 16) {
                Button(action: { if glasses > 0 { glasses -= 1 } }) {
                    Image(systemName: "minus")
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                VStack(spacing: 2) {
                    Text("\(glasses)/\(maxGlasses)")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    Text("glasses")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }

                Button(action: { if glasses < maxGlasses { glasses += 1 } }) {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(glasses) / CGFloat(maxGlasses), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .frame(width: 160, height: 120)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - App Launcher Card

struct AppLauncherCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "apps.fill")
                    .foregroundColor(.green)
                Text("Apps")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
            }

            HStack(spacing: 8) {
                AxisAppButton(icon: "safari", name: "Safari") {
                    openApp("Safari")
                }
                AxisAppButton(icon: "terminal", name: "Terminal") {
                    openApp("Terminal")
                }
                AxisAppButton(icon: "finder", name: "Finder") {
                    openApp("Finder")
                }
            }
        }
        .padding(12)
        .frame(width: 160, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private func openApp(_ name: String) {
        NSWorkspace.shared.launchApplication(name)
    }
}

// MARK: - Axis App Button

struct AxisAppButton: View {
    let icon: String
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(name)
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
    AxisToolsView()
        .frame(width: 400, height: 200)
        .background(Color.black)
}
