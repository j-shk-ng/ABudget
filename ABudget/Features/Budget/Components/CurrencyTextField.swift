//
//  CurrencyTextField.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Text field specialized for currency/decimal input with proper formatting
struct CurrencyTextField: View {
    let title: String
    @Binding var amount: Decimal

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.decimalPad)
            .focused($isFocused)
            .onChange(of: text) { _, newValue in
                updateAmountFromText(newValue)
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    // When focused, show plain number for editing
                    text = amount == 0 ? "" : "\(amount)"
                } else {
                    // When unfocused, format as currency
                    formatText()
                }
            }
            .onAppear {
                formatText()
            }
    }

    private func updateAmountFromText(_ newValue: String) {
        // Remove currency symbols and commas
        let cleaned = newValue
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        if let decimal = Decimal(string: cleaned) {
            amount = decimal
        } else if cleaned.isEmpty {
            amount = 0
        }
    }

    private func formatText() {
        if amount == 0 {
            text = ""
        } else {
            text = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var amount: Decimal = 1234.56

        var body: some View {
            Form {
                CurrencyTextField(title: "Amount", amount: $amount)
                Text("Current value: \(amount as NSDecimalNumber, formatter: currencyFormatter)")
            }
        }

        private var currencyFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            return formatter
        }
    }

    return PreviewWrapper()
}
