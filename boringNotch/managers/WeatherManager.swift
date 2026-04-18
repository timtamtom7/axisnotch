//
//  WeatherManager.swift
//  boringNotch
//
//  Manages weather data fetching from OpenWeatherMap API
//

import Foundation
import Combine
import Defaults

final class WeatherManager: ObservableObject {
    static let shared = WeatherManager()

    @Published var temperature: String = "--"
    @Published var condition: String = "Loading..."
    @Published var conditionIcon: String = "cloud.sun.fill"
    @Published var location: String = "..."
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var refreshTask: Task<Void, Never>?
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"

    private init() {}

    func fetchWeather() {
        let apiKey = Defaults[.weatherAPIKey]
        guard !apiKey.isEmpty else {
            temperature = "--"
            condition = "Set API key"
            conditionIcon = "gear"
            location = "Settings"
            return
        }

        isLoading = true
        errorMessage = nil

        let units = Defaults[.weatherUnits]
        let lat = 40.7128
        let lon = -74.0060

        guard let url = URL(string: "\(baseURL)?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=\(units)") else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.temperature = "--"
                    self?.condition = "Error"
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "No data"
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let main = json["main"] as? [String: Any],
                       let temp = main["temp"] as? Double,
                       let weather = (json["weather"] as? [[String: Any]])?.first,
                       let conditionStr = weather["main"] as? String,
                       let iconStr = weather["icon"] as? String,
                       let name = json["name"] as? String {

                        let tempStr = units == "imperial" ? "\(Int(temp))°F" : "\(Int(temp))°C"
                        self?.temperature = tempStr
                        self?.condition = conditionStr
                        self?.location = name
                        self?.conditionIcon = self?.iconMapping(iconStr) ?? "cloud.sun.fill"
                    }
                } catch {
                    self?.errorMessage = "Parse error"
                    self?.temperature = "--"
                    self?.condition = "Error"
                }
            }
        }.resume()
    }

    private func iconMapping(_ iconCode: String) -> String {
        switch iconCode {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d": return "cloud.sun.rain.fill"
        case "10n": return "cloud.moon.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "snow"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.sun.fill"
        }
    }

    func startAutoRefresh() {
        fetchWeather()

        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15 * 60))
                if !Task.isCancelled {
                    await MainActor.run {
                        self.fetchWeather()
                    }
                }
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    deinit {
        stopAutoRefresh()
    }
}
