//
//  BudgetListView.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Main Budget tab view showing budget periods and summary
struct BudgetListView: View {
    @StateObject private var viewModel = BudgetPeriodViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if viewModel.budgetPeriods.isEmpty {
                    EmptyBudgetView(onCreateBudget: {
                        viewModel.startCreation()
                    })
                } else {
                    BudgetContentView(viewModel: viewModel)
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.startCreation()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreationSheet) {
                BudgetPeriodCreationView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadExistingPeriods()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
}

/// Content view when budget periods exist
struct BudgetContentView: View {
    @ObservedObject var viewModel: BudgetPeriodViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                if viewModel.budgetPeriods.count > 1 {
                    PeriodSelectorView(
                        periods: viewModel.budgetPeriods,
                        selectedPeriod: $viewModel.selectedPeriod
                    )
                    .padding(.horizontal)
                }

                // Current period summary
                if let selectedPeriod = viewModel.selectedPeriod {
                    BudgetPeriodSummaryCard(period: selectedPeriod)
                        .padding(.horizontal)
                }

                // Quick actions
                QuickActionsCard()
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
    }
}

/// Period selector dropdown
struct PeriodSelectorView: View {
    let periods: [BudgetPeriodDTO]
    @Binding var selectedPeriod: BudgetPeriodDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Budget Period")
                .font(.caption)
                .foregroundColor(.secondary)

            Menu {
                ForEach(periods) { period in
                    Button {
                        selectedPeriod = period
                    } label: {
                        HStack {
                            Text(period.dateRange)
                            if period.isActive {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let period = selectedPeriod {
                            Text(period.dateRange)
                                .font(.headline)
                            if period.isActive {
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10)
            }
        }
    }
}

/// Summary card for the selected budget period
struct BudgetPeriodSummaryCard: View {
    let period: BudgetPeriodDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(period.dateRange)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(period.methodology.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if period.isActive {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }

            Divider()

            // Income summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(period.totalIncome, format: .currency(code: "USD"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Income Sources")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(period.incomeSources.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }

            // Income sources breakdown
            if !period.incomeSources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(period.incomeSources) { source in
                        HStack {
                            Text(source.sourceName)
                                .font(.subheadline)
                            Spacer()
                            Text(source.amount, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Quick actions card
struct QuickActionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Add Transaction",
                    color: .blue
                ) {
                    // TODO: Navigate to add transaction
                }

                QuickActionButton(
                    icon: "chart.bar.fill",
                    title: "View Reports",
                    color: .purple
                ) {
                    // TODO: Navigate to reports
                }

                QuickActionButton(
                    icon: "slider.horizontal.3",
                    title: "Adjust Budget",
                    color: .orange
                ) {
                    // TODO: Navigate to budget adjustment
                }

                QuickActionButton(
                    icon: "folder.fill",
                    title: "Categories",
                    color: .green
                ) {
                    // TODO: Navigate to categories
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
    }
}

/// Quick action button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

/// Empty state view when no budget periods exist
struct EmptyBudgetView: View {
    let onCreateBudget: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("No Budget Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Create your first budget to start tracking your finances and take control of your spending.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: onCreateBudget) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Budget")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: 280)
                .background(Color.blue)
                .cornerRadius(12)
            }

            VStack(spacing: 16) {
                Text("Getting Started")
                    .font(.headline)
                    .padding(.top)

                VStack(alignment: .leading, spacing: 12) {
                    GettingStartedStep(number: 1, text: "Choose your budget method")
                    GettingStartedStep(number: 2, text: "Set your budget period dates")
                    GettingStartedStep(number: 3, text: "Add your income sources")
                    GettingStartedStep(number: 4, text: "Allocate money to categories")
                }
                .padding(.horizontal, 40)
            }
        }
        .padding()
    }
}

/// Getting started step indicator
struct GettingStartedStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

#Preview {
    BudgetListView()
}

#Preview("With Budget") {
    struct PreviewWrapper: View {
        @StateObject private var viewModel: BudgetPeriodViewModel = {
            let vm = BudgetPeriodViewModel()
            // Mock data would be set here
            return vm
        }()

        var body: some View {
            BudgetListView()
        }
    }

    return PreviewWrapper()
}
