//
//  AudioPlayer.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 09/08/24.
//

import Foundation
import AppKit

final class AudioPlayer {
    static let shared = AudioPlayer()

    private init() {}

    func play(fileName: String, fileExtension: String) {
        NSSound(contentsOf: Bundle.main.url(forResource: fileName, withExtension: fileExtension)!, byReference: false)?.play()
    }

    func playChime() {
        NSSound(named: "Glass")?.play()
    }
}
