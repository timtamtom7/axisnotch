//
//  CalculatorCard.swift
//  boringNotch
//
//  Calculator card with state machine and expanded view
//

import SwiftUI
import Defaults

// MARK: - Calculator Card

struct CalculatorCard: View {
    @State private var isExpanded: Bool = false
    @StateObject private var calculator = CalculatorState()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.purple)
                    .font(.system(size: 10))
                Text("Calculator")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(calculator.display)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onTapGesture {
            isExpanded = true
        }
        .sheet(isPresented: $isExpanded) {
            CalculatorView(calculator: calculator, isPresented: $isExpanded)
                .frame(width: 280, height: 380)
        }
    }
}

// MARK: - Calculator State Machine

class CalculatorState: ObservableObject {
    enum Operation {
        case add, subtract, multiply, divide, none
    }

    enum CalculatorButton: String, CaseIterable {
        case zero = "0", one = "1", two = "2", three = "3", four = "4"
        case five = "5", six = "6", seven = "7", eight = "8", nine = "9"
        case add = "+", subtract = "-", multiply = "×", divide = "÷"
        case decimal = ".", equals = "=", clear = "C"
        case plusMinus = "±", percent = "%"

        var color: Color {
            switch self {
            case .add, .subtract, .multiply, .divide:
                return .orange
            case .equals:
                return .blue
            case .clear, .plusMinus, .percent:
                return .gray
            default:
                return .white.opacity(0.3)
            }
        }
    }

    @Published var display: String = "0"
    @Published var currentOperation: Operation = .none
    @Published var previousValue: Double = 0
    @Published var shouldResetDisplay: Bool = false
    @Published var memory: Double = 0

    func input(_ button: CalculatorButton) {
        switch button {
        case .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine:
            if shouldResetDisplay || display == "0" {
                display = button.rawValue
                shouldResetDisplay = false
            } else {
                display += button.rawValue
            }

        case .decimal:
            if !display.contains(".") {
                display += "."
            }

        case .add:
            setOperation(.add)
        case .subtract:
            setOperation(.subtract)
        case .multiply:
            setOperation(.multiply)
        case .divide:
            setOperation(.divide)

        case .equals:
            calculateResult()

        case .clear:
            display = "0"
            currentOperation = .none
            previousValue = 0
            shouldResetDisplay = false
            memory = 0

        case .plusMinus:
            if let value = Double(display) {
                display = formatResult(-value)
                shouldResetDisplay = true
            }

        case .percent:
            if let value = Double(display) {
                display = formatResult(value / 100)
                shouldResetDisplay = true
            }
        }
    }

    func memoryAdd() {
        if let value = Double(display) {
            memory += value
        }
    }

    func memorySubtract() {
        if let value = Double(display) {
            memory -= value
        }
    }

    func memoryRecall() {
        if memory != 0 {
            display = formatResult(memory)
            shouldResetDisplay = true
        }
    }

    func memoryClear() {
        memory = 0
    }

    private func setOperation(_ op: Operation) {
        if let value = Double(display) {
            if currentOperation != .none && !shouldResetDisplay {
                calculateResult()
            }
            previousValue = Double(display) ?? 0
            currentOperation = op
            shouldResetDisplay = true
        }
    }

    private func calculateResult() {
        guard currentOperation != .none,
              let currentValue = Double(display) else { return }

        var result: Double = 0

        switch currentOperation {
        case .add:
            result = previousValue + currentValue
        case .subtract:
            result = previousValue - currentValue
        case .multiply:
            result = previousValue * currentValue
        case .divide:
            if currentValue != 0 {
                result = previousValue / currentValue
            } else {
                display = "Error"
                currentOperation = .none
                return
            }
        case .none:
            return
        }

        display = formatResult(result)
        currentOperation = .none
        shouldResetDisplay = true
    }

    private func formatResult(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        } else {
            let result = String(format: "%.8g", value)
            return result
        }
    }
}

// MARK: - Calculator View (Expanded)

struct CalculatorView: View {
    @ObservedObject var calculator: CalculatorState
    @Binding var isPresented: Bool
    @Default(.showCalculator) private var showCalculator

    let buttonSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Calculator")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Display
            HStack {
                Spacer()
                Text(calculator.display)
                    .font(.system(size: 42, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            // Memory buttons
            HStack(spacing: 8) {
                MemoryButton(label: "MC", action: calculator.memoryClear)
                MemoryButton(label: "MR", action: calculator.memoryRecall)
                MemoryButton(label: "M+", action: calculator.memoryAdd)
                MemoryButton(label: "M-", action: calculator.memorySubtract)
            }
            .padding(.horizontal, 16)

            // Calculator buttons
            VStack(spacing: buttonSpacing) {
                // Row 1: C, +/-, %, ÷
                HStack(spacing: buttonSpacing) {
                    CalculatorButtonView(button: .clear, calculator: calculator)
                    CalculatorButtonView(button: .plusMinus, calculator: calculator)
                    CalculatorButtonView(button: .percent, calculator: calculator)
                    CalculatorButtonView(button: .divide, calculator: calculator)
                }
                // Row 2: 7, 8, 9, ×
                HStack(spacing: buttonSpacing) {
                    CalculatorButtonView(button: .seven, calculator: calculator)
                    CalculatorButtonView(button: .eight, calculator: calculator)
                    CalculatorButtonView(button: .nine, calculator: calculator)
                    CalculatorButtonView(button: .multiply, calculator: calculator)
                }
                // Row 3: 4, 5, 6, -
                HStack(spacing: buttonSpacing) {
                    CalculatorButtonView(button: .four, calculator: calculator)
                    CalculatorButtonView(button: .five, calculator: calculator)
                    CalculatorButtonView(button: .six, calculator: calculator)
                    CalculatorButtonView(button: .subtract, calculator: calculator)
                }
                // Row 4: 1, 2, 3, +
                HStack(spacing: buttonSpacing) {
                    CalculatorButtonView(button: .one, calculator: calculator)
                    CalculatorButtonView(button: .two, calculator: calculator)
                    CalculatorButtonView(button: .three, calculator: calculator)
                    CalculatorButtonView(button: .add, calculator: calculator)
                }
                // Row 5: 0, ., =
                HStack(spacing: buttonSpacing) {
                    CalculatorButtonView(button: .zero, calculator: calculator, isWide: true)
                    CalculatorButtonView(button: .decimal, calculator: calculator)
                    CalculatorButtonView(button: .equals, calculator: calculator)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.black.opacity(0.95))
        .cornerRadius(16)
    }
}

struct MemoryButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 50, height: 32)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct CalculatorButtonView: View {
    let button: CalculatorState.CalculatorButton
    @ObservedObject var calculator: CalculatorState
    var isWide: Bool = false

    var body: some View {
        Button(action: { calculator.input(button) }) {
            Text(button.rawValue)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(button == .zero ? .black : .white)
                .frame(width: isWide ? 106 : 50, height: 50)
                .background(button.color)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
