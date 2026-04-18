//
//  WiFiManager.swift
//  boringNotch
//
//  Manages WiFi SSID retrieval and password sharing via QR code
//

import Foundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

final class WiFiManager: ObservableObject {
    static let shared = WiFiManager()

    @Published var currentSSID: String = "Not Connected"
    @Published var currentPassword: String = ""
    @Published var qrCodeImage: NSImage?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasPermissions: Bool = false

    private let context = CIContext()

    private init() {
        refreshWiFiInfo()
    }

    // MARK: - Public Methods

    func refreshWiFiInfo() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ssid = self?.getCurrentSSID() ?? "Not Connected"
            let password = self?.getWiFiPassword() ?? ""
            let hasPerms = self?.checkAirPortPermissions() ?? false

            DispatchQueue.main.async {
                self?.currentSSID = ssid
                self?.currentPassword = password
                self?.hasPermissions = hasPerms
                self?.isLoading = false

                if !ssid.isEmpty && ssid != "Not Connected" && !password.isEmpty {
                    self?.generateQRCode(ssid: ssid, password: password)
                }
            }
        }
    }

    func requestPermissions() {
        // This will trigger the system to ask for permission
        // The networksetup command will prompt for admin credentials if needed
        refreshWiFiInfo()
    }

    // MARK: - Private Methods

    private func checkAirPortPermissions() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-listpreferredwirelessnetworks", "en0"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // If we can read the SSID, we have permissions
                return !output.contains("Unable to")
            }
        } catch {
            return false
        }

        return false
    }

    private func getCurrentSSID() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-listpreferredwirelessnetworks", "en0"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                if lines.count > 1 {
                    // First line is "Preferred networks on en0:", skip it
                    let ssidLine = lines.dropFirst().first?.trimmingCharacters(in: .whitespaces) ?? "Not Connected"
                    return ssidLine.isEmpty ? "Not Connected" : ssidLine
                }
            }
        } catch {
            return "Not Connected"
        }

        return "Not Connected"
    }

    private func getWiFiPassword() -> String {
        guard !currentSSID.isEmpty && currentSSID != "Not Connected" else {
            return ""
        }

        // Use security command to get the WiFi password
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-D", "AirPort network password", "-a", currentSSID]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Output format: "password: <password>"
                for line in output.components(separatedBy: "\n") {
                    if line.hasPrefix("password: ") {
                        return String(line.dropFirst("password: ".count))
                    }
                }
            }
        } catch {
            return ""
        }

        return ""
    }

    private func generateQRCode(ssid: String, password: String) {
        // WiFi QR code format: WIFI:T:WPA;S:<SSID>;P:<PASSWORD>;;
        let wifiString = "WIFI:T:WPA;S:\(ssid);P:\(password);;"

        guard let qrImage = createQRCode(from: wifiString) else {
            errorMessage = "Failed to generate QR code"
            return
        }

        qrCodeImage = qrImage
    }

    private func createQRCode(from string: String) -> NSImage? {
        guard let data = string.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up the QR code for better quality
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: scale)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
