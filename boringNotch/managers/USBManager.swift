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
        // Note: Ejecting USB devices programmatically requires more complex IOKit handling
        // This is a placeholder for the eject functionality
        print("Request to eject: \(device.name)")
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
