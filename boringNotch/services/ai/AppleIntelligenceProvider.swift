//
//  AppleIntelligenceProvider.swift
//  boringNotch
//
//  On-device AI parsing via FoundationModels (macOS 26 Tahoe)
//

import Foundation

final class AppleIntelligenceProvider: AIParserProvider {
    var name: String { "Apple Intelligence" }

    func parse(transcription: String) async throws -> [ParsedTask] {
        // FoundationModels integration - requires macOS 26 Tahoe
        // For now, fall back to keyword-based parsing
        // Real implementation would use ModelContext + TextPrompt
        throw AIParserError.notAvailable
    }
}
