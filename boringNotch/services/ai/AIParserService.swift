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

    // MARK: - Local parsing with detail extraction

    func parseWithDetails(transcription: String) -> [ParsedTask] {
        var tasks: [ParsedTask] = []

        // Split by common delimiters
        let parts = transcription.components(separatedBy: CharacterSet(charactersIn: ",\n."))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for part in parts {
            var task = ParsedTask(
                title: part,
                priority: extractPriority(from: part),
                deadline: extractDeadline(from: part),
                timeEstimate: extractTimeEstimate(from: part)
            )

            // Clean up title
            task.title = cleanTitle(task.title)

            if !task.title.isEmpty {
                tasks.append(task)
            }
        }

        return tasks
    }

    private func extractPriority(from text: String) -> TaskPriority {
        let lowercased = text.lowercased()

        if lowercased.contains("urgent") || lowercased.contains("asap") || lowercased.contains("critical") {
            return .high
        }

        if lowercased.contains("low priority") || lowercased.contains("whenever") || lowercased.contains("someday") {
            return .low
        }

        return .medium
    }

    private func extractDeadline(from text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let today = Date()

        // Check for "by tomorrow"
        if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }

        // Check for "by Monday", "by Tuesday", etc.
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for (index, day) in weekdays.enumerated() {
            if lowercased.contains("by \(day)") || lowercased.contains("\(day)") {
                let currentWeekday = calendar.component(.weekday, from: today)
                let targetWeekday = index + 2 // Sunday = 1, Monday = 2, etc.
                var daysToAdd = targetWeekday - currentWeekday
                if daysToAdd <= 0 { daysToAdd += 7 }
                return calendar.date(byAdding: .day, value: daysToAdd, to: today)
            }
        }

        // Check for "in X days"
        if let match = lowercased.range(of: "in (\\d+) days", options: .regularExpression) {
            let numberString = lowercased[match].filter { $0.isNumber }
            if let days = Int(numberString) {
                return calendar.date(byAdding: .day, value: days, to: today)
            }
        }

        // Check for "by end of week"
        if lowercased.contains("end of week") || lowercased.contains("eow") {
            return calendar.date(byAdding: .day, value: 5 - calendar.component(.weekday, from: today) + 7, to: today)
        }

        return nil
    }

    private func extractTimeEstimate(from text: String) -> Int? {
        let lowercased = text.lowercased()

        // Check for patterns like "30 minutes", "2 hours", "1h", "30m"
        if let hourMatch = lowercased.range(of: "(\\d+)h", options: .regularExpression) {
            let numberString = lowercased[hourMatch].filter { $0.isNumber }
            if let hours = Int(numberString) {
                return hours * 60
            }
        }

        if let minMatch = lowercased.range(of: "(\\d+)m(in)?", options: .regularExpression) {
            let matchedString = String(lowercased[minMatch])
            let numberString = matchedString.filter { $0.isNumber }
            if let minutes = Int(numberString) {
                return minutes
            }
        }

        if lowercased.contains("quick") || lowercased.contains("5 min") {
            return 5
        }

        if lowercased.contains("long") || lowercased.contains("hour") {
            return 60
        }

        return nil
    }

    private func cleanTitle(_ title: String) -> String {
        var cleaned = title

        // Remove priority keywords
        let priorityKeywords = ["urgent", "asap", "critical", "high priority", "low priority", "medium priority"]
        for keyword in priorityKeywords {
            cleaned = cleaned.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
        }

        // Remove time estimates
        cleaned = cleaned.replacingOccurrences(of: "\\d+h", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\d+min(utes)?", with: "", options: .regularExpression)

        // Remove deadline phrases
        let deadlineKeywords = ["by tomorrow", "by monday", "by tuesday", "by wednesday", "by thursday", "by friday", "by saturday", "by sunday", "end of week", "eow", "in \\d+ days"]
        for keyword in deadlineKeywords {
            cleaned = cleaned.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
