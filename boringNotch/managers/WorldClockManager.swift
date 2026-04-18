//
//  WorldClockManager.swift
//  boringNotch
//
//  Manages world clock cities and time updates
//

import Foundation
import Combine
import Defaults

final class WorldClockManager: ObservableObject {
    static let shared = WorldClockManager()

    @Published var cities: [WorldClockCity] = []

    private let userDefaultsKey = "worldClockCities"
    private var timer: Timer?

    private init() {
        loadCities()
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public Methods

    func addCity(_ city: WorldClockCity) {
        guard !cities.contains(where: { $0.timezone == city.timezone }) else { return }
        cities.append(city)
        saveCities()
    }

    func removeCity(at index: Int) {
        guard index >= 0 && index < cities.count else { return }
        cities.remove(at: index)
        saveCities()
    }

    func removeCity(with timezone: String) {
        cities.removeAll { $0.timezone == timezone }
        saveCities()
    }

    func refreshTimes() {
        objectWillChange.send()
    }

    // MARK: - Private Methods

    private func loadCities() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([WorldClockCity].self, from: data) {
            cities = decoded
        } else {
            // Default cities
            cities = [
                WorldClockCity(name: "New York", timezone: "America/New_York"),
                WorldClockCity(name: "London", timezone: "Europe/London"),
                WorldClockCity(name: "Tokyo", timezone: "Asia/Tokyo")
            ]
        }
    }

    private func saveCities() {
        if let encoded = try? JSONEncoder().encode(cities) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshTimes()
            }
        }
    }
}

// MARK: - WorldClockCity Model

struct WorldClockCity: Codable, Identifiable, Equatable {
    var id: String { timezone }
    let name: String
    let timezone: String

    var currentTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: timezone)
        return formatter.string(from: Date())
    }

    var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeZone = TimeZone(identifier: timezone)
        return formatter.string(from: Date())
    }
}

// MARK: - Available Cities

extension WorldClockCity {
    static let availableCities: [WorldClockCity] = [
        WorldClockCity(name: "New York", timezone: "America/New_York"),
        WorldClockCity(name: "Los Angeles", timezone: "America/Los_Angeles"),
        WorldClockCity(name: "Chicago", timezone: "America/Chicago"),
        WorldClockCity(name: "Denver", timezone: "America/Denver"),
        WorldClockCity(name: "London", timezone: "Europe/London"),
        WorldClockCity(name: "Paris", timezone: "Europe/Paris"),
        WorldClockCity(name: "Berlin", timezone: "Europe/Berlin"),
        WorldClockCity(name: "Amsterdam", timezone: "Europe/Amsterdam"),
        WorldClockCity(name: "Tokyo", timezone: "Asia/Tokyo"),
        WorldClockCity(name: "Shanghai", timezone: "Asia/Shanghai"),
        WorldClockCity(name: "Hong Kong", timezone: "Asia/Hong_Kong"),
        WorldClockCity(name: "Singapore", timezone: "Asia/Singapore"),
        WorldClockCity(name: "Sydney", timezone: "Australia/Sydney"),
        WorldClockCity(name: "Dubai", timezone: "Asia/Dubai"),
        WorldClockCity(name: "Mumbai", timezone: "Asia/Kolkata"),
        WorldClockCity(name: "Seoul", timezone: "Asia/Seoul"),
        WorldClockCity(name: "Toronto", timezone: "America/Toronto"),
        WorldClockCity(name: "Vancouver", timezone: "America/Vancouver"),
        WorldClockCity(name: "Mexico City", timezone: "America/Mexico_City"),
        WorldClockCity(name: "Sao Paulo", timezone: "America/Sao_Paulo")
    ]
}
