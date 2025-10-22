//
//  PercentageCalculatorTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
@testable import ABudget

final class PercentageCalculatorTests: XCTestCase {
    var calculator: PercentageCalculator!

    override func setUp() {
        super.setUp()
        calculator = PercentageCalculator()
    }

    override func tearDown() {
        calculator = nil
        super.tearDown()
    }

    // MARK: - Bucket Spending Tests

    func testCalculateBucketSpending() {
        // Given
        let transactions = [
            TestHelpers.createTransaction(subTotal: 100, bucket: .needs),
            TestHelpers.createTransaction(subTotal: 50, bucket: .wants),
            TestHelpers.createTransaction(subTotal: 75, bucket: .needs),
            TestHelpers.createTransaction(subTotal: 25, bucket: .savings)
        ]

        // When
        let needsSpending = calculator.calculateBucketSpending(bucket: .needs, transactions: transactions)
        let wantsSpending = calculator.calculateBucketSpending(bucket: .wants, transactions: transactions)
        let savingsSpending = calculator.calculateBucketSpending(bucket: .savings, transactions: transactions)

        // Then
        XCTAssertEqual(needsSpending, 192.5) // 110 + 82.5 (with default 10% tax)
        XCTAssertEqual(wantsSpending, 55)
        XCTAssertEqual(savingsSpending, 27.5)
    }

    func testCalculateAllBucketSpending() {
        // Given
        let transactions = [
            TestHelpers.createTransaction(subTotal: 100, bucket: .needs),
            TestHelpers.createTransaction(subTotal: 50, bucket: .wants),
            TestHelpers.createTransaction(subTotal: 25, bucket: .savings)
        ]

        // When
        let spending = calculator.calculateAllBucketSpending(transactions: transactions)

        // Then
        XCTAssertEqual(spending[.needs], 110)
        XCTAssertEqual(spending[.wants], 55)
        XCTAssertEqual(spending[.savings], 27.5)
    }

    // MARK: - Actual Percentage Tests

    func testCalculateActualPercentage() {
        // Given
        let transactions = [
            TestHelpers.createTransaction(subTotal: 1000, tax: 0, bucket: .needs),
            TestHelpers.createTransaction(subTotal: 500, tax: 0, bucket: .wants)
        ]
        let totalIncome: Decimal = 3000

        // When
        let needsPercent = calculator.calculateActualPercentage(
            bucket: .needs,
            transactions: transactions,
            totalIncome: totalIncome
        )
        let wantsPercent = calculator.calculateActualPercentage(
            bucket: .wants,
            transactions: transactions,
            totalIncome: totalIncome
        )

        // Then
        XCTAssertEqual(needsPercent, Decimal(1000) / 3000 * 100) // ~33.33%
        XCTAssertEqual(wantsPercent, Decimal(500) / 3000 * 100) // ~16.67%
    }

    func testCalculateActualPercentageZeroIncome() {
        // Given
        let transactions = [TestHelpers.createTransaction(subTotal: 100)]

        // When
        let percent = calculator.calculateActualPercentage(
            bucket: .needs,
            transactions: transactions,
            totalIncome: 0
        )

        // Then
        XCTAssertEqual(percent, 0)
    }

    func testCalculateAllActualPercentages() {
        // Given
        let transactions = [
            TestHelpers.createTransaction(subTotal: 1500, tax: 0, bucket: .needs),
            TestHelpers.createTransaction(subTotal: 900, tax: 0, bucket: .wants),
            TestHelpers.createTransaction(subTotal: 600, tax: 0, bucket: .savings)
        ]
        let totalIncome: Decimal = 3000

        // When
        let percentages = calculator.calculateAllActualPercentages(
            transactions: transactions,
            totalIncome: totalIncome
        )

        // Then
        XCTAssertEqual(percentages[.needs], 50)
        XCTAssertEqual(percentages[.wants], 30)
        XCTAssertEqual(percentages[.savings], 20)
    }

    // MARK: - Comparison to Target Tests

    func testCompareToTargetOnTrack() {
        // Given/When
        let comparison = calculator.compareToTarget(actual: 50, target: 50)

        // Then
        if case .onTrack(let diff) = comparison {
            XCTAssertEqual(diff, 0)
            XCTAssertTrue(comparison.isAcceptable)
        } else {
            XCTFail("Expected onTrack")
        }
    }

    func testCompareToTargetWithinAcceptableVariance() {
        // Given/When
        let comparison = calculator.compareToTarget(actual: 52, target: 50)

        // Then
        if case .onTrack(let diff) = comparison {
            XCTAssertEqual(diff, 2)
            XCTAssertTrue(comparison.isAcceptable)
        } else {
            XCTFail("Expected onTrack")
        }
    }

    func testCompareToTargetUnder() {
        // Given/When
        let comparison = calculator.compareToTarget(actual: 40, target: 50)

        // Then
        if case .underTarget(let diff) = comparison {
            XCTAssertEqual(diff, -10)
            XCTAssertFalse(comparison.isAcceptable)
            XCTAssertEqual(comparison.absoluteDifference, 10)
        } else {
            XCTFail("Expected underTarget")
        }
    }

    func testCompareToTargetOver() {
        // Given/When
        let comparison = calculator.compareToTarget(actual: 65, target: 50)

        // Then
        if case .overTarget(let diff) = comparison {
            XCTAssertEqual(diff, 15)
            XCTAssertFalse(comparison.isAcceptable)
            XCTAssertEqual(comparison.absoluteDifference, 15)
        } else {
            XCTFail("Expected overTarget")
        }
    }

    func testCompareAllToTargets() {
        // Given
        let settings = TestHelpers.createSettings(needs: 50, wants: 30, savings: 20)
        let transactions = [
            TestHelpers.createTransaction(subTotal: 1500, tax: 0, bucket: .needs),
            TestHelpers.createTransaction(subTotal: 1000, tax: 0, bucket: .wants),
            TestHelpers.createTransaction(subTotal: 500, tax: 0, bucket: .savings)
        ]
        let totalIncome: Decimal = 3000

        // When
        let comparisons = calculator.compareAllToTargets(
            transactions: transactions,
            totalIncome: totalIncome,
            settings: settings
        )

        // Then
        XCTAssertEqual(comparisons.count, 3)

        if case .onTrack = comparisons[.needs]! {
            // Success - 50% actual vs 50% target
        } else {
            XCTFail("Needs should be on track")
        }

        if case .overTarget = comparisons[.wants]! {
            // Success - ~33.3% actual vs 30% target
        } else {
            XCTFail("Wants should be over target")
        }
    }

    // MARK: - Percentage Validation Tests

    func testValidatePercentageAllocationValid() {
        XCTAssertTrue(calculator.validatePercentageAllocation(needs: 50, wants: 30, savings: 20))
        XCTAssertTrue(calculator.validatePercentageAllocation(needs: 70, wants: 20, savings: 10))
        XCTAssertTrue(calculator.validatePercentageAllocation(needs: 0, wants: 0, savings: 100))
    }

    func testValidatePercentageAllocationInvalidSum() {
        XCTAssertFalse(calculator.validatePercentageAllocation(needs: 50, wants: 30, savings: 30)) // Sum = 110
        XCTAssertFalse(calculator.validatePercentageAllocation(needs: 40, wants: 30, savings: 20)) // Sum = 90
    }

    func testValidatePercentageAllocationNegative() {
        XCTAssertFalse(calculator.validatePercentageAllocation(needs: -10, wants: 60, savings: 50))
        XCTAssertFalse(calculator.validatePercentageAllocation(needs: 50, wants: -10, savings: 60))
        XCTAssertFalse(calculator.validatePercentageAllocation(needs: 50, wants: 30, savings: -10))
    }

    func testValidatePercentageAllocationWithSettings() {
        let validSettings = TestHelpers.createSettings(needs: 50, wants: 30, savings: 20)
        XCTAssertTrue(calculator.validatePercentageAllocation(settings: validSettings))

        let invalidSettings = TestHelpers.createSettings(needs: 50, wants: 30, savings: 25)
        XCTAssertFalse(calculator.validatePercentageAllocation(settings: invalidSettings))
    }

    // MARK: - Target Amount Tests

    func testCalculateTargetAmount() {
        // Given
        let settings = TestHelpers.createSettings(needs: 50, wants: 30, savings: 20)
        let totalIncome: Decimal = 5000

        // When
        let needsTarget = calculator.calculateTargetAmount(forBucket: .needs, totalIncome: totalIncome, settings: settings)
        let wantsTarget = calculator.calculateTargetAmount(forBucket: .wants, totalIncome: totalIncome, settings: settings)
        let savingsTarget = calculator.calculateTargetAmount(forBucket: .savings, totalIncome: totalIncome, settings: settings)

        // Then
        XCTAssertEqual(needsTarget, 2500)
        XCTAssertEqual(wantsTarget, 1500)
        XCTAssertEqual(savingsTarget, 1000)
    }

    func testCalculateAllTargetAmounts() {
        // Given
        let settings = TestHelpers.createSettings(needs: 50, wants: 30, savings: 20)
        let totalIncome: Decimal = 6000

        // When
        let targets = calculator.calculateAllTargetAmounts(totalIncome: totalIncome, settings: settings)

        // Then
        XCTAssertEqual(targets[.needs], 3000)
        XCTAssertEqual(targets[.wants], 1800)
        XCTAssertEqual(targets[.savings], 1200)
    }

    // MARK: - Variance Tests

    func testCalculateVariance() {
        // Given
        let settings = TestHelpers.createSettings(needs: 50, wants: 30, savings: 20)
        let transactions = [
            TestHelpers.createTransaction(subTotal: 2000, tax: 0, bucket: .needs),
            TestHelpers.createTransaction(subTotal: 500, tax: 0, bucket: .needs)
        ]
        let totalIncome: Decimal = 5000

        // When
        let variance = calculator.calculateVariance(
            forBucket: .needs,
            transactions: transactions,
            totalIncome: totalIncome,
            settings: settings
        )

        // Then
        // Target = 2500 (50% of 5000), Actual = 2500, Variance = 0
        XCTAssertEqual(variance, 0)
    }

    func testCalculateVarianceOverTarget() {
        // Given
        let settings = TestHelpers.createSettings(needs: 50, wants: 30, savings: 20)
        let transactions = [
            TestHelpers.createTransaction(subTotal: 3000, tax: 0, bucket: .needs)
        ]
        let totalIncome: Decimal = 5000

        // When
        let variance = calculator.calculateVariance(
            forBucket: .needs,
            transactions: transactions,
            totalIncome: totalIncome,
            settings: settings
        )

        // Then
        // Target = 2500, Actual = 3000, Variance = +500
        XCTAssertEqual(variance, 500)
    }

    func testCalculateAllVariances() {
        // Given
        let settings = TestHelpers.createSettings(needs: 50, wants: 30, savings: 20)
        let transactions = [
            TestHelpers.createTransaction(subTotal: 2600, tax: 0, bucket: .needs),
            TestHelpers.createTransaction(subTotal: 1400, tax: 0, bucket: .wants),
            TestHelpers.createTransaction(subTotal: 1000, tax: 0, bucket: .savings)
        ]
        let totalIncome: Decimal = 5000

        // When
        let variances = calculator.calculateAllVariances(
            transactions: transactions,
            totalIncome: totalIncome,
            settings: settings
        )

        // Then
        XCTAssertEqual(variances[.needs], 100) // 2600 - 2500
        XCTAssertEqual(variances[.wants], -100) // 1400 - 1500
        XCTAssertEqual(variances[.savings], 0) // 1000 - 1000
    }

    // MARK: - Remaining Budget Tests

    func testCalculateRemainingBudget() {
        // Given
        let settings = TestHelpers.createSettings(needs: 50, wants: 30, savings: 20)
        let transactions = [
            TestHelpers.createTransaction(subTotal: 1500, tax: 0, bucket: .needs)
        ]
        let totalIncome: Decimal = 5000

        // When
        let remaining = calculator.calculateRemainingBudget(
            forBucket: .needs,
            transactions: transactions,
            totalIncome: totalIncome,
            settings: settings
        )

        // Then
        // Target = 2500, Spent = 1500, Remaining = 1000
        XCTAssertEqual(remaining, 1000)
    }

    func testCalculateRemainingBudgetOverSpent() {
        // Given
        let settings = TestHelpers.createSettings(needs: 50, wants: 30, savings: 20)
        let transactions = [
            TestHelpers.createTransaction(subTotal: 3000, tax: 0, bucket: .needs)
        ]
        let totalIncome: Decimal = 5000

        // When
        let remaining = calculator.calculateRemainingBudget(
            forBucket: .needs,
            transactions: transactions,
            totalIncome: totalIncome,
            settings: settings
        )

        // Then
        // Target = 2500, Spent = 3000, Remaining = -500
        XCTAssertEqual(remaining, -500)
    }

    // MARK: - Edge Cases

    func testCalculateActualPercentageEmptyTransactions() {
        let percent = calculator.calculateActualPercentage(
            bucket: .needs,
            transactions: [],
            totalIncome: 5000
        )
        XCTAssertEqual(percent, 0)
    }

    func testSafeCalculatePercentageZeroIncome() {
        let percent = calculator.safeCalculatePercentage(amount: 1000, totalIncome: 0)
        XCTAssertEqual(percent, 0)
    }

    func testSafeCalculatePercentageNormalCase() {
        let percent = calculator.safeCalculatePercentage(amount: 1500, totalIncome: 5000)
        XCTAssertEqual(percent, 30)
    }
}
