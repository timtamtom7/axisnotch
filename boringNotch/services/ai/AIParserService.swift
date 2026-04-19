//
//  AIParserService.swift
//  boringNotch
//
//  Protocol and factory for AI task parsing providers
//

import Foundation

protocol AIParserProvider {
    var name: String { get }
    func parse(transcription: String) async throws -> [ParsedTask]
}

struct ParsedTask: Identifiable {
    public let id = UUID()
    var title: String
    var priority: TaskPriority
    var deadline: Date?
    var timeEstimate: Int?
}

enum AIParserError: Error, LocalizedError {
    case notAvailable
    case parsingFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "AI provider not available"
        case .parsingFailed(let msg): return "Parsing failed: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        }
    }
}

final class AIParserService {
    static let shared = AIParserService()

    private var providers: [AIParserProvider] = []

    private init() {
        setupProviders()
    }

    private func setupProviders() {
        providers.append(AppleIntelligenceProvider())
        providers.append(OllamaProvider())
        providers.append(CloudAPIProvider())
    }

    func parse(transcription: String) async throws -> [ParsedTask] {
        for provider in providers {
            do {
                let tasks = try await provider.parse(transcription: transcription)
                return tasks
            } catch {
                print("AIParserService: \(provider.name) failed, trying next: \(error)")
                continue
            }
        }
        throw AIParserError.notAvailable
    }
}
