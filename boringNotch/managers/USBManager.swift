//
//  USBManager.swift
//  boringNotch
//
//  Manages USB device enumeration and monitoring using IOKit
//

import Foundation
import IOKit
import IOKit.usb
import Combine
import AppKit

final class USBManager: ObservableObject {
    static let shared = USBManager()

    @Published var devices: [USBDevice] = []
    @Published var isLoading: Bool = false

    private var notificationPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var runLoopSource: CFRunLoopSource?

    private init() {
        refreshDevices()
        setupNotifications()
    }

    deinit {
        stopNotifications()
    }

    // MARK: - Public Methods

    func refreshDevices() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let deviceList = self?.enumerateUSBDevices() ?? []
            DispatchQueue.main.async {
                self?.devices = deviceList
                self?.isLoading = false
            }
        }
    }

    func ejectDevice(_ device: USBDevice) {
        // Find volumes associated with this device and eject them
        let fileManager = FileManager.default
        let volumeURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey],
            options: [.skipHiddenVolumes]
        ) ?? []

        var ejected = false
        for url in volumeURLs {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey])
                let isRemovable = resourceValues.volumeIsRemovable ?? false
                let isEjectable = resourceValues.volumeIsEjectable ?? false

                // Check if this volume is removable/ejectable and might match the device
                if isRemovable && isEjectable {
                    let volumeName = resourceValues.volumeName ?? url.lastPathComponent
                    // Try to match by name (fuzzy match)
                    if volumeName.lowercased().contains(device.name.lowercased()) ||
                       device.name.lowercased().contains(volumeName.lowercased()) ||
                       volumeName.lowercased() == "macintosh hd" && device.name.lowercased().contains("disk") {
                        continue // Skip internal drive
                    }

                    // Attempt to eject using diskutil
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
                    process.arguments = ["eject", url.path]
                    process.standardOutput = FileHandle.nullDevice
                    process.standardError = FileHandle.nullDevice

                    do {
                        try process.run()
                        process.waitUntilExit()
                        if process.terminationStatus == 0 {
                            ejected = true
                            print("Successfully ejected volume: \(volumeName)")
                        }
                    } catch {
                        print("Failed to eject volume \(volumeName): \(error)")
                    }
                }
            } catch {
                continue
            }
        }

        // If we couldn't eject programmatically, show alert
        if !ejected {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Manual Eject Required"
                alert.informativeText = "The device \"\(device.name)\" cannot be ejected programmatically. Please eject it manually via Finder by dragging it to the Trash or using the eject button."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    // MARK: - Private Methods

    private func enumerateUSBDevices() -> [USBDevice] {
        var devices: [USBDevice] = []

        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        var iterator: io_iterator_t = 0

        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard result == KERN_SUCCESS else {
            return devices
        }

        var service: io_service_t = IOIteratorNext(iterator)
        while service != 0 {
            if let device = getUSBDeviceInfo(service: service) {
                devices.append(device)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        IOObjectRelease(iterator)
        return devices
    }

    private func getUSBDeviceInfo(service: io_service_t) -> USBDevice? {
        var vendorName = "Unknown USB Device"
        var productName = "Unknown Device"

        if let vendorRef = IORegistryEntryCreateCFProperty(
            service,
            kUSBVendorString as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            vendorName = vendorRef
        }

        if let productRef = IORegistryEntryCreateCFProperty(
            service,
            kUSBProductString as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            productName = productRef
        }

        // Get device speed
        var speed: Int = 0
        if let speedRef = IORegistryEntryCreateCFProperty(
            service,
            "Device Speed" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int {
            speed = speedRef
        }

        // Get location ID for unique identification
        var locationID: UInt32 = 0
        if let locationRef = IORegistryEntryCreateCFProperty(
            service,
            kUSBDevicePropertyLocationID as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? UInt32 {
            locationID = locationRef
        }

        // Get current state (connected/disconnected)
        var isConnected = true
        if let stateRef = IORegistryEntryCreateCFProperty(
            service,
            "DeviceState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int {
            isConnected = stateRef == 0 || stateRef == 4 // 0 = configured, 4 = attached
        }

        let name = productName == "Unknown Device" ? vendorName : productName

        return USBDevice(
            id: "\(locationID)",
            name: name,
            vendor: vendorName,
            speed: speed,
            isConnected: isConnected
        )
    }

    private func setupNotifications() {
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notificationPort = notificationPort else { return }

        runLoopSource = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)

        // Setup for device added notifications
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let addCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon = refcon else { return }
            let manager = Unmanaged<USBManager>.fromOpaque(refcon).takeUnretainedValue()
            manager.handleDeviceAdded(iterator: iterator)
        }

        IOServiceAddMatchingNotification(
            notificationPort,
            kIOFirstMatchNotification,
            matchingDict,
            addCallback,
            selfPtr,
            &addedIterator
        )

        // Drain initial iterator
        handleDeviceAdded(iterator: addedIterator)

        // Setup for device removed notifications
        let removeCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon = refcon else { return }
            let manager = Unmanaged<USBManager>.fromOpaque(refcon).takeUnretainedValue()
            manager.handleDeviceRemoved(iterator: iterator)
        }

        IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            IOServiceMatching(kIOUSBDeviceClassName),
            removeCallback,
            selfPtr,
            &removedIterator
        )

        // Drain initial iterator
        handleDeviceRemoved(iterator: removedIterator)
    }

    private func handleDeviceAdded(iterator: io_iterator_t) {
        var service: io_service_t = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshDevices()
        }
    }

    private func handleDeviceRemoved(iterator: io_iterator_t) {
        var service: io_service_t = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshDevices()
        }
    }

    private func stopNotifications() {
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        if let notificationPort = notificationPort {
            IONotificationPortDestroy(notificationPort)
        }
    }
}

// MARK: - USBDevice Model

struct USBDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let vendor: String
    let speed: Int
    let isConnected: Bool

    var speedString: String {
        switch speed {
        case 0: return "Low Speed"
        case 1: return "Full Speed"
        case 2: return "High Speed"
        case 3: return "Super Speed"
        case 4: return "Super Plus Speed"
        default: return "Unknown"
        }
    }

    var isHighSpeed: Bool {
        speed >= 2
    }
}
