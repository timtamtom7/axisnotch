//
//  WeatherCard.swift
//  boringNotch
//
//  Weather card showing current conditions
//

import SwiftUI
import Defaults

// MARK: - Weather Card

struct WeatherCard: View {
    @StateObject private var weather = WeatherManager.shared
    @Default(.weatherUnits) private var weatherUnits

    private var unitSymbol: String {
        weatherUnits == "imperial" ? "°F" : "°C"
    }

    private func toggleUnits() {
        weatherUnits = weatherUnits == "imperial" ? "metric" : "imperial"
        weather.fetchWeather()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: weather.conditionIcon)
                    .foregroundColor(.yellow)
                    .font(.system(size: 10))
                Text("Weather")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Button(action: toggleUnits) {
                    Text(unitSymbol)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text(weather.temperature)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
            Text(weather.location)
                .font(.system(size: 9))
                .foregroundColor(.gray)
            Text(weather.condition)
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            weather.startAutoRefresh()
        }
        .onDisappear {
            weather.stopAutoRefresh()
        }
    }
}
