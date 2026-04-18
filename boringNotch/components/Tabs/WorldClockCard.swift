//
//  WorldClockCard.swift
//  boringNotch
//
//  World clock card showing time in multiple cities
//

import SwiftUI
import Defaults

struct WorldClockCard: View {
    @ObservedObject private var manager = WorldClockManager.shared
    @State private var showingCityPicker = false
    @State private var cityToDelete: WorldClockCity?
    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.cyan)
                    .font(.system(size: 10))
                Text("World Clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    showingCityPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if manager.cities.isEmpty {
                Text("No cities added")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(manager.cities.prefix(3)) { city in
                        TimeRow(city: city.name, time: city.currentTime)
                            .contextMenu {
                                Button(role: .destructive) {
                                    cityToDelete = city
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Remove \(city.name)", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .onAppear {
            manager.refreshTimes()
        }
        .sheet(isPresented: $showingCityPicker) {
            CityPickerSheet(isPresented: $showingCityPicker)
        }
        .alert("Remove City", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let city = cityToDelete {
                    manager.removeCity(with: city.timezone)
                }
            }
        } message: {
            if let city = cityToDelete {
                Text("Are you sure you want to remove \(city.name)?")
            }
        }
    }
}

// MARK: - TimeRow View

struct TimeRow: View {
    let city: String
    let time: String

    var body: some View {
        HStack {
            Text(city)
                .font(.system(size: 9))
                .foregroundColor(.gray)
            Spacer()
            Text(time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// MARK: - CityPickerSheet

struct CityPickerSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var manager = WorldClockManager.shared
    @State private var searchText = ""

    private var filteredCities: [WorldClockCity] {
        if searchText.isEmpty {
            return WorldClockCity.availableCities
        }
        return WorldClockCity.availableCities.filter { city in
            city.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var unaddedCities: [WorldClockCity] {
        filteredCities.filter { city in
            !manager.cities.contains { $0.timezone == city.timezone }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add City")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
            }
            .padding()

            TextField("Search cities...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List {
                ForEach(unaddedCities) { city in
                    Button {
                        manager.addCity(city)
                    } label: {
                        HStack {
                            Text(city.name)
                            Spacer()
                            Text(city.timezone)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
        .frame(width: 300, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    WorldClockCard()
        .frame(width: 140, height: 100)
        .background(Color.black)
}
