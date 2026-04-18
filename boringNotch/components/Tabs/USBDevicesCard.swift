//
//  USBDevicesCard.swift
//  boringNotch
//
//  USB devices card showing connected devices
//

import SwiftUI

struct USBDevicesCard: View {
    @ObservedObject private var manager = USBManager.shared
    @State private var selectedDevice: USBDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cable.connector")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                Text("USB")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    manager.refreshDevices()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if manager.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if manager.devices.isEmpty {
                Text("No devices")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(manager.devices.prefix(3)) { device in
                        DeviceRow(device: device)
                            .contextMenu {
                                Button {
                                    manager.ejectDevice(device)
                                } label: {
                                    Label("Eject", systemImage: "eject")
                                }
                            }
                    }

                    if manager.devices.count > 3 {
                        Text("+\(manager.devices.count - 3) more")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
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
            manager.refreshDevices()
        }
    }
}

// MARK: - DeviceRow View

struct DeviceRow: View {
    let device: USBDevice

    var body: some View {
        HStack {
            Circle()
                .fill(device.isConnected ? Color.green : Color.gray)
                .frame(width: 5, height: 5)
            Text(device.name)
                .font(.system(size: 9))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

#Preview {
    USBDevicesCard()
        .frame(width: 140, height: 100)
        .background(Color.black)
}
