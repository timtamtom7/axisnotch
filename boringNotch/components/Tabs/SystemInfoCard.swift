//
//  SystemInfoCard.swift
//  boringNotch
//
//  System info card showing CPU, WiFi, and RAM usage
//

import SwiftUI

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
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
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
