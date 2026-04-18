//
//  SystemInfoManager.swift
//  boringNotch
//
//  Provides real-time system information using sysctl and netstat
//

import Foundation
import Combine
import Darwin

final class SystemInfoManager: ObservableObject {
    static let shared = SystemInfoManager()

    @Published var wifiSSID: String = "Not Connected"
    @Published var cpuUsage: String = "0%"
    @Published var ramUsed: String = "0 GB"
    @Published var ramTotal: String = "0 GB"
    @Published var ramUsagePercent: Double = 0.0

    private var refreshTask: Task<Void, Never>?

    private init() {}

    func startAutoRefresh() {
        refreshSystemInfo()

        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled {
                    await MainActor.run {
                        self.refreshSystemInfo()
                    }
                }
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshSystemInfo() {
        refreshCPUUsage()
        refreshRAMUsage()
        refreshWiFiSSID()
    }

    private func refreshCPUUsage() {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            cpuUsage = "N/A"
            return
        }

        var totalUsage: Double = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(info[offset + Int(CPU_STATE_USER)])
            let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(info[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(info[offset + Int(CPU_STATE_NICE)])

            let total = user + system + idle + nice
            let usage = total > 0 ? ((user + system + nice) / total) * 100 : 0
            totalUsage += usage
        }

        let avgUsage = numCPUs > 0 ? totalUsage / Double(numCPUs) : 0
        cpuUsage = String(format: "%.0f%%", avgUsage)
    }

    private func refreshRAMUsage() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            ramUsed = "N/A"
            ramTotal = "N/A"
            return
        }

        let pageSize = vm_kernel_page_size
        let totalMemory = ProcessInfo.processInfo.physicalMemory

        let activePages = UInt64(stats.active_count)
        let wiredPages = UInt64(stats.wire_count)
        let compressedPages = UInt64(stats.compressor_page_count)

        let usedPages = activePages + wiredPages + compressedPages
        let usedBytes = usedPages * UInt64(pageSize)
        let totalGB = Double(totalMemory) / (1024 * 1024 * 1024)
        let usedGB = Double(usedBytes) / (1024 * 1024 * 1024)

        ramTotal = String(format: "%.1f GB", totalGB)
        ramUsed = String(format: "%.1f GB", usedGB)
        ramUsagePercent = totalGB > 0 ? (usedGB / totalGB) * 100 : 0
    }

    private func refreshWiFiSSID() {
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
                    wifiSSID = ssidLine.isEmpty ? "Not Connected" : ssidLine
                } else {
                    wifiSSID = "Not Connected"
                }
            }
        } catch {
            wifiSSID = "Not Connected"
        }
    }

    deinit {
        stopAutoRefresh()
    }
}
