//
//  VoiceInputManager.swift
//  boringNotch
//
//  Handles voice input with toggle mode and SFSpeechRecognizer
//  - Real-time transcription display
//  - Visual waveform/pulse animation while recording
//  - Confirm transcription before AI parsing
//

import Foundation
import Speech
import AVFoundation
import Combine
import AppKit
import SwiftUI

final class VoiceInputManager: ObservableObject {
    static let shared = VoiceInputManager()

    @Published var isListening: Bool = false
    @Published var transcription: String = ""
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0.0

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var levelTimer: Timer?
    private var lastTranscriptionUpdate: Date = Date()

    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func toggle() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition unavailable"
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Failed to create recognition request"
            return
        }

        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
            self.updateAudioLevel(buffer: buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Failed to start audio engine: \(error)"
            return
        }

        isListening = true
        transcription = ""
        lastTranscriptionUpdate = Date()
        startLevelMonitoring()

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcription = result.bestTranscription.formattedString
                    self.lastTranscriptionUpdate = Date()
                }
            }

            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    // Auto-stop after 2 seconds of silence
                    if self.isListening && Date().timeIntervalSince(self.lastTranscriptionUpdate) > 2.0 {
                        self.stopListening()
                    }
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        stopLevelMonitoring()

        if !transcription.isEmpty {
            NotificationCenter.default.post(
                name: .voiceInputCompleted,
                object: nil,
                userInfo: [
                    "transcription": transcription,
                    "timestamp": Date()
                ]
            )
        }
    }

    func confirmTranscription() {
        // This is called when user confirms the transcription
        // The notification is posted automatically in stopListening
    }

    func cancelListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        transcription = ""
        stopLevelMonitoring()
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let averageLevel = sum / Float(frameLength)
        let normalizedLevel = min(max(averageLevel * 5, 0), 1)

        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
        }
    }

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            // Decay audio level when no new data
            DispatchQueue.main.async {
                self?.audioLevel *= 0.9
            }
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
    }
}

extension Notification.Name {
    static let voiceInputCompleted = Notification.Name("voiceInputCompleted")
}

// MARK: - Voice Input Waveform View

struct VoiceInputWaveformView: View {
    @ObservedObject var voiceManager = VoiceInputManager.shared

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: voiceManager.audioLevel)
            }
        }
        .frame(height: 16)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxAddition: CGFloat = 12
        let variation = sin(Double(index) * .pi / 2) * 0.5 + 0.5
        return baseHeight + CGFloat(voiceManager.audioLevel) * maxAddition * CGFloat(variation)
    }
}

// MARK: - Voice Input Button with Animation

struct VoiceInputButton: View {
    @ObservedObject var voiceManager = VoiceInputManager.shared

    var body: some View {
        ZStack {
            if voiceManager.isListening {
                // Pulsing ring
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 2)
                    .frame(width: 28, height: 28)
                    .scaleEffect(voiceManager.isListening ? 1.5 : 1)
                    .opacity(voiceManager.isListening ? 0 : 1)
                    .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: voiceManager.isListening)
            }

            Button(action: { voiceManager.toggle() }) {
                ZStack {
                    Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 11))
                        .foregroundColor(voiceManager.isListening ? .red : .gray)

                    if voiceManager.isListening {
                        VoiceInputWaveformView()
                            .offset(y: 12)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
