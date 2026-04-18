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

    @Default(.showCalculator) private var showCalculator
    @Default(.showSystemInfo) private var showSystemInfo
    @Default(.showWeather) private var showWeather
    @Default(.showScreenshot) private var showScreenshot
    @Default(.showWorldClock) private var showWorldClock
    @Default(.showUSBDevices) private var showUSBDevices
    @Default(.showNotchControl) private var showNotchControl
    @Default(.showStorageInfo) private var showStorageInfo
    @Default(.showAppLauncher) private var showAppLauncher

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if showCalculator { CalculatorCard() }
                if showSystemInfo { SystemInfoCard() }
                if showWeather { WeatherCard() }
                if showScreenshot { ScreenshotCard() }
                if showWorldClock { WorldClockCard() }
                if showUSBDevices { USBDevicesCard() }
                if showNotchControl { NotchControlCard(onHide: { vm.close() }, onShow: { vm.open() }) }
                if showStorageInfo { StorageCard() }
                if showAppLauncher { AppLauncherCard() }
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
    @State private var isExpanded: Bool = false
    @StateObject private var calculator = CalculatorState()

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

            Text(calculator.display)
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
            isExpanded = true
        }
        .sheet(isPresented: $isExpanded) {
            CalculatorView(calculator: calculator, isPresented: $isExpanded)
                .frame(width: 280, height: 380)
        }
    }
}

// MARK: - Calculator State Machine

class CalculatorState: ObservableObject {
    enum Operation {
        case add, subtract, multiply, divide, none
    }

    enum CalculatorButton: String, CaseIterable {
        case zero = "0", one = "1", two = "2", three = "3", four = "4"
        case five = "5", six = "6", seven = "7", eight = "8", nine = "9"
        case add = "+", subtract = "-", multiply = "×", divide = "÷"
        case decimal = ".", equals = "=", clear = "C"
        case plusMinus = "±", percent = "%"

        var color: Color {
            switch self {
            case .add, .subtract, .multiply, .divide:
                return .orange
            case .equals:
                return .blue
            case .clear, .plusMinus, .percent:
                return .gray
            default:
                return .white.opacity(0.3)
            }
        }
    }

    @Published var display: String = "0"
    @Published var currentOperation: Operation = .none
    @Published var previousValue: Double = 0
    @Published var shouldResetDisplay: Bool = false
    @Published var memory: Double = 0

    func input(_ button: CalculatorButton) {
        switch button {
        case .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine:
            if shouldResetDisplay || display == "0" {
                display = button.rawValue
                shouldResetDisplay = false
            } else {
                display += button.rawValue
            }

        case .decimal:
            if !display.contains(".") {
                display += "."
            }

        case .add:
            setOperation(.add)
        case .subtract:
            setOperation(.subtract)
        case .multiply:
            setOperation(.multiply)
        case .divide:
            setOperation(.divide)

        case .equals:
            calculateResult()

        case .clear:
            display = "0"
            currentOperation = .none
            previousValue = 0
            shouldResetDisplay = false
            memory = 0

        case .plusMinus:
            if let value = Double(display) {
                display = formatResult(-value)
                shouldResetDisplay = true
            }

        case .percent:
            if let value = Double(display) {
                display = formatResult(value / 100)
                shouldResetDisplay = true
            }
        }
    }

    func memoryAdd() {
        if let value = Double(display) {
            memory += value
        }
    }

    func memorySubtract() {
        if let value = Double(display) {
            memory -= value
        }
    }

    func memoryRecall() {
        if memory != 0 {
            display = formatResult(memory)
            shouldResetDisplay = true
        }
    }

    func memoryClear() {
        memory = 0
    }

    private func setOperation(_ op: Operation) {
        if let value = Double(display) {
            if currentOperation != .none && !shouldResetDisplay {
                calculateResult()
            }
            previousValue = Double(display) ?? 0
            currentOperation = op
            shouldResetDisplay = true
        }
    }

    private func calculateResult() {
        guard currentOperation != .none,
              let currentValue = Double(display) else { return }

        var result: Double = 0

        switch currentOperation {
        case .add:
            result = previousValue + currentValue
        case .subtract:
            result = previousValue - currentValue
        case .multiply:
            result = previousValue * currentValue
        case .divide:
            if currentValue != 0 {
                result = previousValue / currentValue
            } else {
                display = "Error"
                currentOperation = .none
                return
            }
        case .none:
            return
        }

        display = formatResult(result)
        currentOperation = .none
        shouldResetDisplay = true
    }

    private func formatResult(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        } else {
            let result = String(format: "%.8g", value)
            return result
        }
    }
}

// MARK: - Calculator View (Expanded)

struct CalculatorView: View {
    @ObservedObject var calculator: CalculatorState
    @Binding var isPresented: Bool
    @Default(.showCalculator) private var showCalculator

    let buttonSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Calculator")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Display
            HStack {
                Spacer()
                Text(calculator.display)
                    .font(.system(size: 42, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            // Memory buttons
            HStack(spacing: 8) {
                MemoryButton(label: "MC", action: calculator.memoryClear)
                MemoryButton(label: "MR", action: calculator.memoryRecall)
                MemoryButton(label: "M+", action: calculator.memoryAdd)
                MemoryButton(label: "M-", action: calculator.memorySubtract)
            }
            .padding(.horizontal, 16)

            // Calculator buttons
            VStack(spacing: buttonSpacing) {
                // Row 1: C, +/-, %, ÷
                HStack(spacing: buttonSpacing) {
                    CalculatorButtonView(button: .clear, calculator: calculator)
                    CalculatorButtonView(button: .plusMinus, calculator: calculator)
                    CalculatorButtonView(button: .percent, calculator: calculator)
                    CalculatorButtonView(button: .divide, calculator: calculator)
                }
                // Row 2: 7, 8, 9, ×
                HStack(spacing: buttonSpacing) {
                    CalculatorButtonView(button: .seven, calculator: calculator)
                    CalculatorButtonView(button: .eight, calculator: calculator)
                    CalculatorButtonView(button: .nine, calculator: calculator)
                    CalculatorButtonView(button: .multiply, calculator: calculator)
                }
                // Row 3: 4, 5, 6, -
                HStack(spacing: buttonSpacing) {
                    CalculatorButtonView(button: .four, calculator: calculator)
                    CalculatorButtonView(button: .five, calculator: calculator)
                    CalculatorButtonView(button: .six, calculator: calculator)
                    CalculatorButtonView(button: .subtract, calculator: calculator)
                }
                // Row 4: 1, 2, 3, +
                HStack(spacing: buttonSpacing) {
                    CalculatorButtonView(button: .one, calculator: calculator)
                    CalculatorButtonView(button: .two, calculator: calculator)
                    CalculatorButtonView(button: .three, calculator: calculator)
                    CalculatorButtonView(button: .add, calculator: calculator)
                }
                // Row 5: 0, ., =
                HStack(spacing: buttonSpacing) {
                    CalculatorButtonView(button: .zero, calculator: calculator, isWide: true)
                    CalculatorButtonView(button: .decimal, calculator: calculator)
                    CalculatorButtonView(button: .equals, calculator: calculator)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.black.opacity(0.95))
        .cornerRadius(16)
    }
}

struct MemoryButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 50, height: 32)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct CalculatorButtonView: View {
    let button: CalculatorState.CalculatorButton
    @ObservedObject var calculator: CalculatorState
    var isWide: Bool = false

    var body: some View {
        Button(action: { calculator.input(button) }) {
            Text(button.rawValue)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(button == .zero ? .black : .white)
                .frame(width: isWide ? 106 : 50, height: 50)
                .background(button.color)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - System Info Card

struct SystemInfoCard: View {
    @StateObject private var systemInfo = SystemInfoManager.shared

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
                SystemInfoRow(icon: "cpu", label: "CPU", value: systemInfo.cpuUsage)
                SystemInfoRow(icon: "wifi", label: "WiFi", value: systemInfo.wifiSSID)
                SystemInfoRow(icon: "memorychip", label: "RAM", value: systemInfo.ramUsed)
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .onAppear {
            systemInfo.startAutoRefresh()
        }
        .onDisappear {
            systemInfo.stopAutoRefresh()
        }
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
                .lineLimit(1)
        }
    }
}

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
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .onAppear {
            weather.startAutoRefresh()
        }
        .onDisappear {
            weather.stopAutoRefresh()
        }
    }
}

// MARK: - Screenshot Card

enum ScreenshotMode: String, CaseIterable {
    case screen = "Screen"
    case selection = "Selection"
    case window = "Window"
}

struct ScreenshotCard: View {
    @State private var selectedMode: ScreenshotMode = .screen
    @State private var isCapturing: Bool = false
    @State private var lastCaptureTime: Date?
    @Default(.screenshotDestination) private var destination

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

            // Mode selector
            Picker("", selection: $selectedMode) {
                ForEach(ScreenshotMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .scaleEffect(0.6)
            .frame(height: 24)

            // Capture button
            Button(action: takeScreenshot) {
                HStack(spacing: 4) {
                    Image(systemName: isCapturing ? "checkmark" : "camera")
                        .font(.system(size: 12))
                    Text(isCapturing ? "Captured!" : "Capture")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white)
                .frame(width: 80, height: 28)
                .background(isCapturing ? Color.green.opacity(0.6) : Color.blue.opacity(0.4))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(isCapturing)
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }

    private func takeScreenshot() {
        isCapturing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCapturing = false
        }

        let modeFlag: String
        switch selectedMode {
        case .screen:
            modeFlag = "-m"
        case .selection:
            modeFlag = "-s"
        case .window:
            modeFlag = "-w"
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

        if destination == "clipboard" {
            task.arguments = [modeFlag, "-x", "-c"]
        } else {
            let timestamp = Int(Date().timeIntervalSince1970)
            let filename = "Screenshot_\(timestamp).png"
            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let filePath = desktopURL.appendingPathComponent(filename).path
            task.arguments = [modeFlag, filePath]
        }

        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            if destination == "clipboard" {
                AudioPlayer.shared.play(fileName: "shutter", fileExtension: "aiff")
            }
        } catch {
            print("Screenshot error: \(error)")
        }
    }
}

// MARK: - World Clock Card

struct WorldClockCard: View {
    @State private var nycTime: String = ""
    @State private var londonTime: String = ""
    @State private var tokyoTime: String = ""
    @State private var timer: Timer?

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
                TimeRow(city: "NYC", time: nycTime)
                TimeRow(city: "London", time: londonTime)
                TimeRow(city: "Tokyo", time: tokyoTime)
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .onAppear {
            updateTimes()
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                updateTimes()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func updateTimes() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        formatter.timeZone = TimeZone(identifier: "America/New_York")
        nycTime = formatter.string(from: Date())

        formatter.timeZone = TimeZone(identifier: "Europe/London")
        londonTime = formatter.string(from: Date())

        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        tokyoTime = formatter.string(from: Date())
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
