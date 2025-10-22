//
//  TestHelpers.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import Foundation
@testable import ABudget

/// Helper class for creating mock data in tests
enum TestHelpers {

    // MARK: - Transaction Helpers

    static func createTransaction(
        id: UUID = UUID(),
        date: Date = Date(),
        subTotal: Decimal = 100,
        tax: Decimal? = 10,
        merchant: String = "Test Merchant",
        bucket: BucketType = .needs,
        categoryId: UUID? = nil,
        subCategoryId: UUID? = nil,
        budgetPeriodId: UUID? = nil
    ) -> TransactionDTO {
        TransactionDTO(
            id: id,
            date: date,
            subTotal: subTotal,
            tax: tax,
            merchant: merchant,
            bucket: bucket,
            categoryId: categoryId,
            subCategoryId: subCategoryId,
            budgetPeriodId: budgetPeriodId
        )
    }

    static func createTransactions(count: Int, bucket: BucketType = .needs) -> [TransactionDTO] {
        (0..<count).map { i in
            createTransaction(
                subTotal: Decimal(50 + i * 10),
                merchant: "Merchant \(i)",
                bucket: bucket
            )
        }
    }

    // MARK: - Budget Period Helpers

    static func createBudgetPeriod(
        id: UUID = UUID(),
        methodology: BudgetMethodology = .zeroBased,
        startDate: Date = Date(),
        endDate: Date? = nil,
        incomeSources: [IncomeSourceDTO] = []
    ) -> BudgetPeriodDTO {
        let end = endDate ?? Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
        return BudgetPeriodDTO(
            id: id,
            methodology: methodology,
            startDate: startDate,
            endDate: end,
            incomeSources: incomeSources.isEmpty ? [createIncomeSource()] : incomeSources
        )
    }

    static func createSequentialPeriods(count: Int, monthsApart: Int = 1) -> [BudgetPeriodDTO] {
        (0..<count).map { i in
            let startDate = Calendar.current.date(byAdding: .month, value: i * monthsApart, to: Date())!
            return createBudgetPeriod(startDate: startDate)
        }
    }

    // MARK: - Income Source Helpers

    static func createIncomeSource(
        id: UUID = UUID(),
        sourceName: String = "Salary",
        amount: Decimal = 5000
    ) -> IncomeSourceDTO {
        IncomeSourceDTO(
            id: id,
            sourceName: sourceName,
            amount: amount
        )
    }

    // MARK: - Category Helpers

    static func createCategory(
        id: UUID = UUID(),
        name: String = "Test Category"
    ) -> CategoryDTO {
        CategoryDTO(
            id: id,
            name: name
        )
    }

    // MARK: - Allocation Helpers

    static func createAllocation(
        id: UUID = UUID(),
        plannedAmount: Decimal = 1000,
        carryOverAmount: Decimal = 0,
        budgetPeriodId: UUID? = nil,
        categoryId: UUID? = nil
    ) -> CategoryAllocationDTO {
        CategoryAllocationDTO(
            id: id,
            plannedAmount: plannedAmount,
            carryOverAmount: carryOverAmount,
            budgetPeriodId: budgetPeriodId,
            categoryId: categoryId
        )
    }

    static func createAllocations(
        count: Int,
        budgetPeriodId: UUID,
        categoryIds: [UUID]
    ) -> [CategoryAllocationDTO] {
        (0..<min(count, categoryIds.count)).map { i in
            createAllocation(
                plannedAmount: Decimal(500 + i * 100),
                budgetPeriodId: budgetPeriodId,
                categoryId: categoryIds[i]
            )
        }
    }

    // MARK: - Settings Helpers

    static func createSettings(
        needs: Decimal = 50,
        wants: Decimal = 30,
        savings: Decimal = 20
    ) -> UserSettingsDTO {
        UserSettingsDTO(
            needsPercentage: needs,
            wantsPercentage: wants,
            savingsPercentage: savings
        )
    }

    // MARK: - Date Helpers

    static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    static func addDays(_ days: Int, to date: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date)!
    }

    static func addMonths(_ months: Int, to date: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: date)!
    }

    // MARK: - Scenario Builders

    /// Creates a complete budget scenario for testing
    static func createBudgetScenario(
        income: Decimal = 5000,
        categoryCount: Int = 3,
        transactionCount: Int = 10
    ) -> BudgetScenario {
        let period = createBudgetPeriod(
            incomeSources: [createIncomeSource(amount: income)]
        )

        let categories = (0..<categoryCount).map { i in
            createCategory(name: "Category \(i)")
        }

        let allocations = categories.enumerated().map { index, category in
            createAllocation(
                plannedAmount: Decimal(300 + index * 100),
                budgetPeriodId: period.id,
                categoryId: category.id
            )
        }

        let transactions = (0..<transactionCount).map { i in
            let categoryIndex = i % categories.count
            return createTransaction(
                date: period.startDate,
                subTotal: Decimal(50 + i * 10),
                bucket: .needs,
                categoryId: categories[categoryIndex].id,
                budgetPeriodId: period.id
            )
        }

        return BudgetScenario(
            period: period,
            categories: categories,
            allocations: allocations,
            transactions: transactions
        )
    }
}

// MARK: - Test Scenario Type

struct BudgetScenario {
    let period: BudgetPeriodDTO
    let categories: [CategoryDTO]
    let allocations: [CategoryAllocationDTO]
    let transactions: [TransactionDTO]
}
