//
//  OllamaProvider.swift
//  boringNotch
//
//  Local AI parsing via Ollama
//

import Foundation

final class OllamaProvider: AIParserProvider {
    var name: String { "Ollama" }

    func parse(transcription: String) async throws -> [ParsedTask] {
        let url = URL(string: "http://localhost:11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let prompt = """
        Parse the following into a JSON array of tasks. Each task has: title (string), priority ("high", "medium", or "low"), deadline (ISO date string or null).
        Input: "\(transcription)"
        Output ONLY the JSON array, no markdown.
        """

        let body: [String: Any] = [
            "model": "llama3.2",
            "prompt": prompt,
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIParserError.networkError("Ollama returned non-200")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw AIParserError.parsingFailed("Invalid Ollama response")
        }

        return try parseTasksFromJSON(responseText)
    }

    private func parseTasksFromJSON(_ jsonString: String) throws -> [ParsedTask] {
        let cleaned = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw AIParserError.parsingFailed("Could not encode response")
        }

        struct OllamaTask: Codable {
            let title: String
            let priority: String
            let deadline: String?
        }

        let ollamaTasks = try JSONDecoder().decode([OllamaTask].self, from: data)

        return ollamaTasks.map { t in
            ParsedTask(
                title: t.title,
                priority: TaskPriority(rawValue: t.priority) ?? .medium,
                deadline: t.deadline.flatMap { ISO8601DateFormatter().date(from: $0) },
                timeEstimate: nil
            )
        }
    }
}
