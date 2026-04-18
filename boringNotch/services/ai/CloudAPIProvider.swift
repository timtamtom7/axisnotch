//
//  CloudAPIProvider.swift
//  boringNotch
//
//  Cloud AI parsing via OpenAI-compatible API
//

import Foundation
import Defaults

final class CloudAPIProvider: AIParserProvider {
    var name: String { "Cloud API" }

    func parse(transcription: String) async throws -> [ParsedTask] {
        let endpoint = Defaults[.cloudAPIEndpoint]
        guard !endpoint.isEmpty else {
            throw AIParserError.notAvailable
        }

        guard let url = URL(string: endpoint) else {
            throw AIParserError.networkError("Invalid API endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are a task parser. Parse the user input into tasks.
        Return ONLY a JSON array of objects with keys: title (string), priority ("high", "medium", "low"), deadline (ISO 8601 date string or null).
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcription]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let apiKey = Defaults[.cloudAPIKey]
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIParserError.networkError("Cloud API returned non-200")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIParserError.parsingFailed("Invalid Cloud API response")
        }

        return try parseTasksFromJSON(content)
    }

    private func parseTasksFromJSON(_ jsonString: String) throws -> [ParsedTask] {
        let cleaned = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw AIParserError.parsingFailed("Could not encode response")
        }

        struct CloudTask: Codable {
            let title: String
            let priority: String
            let deadline: String?
        }

        let cloudTasks = try JSONDecoder().decode([CloudTask].self, from: data)

        return cloudTasks.map { t in
            ParsedTask(
                title: t.title,
                priority: TaskPriority(rawValue: t.priority) ?? .medium,
                deadline: t.deadline.flatMap { ISO8601DateFormatter().date(from: $0) },
                timeEstimate: nil
            )
        }
    }
}
