//
//  AxisToolsView.swift
//  boringNotch
//
//  Utility tools for the notch: calculator, system info, weather, etc.
//

import SwiftUI
import Defaults

struct AxisToolsView: View {
    @EnvironmentObject var vm: BoringViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CalculatorCard()
                SystemInfoCard()
                WeatherCard()
                ScreenshotCard()
                WorldClockCard()
                USBDevicesCard()
                NotchControlCard(onHide: { vm.close() }, onShow: { vm.open() })
                StorageCard()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollTargetBehavior(.viewAligned)
        .sensoryFeedback(.alignment, trigger: 0)
    }
}

// MARK: - Calculator Card

struct CalculatorCard: View {
    @State private var display: String = "0"
    @State private var currentOp: String = ""
    @State private var prevValue: Double = 0
    @State private var shouldReset: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.purple)
                    .font(.system(size: 10))
                Text("Calculator")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(display)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .onTapGesture {
            // Calculator popup would go here
            // For now, show a simple 1+1
            if display == "0" {
                display = "1 + 1 = 2"
            }
        }
    }
}

// MARK: - System Info Card

struct SystemInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.green)
                    .font(.system(size: 10))
                Text("System")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                SystemInfoRow(icon: "wifi", label: "WiFi", value: "Connected")
                SystemInfoRow(icon: "memorychip", label: "RAM", value: "8 GB")
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }
}

struct SystemInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .frame(width: 12)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 9))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Weather Card

struct WeatherCard: View {
    @State private var temp: String = "--"
    @State private var condition: String = "loading..."

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 10))
                Text("Weather")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(temp)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
            Text(condition)
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .onAppear {
            // Weather API would go here
            temp = "72°F"
            condition = "Sunny"
        }
    }
}

// MARK: - Screenshot Card

struct ScreenshotCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))
                Text("Screenshot")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: takeScreenshot) {
                HStack(spacing: 4) {
                    Image(systemName: "camera")
                        .font(.system(size: 12))
                    Text("Capture")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white)
                .frame(width: 80, height: 28)
                .background(Color.blue.opacity(0.4))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }

    private func takeScreenshot() {
        // Screenshot shortcut using screencapture
    }
}

// MARK: - World Clock Card

struct WorldClockCard: View {
    @State private var currentTime: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.cyan)
                    .font(.system(size: 10))
                Text("World Clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                TimeRow(city: "NYC", time: "10:30 AM")
                TimeRow(city: "London", time: "3:30 PM")
                TimeRow(city: "Tokyo", time: "12:30 AM+1")
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .onAppear {
            updateTime()
        }
    }

    private func updateTime() {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.timeStyle = .short
        currentTime = formatter.string(from: Date())
    }
}

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

// MARK: - USB Devices Card

struct USBDevicesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cable.connector")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                Text("USB")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                DeviceRow(name: "iPhone", status: "Connected")
                DeviceRow(name: "AirPods", status: "Disconnected")
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }
}

struct DeviceRow: View {
    let name: String
    let status: String

    var body: some View {
        HStack {
            Circle()
                .fill(status == "Connected" ? Color.green : Color.gray)
                .frame(width: 5, height: 5)
            Text(name)
                .font(.system(size: 9))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Notch Control Card

struct NotchControlCard: View {
    let onHide: () -> Void
    let onShow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "rectangle.and.arrow.up.right")
                    .foregroundColor(.pink)
                    .font(.system(size: 10))
                Text("Notch")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onHide) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.down.left.and.arrow.up.right")
                            .font(.system(size: 12))
                        Text("Hide")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.white)
                    .frame(width: 44, height: 36)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: onShow) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up.right.and.arrow.down.left")
                            .font(.system(size: 12))
                        Text("Show")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.white)
                    .frame(width: 44, height: 36)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }
}

// MARK: - Storage Card

struct StorageCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 10))
                Text("Storage")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Storage bar
            VStack(alignment: .leading, spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: geo.size.width * 0.65, height: 6)
                    }
                }
                .frame(height: 6)

                Text("256GB / 512GB used")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }
}

// MARK: - App Launcher Card (retained from original)

struct AppLauncherCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "apps.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 10))
                Text("Apps")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 6) {
                AxisAppButton(icon: "safari", name: "Safari") {
                    NSWorkspace.shared.launchApplication("Safari")
                }
                AxisAppButton(icon: "terminal", name: "Terminal") {
                    NSWorkspace.shared.launchApplication("Terminal")
                }
                AxisAppButton(icon: "finder", name: "Finder") {
                    NSWorkspace.shared.launchApplication("Finder")
                }
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }
}

struct AxisAppButton: View {
    let icon: String
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(name)
                    .font(.system(size: 7))
            }
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AxisToolsView()
        .frame(width: 500, height: 160)
        .background(Color.black)
}
