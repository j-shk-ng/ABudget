//
//  BudgetPeriodCreationView.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Main container view for the multi-step budget period creation flow
struct BudgetPeriodCreationView: View {
    @ObservedObject var viewModel: BudgetPeriodViewModel
    @Environment(\.dismiss) var dismiss

    @State private var categories: [CategoryDTO] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressIndicator(
                    currentStep: viewModel.currentStep,
                    totalSteps: CreationStep.allCases.count
                )
                .padding()

                // Current step view
                TabView(selection: $viewModel.currentStep) {
                    BudgetMethodologyView(
                        selectedMethodology: $viewModel.selectedMethodology
                    )
                    .tag(CreationStep.methodology)

                    BudgetDateRangeView(
                        startDate: $viewModel.startDate,
                        endDate: $viewModel.endDate,
                        validationErrors: $viewModel.validationErrors
                    )
                    .tag(CreationStep.dateRange)

                    IncomeSourcesView(
                        incomeSources: $viewModel.incomeSources,
                        validationErrors: $viewModel.validationErrors,
                        onAdd: viewModel.addIncome,
                        onRemove: viewModel.removeIncome,
                        onUpdate: viewModel.updateIncome
                    )
                    .tag(CreationStep.incomeSources)

                    CategoryAllocationsView(
                        allocations: $viewModel.allocations,
                        categories: categories,
                        totalIncome: viewModel.totalIncome,
                        onUpdateAllocation: viewModel.updateAllocation
                    )
                    .tag(CreationStep.allocations)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .disabled(true) // Disable swipe navigation, use buttons instead

                Divider()

                // Navigation buttons
                HStack(spacing: 16) {
                    if !viewModel.currentStep.isFirst {
                        Button("Back") {
                            viewModel.previousStep()
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button("Cancel") {
                        viewModel.cancelCreation()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)

                    if viewModel.currentStep.isLast {
                        Button("Create Budget") {
                            Task {
                                let success = await viewModel.createBudgetPeriod()
                                if success {
                                    dismiss()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoading)
                    } else {
                        Button("Next") {
                            viewModel.nextStep()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("New Budget Period")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Load categories when allocations step is reached
                if viewModel.currentStep == .allocations {
                    await loadCategories()
                }
            }
            .onChange(of: viewModel.currentStep) { _, newStep in
                if newStep == .allocations {
                    Task {
                        await loadCategories()
                        await viewModel.loadCategoriesForAllocation()
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
            }
        }
    }

    private func loadCategories() async {
        let repository = CoreDataCategoryRepository()
        do {
            categories = try await repository.fetchRootCategories()
        } catch {
            // Silent failure - empty categories will show empty state
            categories = []
        }
    }
}

/// Progress indicator showing current step in the creation flow
struct ProgressIndicator: View {
    let currentStep: CreationStep
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 8) {
            // Step indicators
            HStack(spacing: 8) {
                ForEach(CreationStep.allCases, id: \.self) { step in
                    StepCircle(
                        step: step,
                        isActive: step.rawValue <= currentStep.rawValue
                    )

                    if step != CreationStep.allCases.last {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }

            // Step title
            Text(currentStep.title)
                .font(.headline)
                .foregroundColor(.primary)

            // Step counter
            Text("Step \(currentStep.rawValue + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Individual step circle in the progress indicator
struct StepCircle: View {
    let step: CreationStep
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)

            Text("\(step.rawValue + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isActive ? .white : .gray)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = BudgetPeriodViewModel()

        var body: some View {
            BudgetPeriodCreationView(viewModel: viewModel)
        }
    }

    return PreviewWrapper()
}
