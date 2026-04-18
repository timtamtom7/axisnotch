//
//  StorageCard.swift
//  boringNotch
//
//  Storage card showing disk usage
//

import SwiftUI

struct StorageCard: View {
    @ObservedObject private var manager = StorageManager.shared

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
            } else {
                // Storage bar
                VStack(alignment: .leading, spacing: 2) {
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

                    Text("\(manager.totalStorage.formattedUsed) / \(manager.totalStorage.formattedTotal) used")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .onAppear {
            manager.refreshStorage()
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
}

#Preview {
    StorageCard()
        .frame(width: 140, height: 100)
        .background(Color.black)
}
