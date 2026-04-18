//
//  PomodoroLiveActivity.swift
//  boringNotch
//
//  Compact Pomodoro timer display when notch is closed
//

import SwiftUI
import Defaults

struct PomodoroLiveActivity: View {
    @ObservedObject var pomodoroManager = PomodoroManager.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @EnvironmentObject var vm: BoringViewModel

    @State private var pulseAnimation: Bool = false

    var body: some View {
        if pomodoroManager.showLiveActivityCompact && Defaults[.showLiveActivity] {
            Button(action: {
                openPomodoroTab()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: pomodoroManager.isBreak ? "pause.circle.fill" : "timer")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(pomodoroManager.isBreak ? .green : .red)
                        .opacity(pulseAnimation ? 0.7 : 1.0)

                    Text(pomodoroManager.formattedTime)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.3))

                            Capsule()
                                .fill(pomodoroManager.isBreak ? Color.green : Color.red)
                                .frame(width: geo.size.width * pomodoroManager.progress)
                        }
                    }
                    .frame(width: 40, height: 4)

                    // Session indicator
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index < pomodoroManager.sessionsCompleted % 4 ? Color.red : Color.gray.opacity(0.3))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            Capsule()
                                .stroke(pomodoroManager.isBreak ? Color.green.opacity(0.5) : Color.red.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
    }

    private func openPomodoroTab() {
        coordinator.currentView = .tasks
        if vm.notchState == .closed {
            withAnimation {
                vm.open()
            }
        }
    }
}

struct PomodoroCompactView: View {
    @ObservedObject var pomodoroManager = PomodoroManager.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: pomodoroManager.isBreak ? "pause.circle.fill" : "timer")
                .font(.system(size: 10))
                .foregroundColor(pomodoroManager.isBreak ? .green : .red)

            Text(pomodoroManager.formattedTime)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    VStack {
        PomodoroLiveActivity()
        Spacer()
    }
    .padding()
    .background(Color.black)
    .environmentObject(BoringViewModel())
}