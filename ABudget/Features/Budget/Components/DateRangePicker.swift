//
//  DateRangePicker.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Component for selecting a date range
struct DateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DatePicker("Start Date",
                      selection: $startDate,
                      displayedComponents: .date)

            DatePicker("End Date",
                      selection: $endDate,
                      in: startDate...,
                      displayedComponents: .date)

            if startDate < endDate {
                Text("Duration: \(durationText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var durationText: String {
        let components = Calendar.current.dateComponents([.day], from: startDate, to: endDate)
        let days = components.day ?? 0

        if days < 30 {
            return "\(days) days"
        } else {
            let months = days / 30
            let remainingDays = days % 30
            if remainingDays == 0 {
                return "\(months) month\(months == 1 ? "" : "s")"
            } else {
                return "\(months) month\(months == 1 ? "" : "s"), \(remainingDays) day\(remainingDays == 1 ? "" : "s")"
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var startDate = Date()
        @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!

        var body: some View {
            Form {
                DateRangePicker(startDate: $startDate, endDate: $endDate)
            }
        }
    }

    return PreviewWrapper()
}
