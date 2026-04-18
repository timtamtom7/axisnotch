//
//  WiFiSharingCard.swift
//  boringNotch
//
//  WiFi sharing card showing QR code to share WiFi credentials
//

import SwiftUI

struct WiFiSharingCard: View {
    @ObservedObject private var manager = WiFiManager.shared
    @State private var showingQRDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "wifi")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))
                Text("WiFi Share")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    manager.refreshWiFiInfo()
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
            } else if manager.currentSSID == "Not Connected" {
                VStack(spacing: 2) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    Text("Not Connected")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else if let qrImage = manager.qrCodeImage {
                VStack(spacing: 2) {
                    Image(nsImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 50, height: 50)
                        .onTapGesture {
                            showingQRDetail = true
                        }

                    Text(manager.currentSSID)
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16))
                        .foregroundColor(.yellow)
                    Text("Scan to share")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
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
            manager.refreshWiFiInfo()
        }
        .sheet(isPresented: $showingQRDetail) {
            QRDetailSheet(isPresented: $showingQRDetail)
        }
    }
}

// MARK: - QRDetailSheet

struct QRDetailSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var manager = WiFiManager.shared
    @State private var isPasswordVisible = false

    var body: some View {
        VStack(spacing: 20) {
            Text("WiFi Sharing")
                .font(.headline)

            if let qrImage = manager.qrCodeImage {
                Image(nsImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 200, height: 200)
            }

            VStack(spacing: 8) {
                Text("Network: \(manager.currentSSID)")
                    .font(.title2)

                if !manager.currentPassword.isEmpty {
                    HStack {
                        Text("Password: ")
                            .foregroundColor(.secondary)
                        if isPasswordVisible {
                            Text(manager.currentPassword)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            Text(String(repeating: "•", count: manager.currentPassword.count))
                                .font(.system(.body, design: .monospaced))
                        }
                        Button(isPasswordVisible ? "Hide" : "Show") {
                            isPasswordVisible.toggle()
                            if isPasswordVisible {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                    isPasswordVisible = false
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            Button("Done") {
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(30)
        .frame(width: 320, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    WiFiSharingCard()
        .frame(width: 140, height: 100)
        .background(Color.black)
}
