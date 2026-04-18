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
    @Default(.showWiFiSharing) private var showWiFiSharing
    @Default(.showScreenshotHistory) private var showScreenshotHistory
    @Default(.showAppCleaner) private var showAppCleaner

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if showCalculator { CalculatorCard() }
                if showSystemInfo { SystemInfoCard() }
                if showWeather { WeatherCard() }
                if showScreenshot { ScreenshotCard() }
                if showScreenshotHistory { ScreenshotHistoryCard() }
                if showWorldClock { WorldClockCard() }
                if showUSBDevices { USBDevicesCard() }
                if showNotchControl { NotchControlCard(onHide: { vm.close() }, onShow: { vm.open() }) }
                if showStorageInfo { StorageCard() }
                if showAppLauncher { AppLauncherCard() }
                if showAppCleaner { CleanerCard() }
                if showWiFiSharing { WiFiSharingCard() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollTargetBehavior(.viewAligned)
        .sensoryFeedback(.alignment, trigger: 0)
    }
}

#Preview {
    AxisToolsView()
        .frame(width: 500, height: 160)
        .background(Color.black)
}
