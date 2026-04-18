//
//  FocusModeIndicator.swift
//  boringNotch
//
//  Focus mode indicator pill for the notch header
//

import SwiftUI
import Defaults

struct FocusModeIndicator: View {
    @ObservedObject var focusManager = FocusModeManager.shared
    @Default(.showFocusMode) var showFocusMode

    @State private var isPressed: Bool = false

    var body: some View {
        if showFocusMode {
            Button(action: {
                focusManager.toggleDND()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: focusIcon)
                        .font(.system(size: 10, weight: .medium))
                    Text(focusManager.focusName)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(focusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(focusBackgroundColor)
                        .overlay(
                            Capsule()
                                .stroke(focusBorderColor, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }, perform: {})
        }
    }

    private var focusIcon: String {
        if focusManager.isFocusActive {
            return "moon.fill"
        }
        return "moon"
    }

    private var focusColor: Color {
        if focusManager.isFocusActive {
            return .purple
        }
        return .gray
    }

    private var focusBackgroundColor: Color {
        if focusManager.isFocusActive {
            return Color.purple.opacity(0.2)
        }
        return Color.gray.opacity(0.1)
    }

    private var focusBorderColor: Color {
        if focusManager.isFocusActive {
            return Color.purple.opacity(0.5)
        }
        return Color.gray.opacity(0.3)
    }
}

#Preview {
    HStack {
        FocusModeIndicator()
        Spacer()
    }
    .padding()
    .background(Color.black)
    .frame(width: 300)
}