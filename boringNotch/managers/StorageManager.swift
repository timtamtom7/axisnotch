//
//  StorageManager.swift
//  boringNotch
//
//  Manages disk storage information using FileManager
//

import Foundation
import Combine

final class StorageManager: ObservableObject {
    static let shared = StorageManager()

    @Published var volumes: [StorageVolume] = []
    @Published var totalStorage: StorageInfo = StorageInfo(used: 0, total: 0, free: 0)
    @Published var isLoading: Bool = false

    private init() {
        refreshStorage()
    }

    // MARK: - Public Methods

    func refreshStorage() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let volumeList = self?.getVolumes() ?? []
            let total = self?.getTotalStorage() ?? StorageInfo(used: 0, total: 0, free: 0)

            DispatchQueue.main.async {
                self?.volumes = volumeList
                self?.totalStorage = total
                self?.isLoading = false
            }
        }
    }

    // MARK: - Private Methods

    private func getVolumes() -> [StorageVolume] {
        var volumeList: [StorageVolume] = []

        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsReadOnlyKey
        ]

        guard let urlArray = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else {
            return volumeList
        }

        for url in urlArray {
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(keys))

                let name = resourceValues.volumeName ?? url.lastPathComponent
                let total = Int64(resourceValues.volumeTotalCapacity ?? 0)
                let available = resourceValues.volumeAvailableCapacityForImportantUsage ?? 0
                let used = total - available
                let isRemovable = resourceValues.volumeIsRemovable ?? false
                let isEjectable = resourceValues.volumeIsEjectable ?? false
                let isReadOnly = resourceValues.volumeIsReadOnly ?? false

                let volume = StorageVolume(
                    id: url.path,
                    name: name,
                    mountPoint: url.path,
                    total: total,
                    used: used,
                    free: available,
                    isRemovable: isRemovable,
                    isEjectable: isEjectable,
                    isReadOnly: isReadOnly
                )

                volumeList.append(volume)
            } catch {
                print("Error getting volume info for \(url): \(error)")
            }
        }

        return volumeList
    }

    private func getTotalStorage() -> StorageInfo {
        let fileManager = FileManager.default
        var totalUsed: Int64 = 0
        var totalTotal: Int64 = 0

        let keys: [URLResourceKey] = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]

        guard let urlArray = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else {
            return StorageInfo(used: 0, total: 0, free: 0)
        }

        for url in urlArray {
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(keys))
                let total = Int64(resourceValues.volumeTotalCapacity ?? 0)
                let available = Int64(resourceValues.volumeAvailableCapacity ?? 0)
                totalTotal += total
                totalUsed += (total - available)
            } catch {
                continue
            }
        }

        return StorageInfo(used: totalUsed, total: totalTotal, free: totalTotal - totalUsed)
    }
}

// MARK: - StorageInfo Model

struct StorageInfo: Equatable {
    let used: Int64
    let total: Int64
    let free: Int64

    var usedGB: Double {
        Double(used) / (1024 * 1024 * 1024)
    }

    var totalGB: Double {
        Double(total) / (1024 * 1024 * 1024)
    }

    var freeGB: Double {
        Double(free) / (1024 * 1024 * 1024)
    }

    var usagePercentage: Double {
        guard total > 0 else { return 0 }
        return (Double(used) / Double(total)) * 100
    }

    var formattedUsed: String {
        String(format: "%.0f GB", usedGB)
    }

    var formattedTotal: String {
        String(format: "%.0f GB", totalGB)
    }

    var formattedFree: String {
        String(format: "%.0f GB", freeGB)
    }

    var usageColor: StorageColor {
        let percentage = usagePercentage
        if percentage < 70 {
            return .green
        } else if percentage < 85 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - StorageVolume Model

struct StorageVolume: Identifiable, Equatable {
    let id: String
    let name: String
    let mountPoint: String
    let total: Int64
    let used: Int64
    let free: Int64
    let isRemovable: Bool
    let isEjectable: Bool
    let isReadOnly: Bool

    var storageInfo: StorageInfo {
        StorageInfo(used: used, total: total, free: free)
    }

    var displayName: String {
        if name.isEmpty || name == "/" {
            return "Macintosh HD"
        }
        return name
    }
}

// MARK: - StorageColor Enum

enum StorageColor {
    case green
    case yellow
    case red
}
