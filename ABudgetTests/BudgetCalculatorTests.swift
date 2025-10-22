//
//  BudgetCalculatorTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
@testable import ABudget

final class BudgetCalculatorTests: XCTestCase {
    var calculator: BudgetCalculator!

    override func setUp() {
        super.setUp()
        calculator = BudgetCalculator()
    }

    override func tearDown() {
        calculator = nil
        super.tearDown()
    }

    // MARK: - Spent Amount Tests

    func testCalculateSpentAmountForCategory() {
        // Given
        let categoryId = UUID()
        let transactions = [
            TestHelpers.createTransaction(subTotal: 50, tax: 5, categoryId: categoryId),
            TestHelpers.createTransaction(subTotal: 100, tax: 10, categoryId: categoryId),
            TestHelpers.createTransaction(subTotal: 75, tax: nil, categoryId: categoryId)
        ]

        // When
        let spent = calculator.calculateSpentAmount(forCategoryId: categoryId, in: transactions)

        // Then
        XCTAssertEqual(spent, 240) // 55 + 110 + 75
    }

    func testCalculateSpentAmountForCategoryIncludesSubcategory() {
        // Given
        let categoryId = UUID()
        let transactions = [
            TestHelpers.createTransaction(subTotal: 50, categoryId: categoryId),
            TestHelpers.createTransaction(subTotal: 100, subCategoryId: categoryId)
        ]

        // When
        let spent = calculator.calculateSpentAmount(forCategoryId: categoryId, in: transactions)

        // Then
        XCTAssertEqual(spent, 160) // Both included
    }

    func testCalculateTotalSpent() {
        // Given
        let transactions = [
            TestHelpers.createTransaction(subTotal: 50, tax: 5),
            TestHelpers.createTransaction(subTotal: 100, tax: nil),
            TestHelpers.createTransaction(subTotal: 75, tax: 7.5)
        ]

        // When
        let total = calculator.calculateTotalSpent(in: transactions)

        // Then
        XCTAssertEqual(total, 237.5)
    }

    func testCalculateSpentAmountForBucket() {
        // Given
        let transactions = [
            TestHelpers.createTransaction(subTotal: 100, bucket: .needs),
            TestHelpers.createTransaction(subTotal: 50, bucket: .wants),
            TestHelpers.createTransaction(subTotal: 75, bucket: .needs)
        ]

        // When
        let needsSpent = calculator.calculateSpentAmount(forBucket: .needs, in: transactions)
        let wantsSpent = calculator.calculateSpentAmount(forBucket: .wants, in: transactions)

        // Then
        XCTAssertEqual(needsSpent, 185)
        XCTAssertEqual(wantsSpent, 60)
    }

    // MARK: - Remaining Amount Tests

    func testCalculateRemainingAmount() {
        XCTAssertEqual(calculator.calculateRemainingAmount(planned: 1000, spent: 600), 400)
        XCTAssertEqual(calculator.calculateRemainingAmount(planned: 500, spent: 500), 0)
        XCTAssertEqual(calculator.calculateRemainingAmount(planned: 300, spent: 400), -100)
    }

    func testCalculateRemainingAmountForAllocation() {
        // Given
        let allocation = TestHelpers.createAllocation(plannedAmount: 1000, carryOverAmount: 100)

        // When
        let remaining = calculator.calculateRemainingAmount(forAllocation: allocation, spent: 600)

        // Then
        XCTAssertEqual(remaining, 500) // 1100 - 600
    }

    // MARK: - Carry Over Tests

    func testCalculateCarryOverPositive() {
        // Given
        let categoryId = UUID()
        let allocation = TestHelpers.createAllocation(
            plannedAmount: 1000,
            carryOverAmount: 100,
            categoryId: categoryId
        )
        let transactions = [
            TestHelpers.createTransaction(subTotal: 600, categoryId: categoryId)
        ]

        // When
        let carryOver = calculator.calculateCarryOver(
            forCategoryId: categoryId,
            previousAllocation: allocation,
            previousTransactions: transactions
        )

        // Then
        XCTAssertEqual(carryOver, 510) // 1100 - 590 (600 with default 10 tax)
    }

    func testCalculateCarryOverOverBudget() {
        // Given
        let categoryId = UUID()
        let allocation = TestHelpers.createAllocation(plannedAmount: 500, categoryId: categoryId)
        let transactions = [
            TestHelpers.createTransaction(subTotal: 600, categoryId: categoryId)
        ]

        // When
        let carryOver = calculator.calculateCarryOver(
            forCategoryId: categoryId,
            previousAllocation: allocation,
            previousTransactions: transactions
        )

        // Then
        XCTAssertEqual(carryOver, 0) // No carry over when over budget
    }

    func testCalculateAllCarryOvers() {
        // Given
        let cat1 = UUID()
        let cat2 = UUID()
        let allocations = [
            TestHelpers.createAllocation(plannedAmount: 1000, categoryId: cat1),
            TestHelpers.createAllocation(plannedAmount: 500, categoryId: cat2)
        ]
        let transactions = [
            TestHelpers.createTransaction(subTotal: 500, categoryId: cat1),
            TestHelpers.createTransaction(subTotal: 200, categoryId: cat2)
        ]

        // When
        let carryOvers = calculator.calculateAllCarryOvers(
            from: allocations,
            previousTransactions: transactions
        )

        // Then
        XCTAssertEqual(carryOvers.count, 2)
        XCTAssertEqual(carryOvers[cat1], 450) // 1000 - 550
        XCTAssertEqual(carryOvers[cat2], 290) // 500 - 210
    }

    // MARK: - Budget Period Totals Tests

    func testCalculateBudgetPeriodTotals() {
        // Given
        let period = TestHelpers.createBudgetPeriod(
            incomeSources: [TestHelpers.createIncomeSource(amount: 5000)]
        )
        let allocations = [
            TestHelpers.createAllocation(plannedAmount: 2000),
            TestHelpers.createAllocation(plannedAmount: 1500)
        ]
        let transactions = [
            TestHelpers.createTransaction(subTotal: 1000),
            TestHelpers.createTransaction(subTotal: 500)
        ]

        // When
        let totals = calculator.calculateBudgetPeriodTotals(
            period: period,
            allocations: allocations,
            transactions: transactions
        )

        // Then
        XCTAssertEqual(totals.totalIncome, 5000)
        XCTAssertEqual(totals.totalPlanned, 3500)
        XCTAssertEqual(totals.totalSpent, 1650) // 1100 + 550 (with default tax)
        XCTAssertEqual(totals.totalRemaining, 1850)
    }

    func testBudgetPeriodTotalsComputedProperties() {
        // Given
        let totals = BudgetPeriodTotals(
            totalIncome: 5000,
            totalPlanned: 4000,
            totalSpent: 3000,
            totalRemaining: 1000
        )

        // Then
        XCTAssertEqual(totals.plannedPercentage, 80) // 4000/5000
        XCTAssertEqual(totals.spentPercentage, 60) // 3000/5000
        XCTAssertEqual(totals.executionPercentage, 75) // 3000/4000
        XCTAssertFalse(totals.isOverAllocated)
        XCTAssertFalse(totals.isOverBudget)
    }

    func testBudgetPeriodTotalsOverAllocated() {
        // Given
        let totals = BudgetPeriodTotals(
            totalIncome: 3000,
            totalPlanned: 4000,
            totalSpent: 2000,
            totalRemaining: 2000
        )

        // Then
        XCTAssertTrue(totals.isOverAllocated)
    }

    // MARK: - Budget Health Tests

    func testCalculateBudgetUtilization() {
        XCTAssertEqual(calculator.calculateBudgetUtilization(planned: 1000, spent: 500), 50)
        XCTAssertEqual(calculator.calculateBudgetUtilization(planned: 1000, spent: 1000), 100)
        XCTAssertEqual(calculator.calculateBudgetUtilization(planned: 1000, spent: 1200), 120)
        XCTAssertEqual(calculator.calculateBudgetUtilization(planned: 0, spent: 500), 0)
    }

    func testIsOverBudget() {
        // Given
        let allocation = TestHelpers.createAllocation(plannedAmount: 1000, carryOverAmount: 100)

        // Then
        XCTAssertFalse(calculator.isOverBudget(allocation: allocation, spent: 1000))
        XCTAssertFalse(calculator.isOverBudget(allocation: allocation, spent: 1100))
        XCTAssertTrue(calculator.isOverBudget(allocation: allocation, spent: 1200))
    }

    func testCalculateOverBudgetAmount() {
        // Given
        let allocation = TestHelpers.createAllocation(plannedAmount: 1000)

        // When/Then
        XCTAssertEqual(calculator.calculateOverBudgetAmount(allocation: allocation, spent: 800), 0)
        XCTAssertEqual(calculator.calculateOverBudgetAmount(allocation: allocation, spent: 1000), 0)
        XCTAssertEqual(calculator.calculateOverBudgetAmount(allocation: allocation, spent: 1200), 200)
    }

    // MARK: - Projection Tests

    func testProjectEndOfPeriodSpending() {
        // Given
        let startDate = TestHelpers.date(year: 2025, month: 1, day: 1)
        let endDate = TestHelpers.date(year: 2025, month: 1, day: 31) // 31 days
        let period = TestHelpers.createBudgetPeriod(startDate: startDate, endDate: endDate)

        let currentDate = TestHelpers.date(year: 2025, month: 1, day: 11) // 10 days elapsed
        let currentSpent: Decimal = 1000

        // When
        let projected = calculator.projectEndOfPeriodSpending(
            currentSpent: currentSpent,
            period: period,
            asOfDate: currentDate
        )

        // Then
        // 1000 / 10 days = 100/day * 31 days = 3100
        XCTAssertEqual(projected, 3100)
    }

    func testCalculateDailySpendingLimit() {
        // Given
        let startDate = TestHelpers.date(year: 2025, month: 1, day: 1)
        let endDate = TestHelpers.date(year: 2025, month: 1, day: 31)
        let period = TestHelpers.createBudgetPeriod(startDate: startDate, endDate: endDate)

        let allocation = TestHelpers.createAllocation(plannedAmount: 1000)
        let spent: Decimal = 600

        let currentDate = TestHelpers.date(year: 2025, month: 1, day: 21) // 10 days remaining

        // When
        let dailyLimit = calculator.calculateDailySpendingLimit(
            allocation: allocation,
            spent: spent,
            period: period,
            asOfDate: currentDate
        )

        // Then
        // (1000 - 600) / 10 = 40 per day
        XCTAssertEqual(dailyLimit, 40)
    }

    func testCalculateDailySpendingLimitOverBudget() {
        // Given
        let period = TestHelpers.createBudgetPeriod()
        let allocation = TestHelpers.createAllocation(plannedAmount: 500)
        let spent: Decimal = 600

        // When
        let dailyLimit = calculator.calculateDailySpendingLimit(
            allocation: allocation,
            spent: spent,
            period: period
        )

        // Then
        XCTAssertEqual(dailyLimit, 0)
    }

    // MARK: - Edge Cases

    func testCalculateSpentAmountEmptyTransactions() {
        let spent = calculator.calculateSpentAmount(forCategoryId: UUID(), in: [])
        XCTAssertEqual(spent, 0)
    }

    func testCalculateTotalSpentEmptyTransactions() {
        let total = calculator.calculateTotalSpent(in: [])
        XCTAssertEqual(total, 0)
    }

    func testCalculateCarryOverNilAllocation() {
        let carryOver = calculator.calculateCarryOver(
            forCategoryId: UUID(),
            previousAllocation: nil,
            previousTransactions: []
        )
        XCTAssertEqual(carryOver, 0)
    }
}
