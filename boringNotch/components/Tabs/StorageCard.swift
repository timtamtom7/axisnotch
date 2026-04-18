//
//  StorageCard.swift
//  boringNotch
//
//  Storage card showing disk usage
//

import SwiftUI

struct StorageCard: View {
    @ObservedObject private var manager = StorageManager.shared

    private var showPerVolume: Bool {
        manager.volumes.count > 1
    }

    private var primaryVolume: StorageVolume? {
        // Prefer "Macintosh HD" or the root volume, otherwise first available
        manager.volumes.first { $0.name == "Macintosh HD" || $0.mountPoint == "/" }
            ?? manager.volumes.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(storageColor)
                    .font(.system(size: 10))
                Text("Storage")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            if manager.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if showPerVolume {
                // Per-volume breakdown
                perVolumeView
            } else {
                // Single volume (aggregate or primary only)
                singleVolumeView
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
            manager.refreshStorage()
        }
    }

    @ViewBuilder
    private var singleVolumeView: some View {
        let volumeToShow = primaryVolume ?? StorageVolume(
            id: "unknown",
            name: "Storage",
            mountPoint: "/",
            total: manager.totalStorage.total,
            used: manager.totalStorage.used,
            free: manager.totalStorage.free,
            isRemovable: false,
            isEjectable: false,
            isReadOnly: false
        )

        VStack(alignment: .leading, spacing: 2) {
            Text(volumeToShow.displayName)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(storageColor)
                        .frame(width: geo.size.width * CGFloat(manager.totalStorage.usagePercentage / 100), height: 6)
                }
            }
            .frame(height: 6)

            Text("\(volumeToShow.storageInfo.formattedUsed) / \(volumeToShow.storageInfo.formattedTotal) used")
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private var perVolumeView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Show first two volumes with usage bars
            ForEach(Array(manager.volumes.prefix(2))) { volume in
                VStack(alignment: .leading, spacing: 1) {
                    Text(volume.displayName)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(storageColorForVolume(volume))
                                .frame(width: geo.size.width * CGFloat(volume.storageInfo.usagePercentage / 100), height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(volume.storageInfo.formattedUsed) / \(volume.storageInfo.formattedTotal)")
                        .font(.system(size: 6))
                        .foregroundColor(.gray)
                }
            }

            if manager.volumes.count > 2 {
                Text("+\(manager.volumes.count - 2) more")
                    .font(.system(size: 6))
                    .foregroundColor(.gray)
            }
        }
    }

    private var storageColor: Color {
        switch manager.totalStorage.usageColor {
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .red:
            return .red
        }
    }

    private func storageColorForVolume(_ volume: StorageVolume) -> Color {
        switch volume.storageInfo.usageColor {
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .red:
            return .red
        }
    }
}

#Preview {
    StorageCard()
        .frame(width: 140, height: 100)
        .background(Color.black)
}
