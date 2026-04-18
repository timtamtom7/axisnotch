//
//  NotchControlCard.swift
//  boringNotch
//
//  Notch control card for showing/hiding the notch
//

import SwiftUI

// MARK: - Notch Control Card

struct NotchControlCard: View {
    let onHide: () -> Void
    let onShow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "rectangle.and.arrow.up.right")
                    .foregroundColor(.pink)
                    .font(.system(size: 10))
                Text("Notch")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onHide) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.down.left.and.arrow.up.right")
                            .font(.system(size: 12))
                        Text("Hide")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.white)
                    .frame(width: 44, height: 36)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: onShow) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up.right.and.arrow.down.left")
                            .font(.system(size: 12))
                        Text("Show")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.white)
                    .frame(width: 44, height: 36)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }
}
