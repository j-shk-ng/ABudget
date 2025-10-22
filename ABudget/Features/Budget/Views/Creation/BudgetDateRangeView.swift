//
//  BudgetDateRangeView.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Step 2: Budget date range selection view
struct BudgetDateRangeView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var validationErrors: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Set Budget Period")
                .font(.title2)
                .fontWeight(.bold)

            Text("Choose the start and end dates for this budget period. Most users create monthly budgets.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Quick presets
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Presets")
                    .font(.headline)

                HStack(spacing: 12) {
                    PresetButton(title: "This Month") {
                        setCurrentMonth()
                    }

                    PresetButton(title: "Next Month") {
                        setNextMonth()
                    }
                }

                HStack(spacing: 12) {
                    PresetButton(title: "This Quarter") {
                        setCurrentQuarter()
                    }

                    PresetButton(title: "Custom") {
                        // Already custom, do nothing
                    }
                }
            }
            .padding(.vertical)

            // Date pickers
            VStack(alignment: .leading, spacing: 16) {
                Text("Custom Dates")
                    .font(.headline)

                DateRangePicker(startDate: $startDate, endDate: $endDate)
            }

            // Validation errors
            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(validationErrors, id: \.self) { error in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
    }

    private func setCurrentMonth() {
        let calendar = Calendar.current
        let now = Date()
        startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate)!
    }

    private func setNextMonth() {
        let calendar = Calendar.current
        let now = Date()
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now)!
        startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth))!
        endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate)!
    }

    private func setCurrentQuarter() {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)

        // Find the start month of current quarter (1, 4, 7, or 10)
        let quarterStartMonth = ((month - 1) / 3) * 3 + 1

        var startComponents = calendar.dateComponents([.year], from: now)
        startComponents.month = quarterStartMonth
        startComponents.day = 1

        startDate = calendar.date(from: startComponents)!
        endDate = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: startDate)!
    }
}

/// Button for date range presets
struct PresetButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var startDate = Date()
        @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        @State private var errors: [String] = []

        var body: some View {
            NavigationStack {
                BudgetDateRangeView(
                    startDate: $startDate,
                    endDate: $endDate,
                    validationErrors: $errors
                )
            }
        }
    }

    return PreviewWrapper()
}
