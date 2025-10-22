//
//  ValidationRulesTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
@testable import ABudget

final class ValidationRulesTests: XCTestCase {

    // MARK: - Transaction Validation Tests

    func testValidateTransactionSuccess() throws {
        // Given
        let transaction = TransactionDTO(
            date: Date(),
            subTotal: 100.50,
            tax: 10.05,
            merchant: "Test Store",
            bucket: .needs
        )

        // When/Then - Should not throw
        XCTAssertNoThrow(try ValidationRules.validateTransaction(transaction))
    }

    func testValidateTransactionFailsWithZeroAmount() {
        // Given
        let transaction = TransactionDTO(
            subTotal: 0,
            merchant: "Test Store",
            bucket: .needs
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateTransaction(transaction)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .transactionAmountInvalid(let message) = validationError {
                XCTAssertTrue(message.contains("greater than 0"))
            } else {
                XCTFail("Wrong validation error: \(validationError)")
            }
        }
    }

    func testValidateTransactionFailsWithNegativeAmount() {
        // Given
        let transaction = TransactionDTO(
            subTotal: -50,
            merchant: "Test Store",
            bucket: .needs
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateTransaction(transaction))
    }

    func testValidateTransactionFailsWithNegativeTax() {
        // Given
        let transaction = TransactionDTO(
            subTotal: 100,
            tax: -10,
            merchant: "Test Store",
            bucket: .needs
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateTransaction(transaction)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .transactionAmountInvalid(let message) = validationError {
                XCTAssertTrue(message.contains("Tax cannot be negative"))
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    func testValidateTransactionFailsWithEmptyMerchant() {
        // Given
        let transaction = TransactionDTO(
            subTotal: 100,
            merchant: "   ",
            bucket: .needs
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateTransaction(transaction)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .transactionMerchantRequired = validationError {
                // Success
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    func testValidateTransactionFailsWithFutureDate() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let transaction = TransactionDTO(
            date: futureDate,
            subTotal: 100,
            merchant: "Test Store",
            bucket: .needs
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateTransaction(transaction)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .transactionDateInvalid(let message) = validationError {
                XCTAssertTrue(message.contains("future"))
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    func testValidateTransactionStrictRequiresCategory() {
        // Given
        let transaction = TransactionDTO(
            subTotal: 100,
            merchant: "Test Store",
            bucket: .needs
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateTransactionStrict(transaction)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .requiredFieldMissing(let field) = validationError {
                XCTAssertEqual(field, "category")
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    func testValidateTransactionStrictSuccessWithCategory() throws {
        // Given
        let transaction = TransactionDTO(
            subTotal: 100,
            merchant: "Test Store",
            bucket: .needs,
            categoryId: UUID()
        )

        // When/Then
        XCTAssertNoThrow(try ValidationRules.validateTransactionStrict(transaction))
    }

    // MARK: - Budget Period Validation Tests

    func testValidateBudgetPeriodSuccess() throws {
        // Given
        let income = IncomeSourceDTO(sourceName: "Salary", amount: 5000)
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [income]
        )

        // When/Then
        XCTAssertNoThrow(try ValidationRules.validateBudgetPeriod(period))
    }

    func testValidateBudgetPeriodFailsWhenEndBeforeStart() {
        // Given
        let income = IncomeSourceDTO(sourceName: "Salary", amount: 5000)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)!
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: startDate,
            endDate: endDate,
            incomeSources: [income]
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateBudgetPeriod(period)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .budgetPeriodDateInvalid(let message) = validationError {
                XCTAssertTrue(message.contains("after start"))
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    func testValidateBudgetPeriodFailsWithNoIncome() {
        // Given
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: []
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateBudgetPeriod(period)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .budgetPeriodNoIncome = validationError {
                // Success
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    func testValidateBudgetPeriodFailsWithZeroIncome() {
        // Given
        let income = IncomeSourceDTO(sourceName: "Salary", amount: 0)
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [income]
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateBudgetPeriod(period))
    }

    func testValidateBudgetPeriodFailsWithEmptyIncomeSourceName() {
        // Given
        let income = IncomeSourceDTO(sourceName: "  ", amount: 5000)
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [income]
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateBudgetPeriod(period))
    }

    func testValidateBudgetPeriodNoOverlapSuccess() throws {
        // Given
        let period1 = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [IncomeSourceDTO(sourceName: "Salary", amount: 5000)]
        )
        let period2 = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Calendar.current.date(byAdding: .month, value: 2, to: Date())!,
            endDate: Calendar.current.date(byAdding: .month, value: 3, to: Date())!,
            incomeSources: [IncomeSourceDTO(sourceName: "Salary", amount: 5000)]
        )

        // When/Then
        XCTAssertNoThrow(try ValidationRules.validateBudgetPeriodNoOverlap(period2, against: [period1]))
    }

    func testValidateBudgetPeriodOverlapFails() {
        // Given
        let period1 = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [IncomeSourceDTO(sourceName: "Salary", amount: 5000)]
        )
        let period2 = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Calendar.current.date(byAdding: .day, value: 15, to: Date())!,
            endDate: Calendar.current.date(byAdding: .month, value: 2, to: Date())!,
            incomeSources: [IncomeSourceDTO(sourceName: "Salary", amount: 5000)]
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateBudgetPeriodNoOverlap(period2, against: [period1])) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .budgetPeriodOverlap = validationError {
                // Success
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    // MARK: - Category Allocation Validation Tests

    func testValidateCategoryAllocationSuccess() throws {
        // Given
        let allocation = CategoryAllocationDTO(
            plannedAmount: 1000,
            carryOverAmount: 100,
            budgetPeriodId: UUID(),
            categoryId: UUID()
        )

        // When/Then
        XCTAssertNoThrow(try ValidationRules.validateCategoryAllocation(allocation))
    }

    func testValidateCategoryAllocationFailsWithNegativePlannedAmount() {
        // Given
        let allocation = CategoryAllocationDTO(
            plannedAmount: -100,
            budgetPeriodId: UUID(),
            categoryId: UUID()
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateCategoryAllocation(allocation))
    }

    func testValidateCategoryAllocationFailsWithNegativeCarryOver() {
        // Given
        let allocation = CategoryAllocationDTO(
            plannedAmount: 1000,
            carryOverAmount: -50,
            budgetPeriodId: UUID(),
            categoryId: UUID()
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateCategoryAllocation(allocation))
    }

    func testValidateCategoryAllocationFailsWithoutCategory() {
        // Given
        let allocation = CategoryAllocationDTO(
            plannedAmount: 1000,
            budgetPeriodId: UUID()
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateCategoryAllocation(allocation)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .allocationCategoryRequired = validationError {
                // Success
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    func testValidateCategoryAllocationFailsWithoutBudgetPeriod() {
        // Given
        let allocation = CategoryAllocationDTO(
            plannedAmount: 1000,
            categoryId: UUID()
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateCategoryAllocation(allocation)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .allocationBudgetPeriodRequired = validationError {
                // Success
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    // MARK: - User Settings Validation Tests

    func testValidatePercentagesSuccess() throws {
        // Given
        let settings = UserSettingsDTO(
            needsPercentage: 50,
            wantsPercentage: 30,
            savingsPercentage: 20
        )

        // When/Then
        XCTAssertNoThrow(try ValidationRules.validatePercentages(settings))
    }

    func testValidatePercentagesFailsWhenSumNot100() {
        // Given
        let settings = UserSettingsDTO(
            needsPercentage: 50,
            wantsPercentage: 30,
            savingsPercentage: 25 // Sum = 105
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validatePercentages(settings)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .percentageSumInvalid(let sum) = validationError {
                XCTAssertEqual(sum, 105)
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    func testValidatePercentagesFailsWithNegativeNeeds() {
        // Given
        let settings = UserSettingsDTO(
            needsPercentage: -10,
            wantsPercentage: 60,
            savingsPercentage: 50
        )

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validatePercentages(settings)) { error in
            guard let validationError = error as? ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .percentageNegative(let field) = validationError {
                XCTAssertEqual(field, "needs")
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }

    func testValidatePercentagesAllowsCustomDistribution() throws {
        // Given - 70/20/10 distribution
        let settings = UserSettingsDTO(
            needsPercentage: 70,
            wantsPercentage: 20,
            savingsPercentage: 10
        )

        // When/Then
        XCTAssertNoThrow(try ValidationRules.validatePercentages(settings))
    }

    // MARK: - Income Source Validation Tests

    func testValidateIncomeSourceSuccess() throws {
        // Given
        let income = IncomeSourceDTO(sourceName: "Salary", amount: 5000)

        // When/Then
        XCTAssertNoThrow(try ValidationRules.validateIncomeSource(income))
    }

    func testValidateIncomeSourceFailsWithZeroAmount() {
        // Given
        let income = IncomeSourceDTO(sourceName: "Salary", amount: 0)

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateIncomeSource(income))
    }

    func testValidateIncomeSourceFailsWithEmptyName() {
        // Given
        let income = IncomeSourceDTO(sourceName: "  ", amount: 5000)

        // When/Then
        XCTAssertThrowsError(try ValidationRules.validateIncomeSource(income))
    }

    // MARK: - General Helper Tests

    func testValidateDecimalRange() throws {
        // Success cases
        XCTAssertNoThrow(try ValidationRules.validateDecimalRange(50, min: 0, max: 100, fieldName: "test"))
        XCTAssertNoThrow(try ValidationRules.validateDecimalRange(0, min: 0, max: 100, fieldName: "test"))
        XCTAssertNoThrow(try ValidationRules.validateDecimalRange(100, min: 0, max: 100, fieldName: "test"))

        // Failure cases
        XCTAssertThrowsError(try ValidationRules.validateDecimalRange(-1, min: 0, max: 100, fieldName: "test"))
        XCTAssertThrowsError(try ValidationRules.validateDecimalRange(101, min: 0, max: 100, fieldName: "test"))
    }

    func testValidateDateRange() throws {
        // Success case
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        XCTAssertNoThrow(try ValidationRules.validateDateRange(startDate: start, endDate: end))

        // Failure case
        XCTAssertThrowsError(try ValidationRules.validateDateRange(startDate: end, endDate: start))
    }

    func testValidateNotEmpty() throws {
        // Success cases
        XCTAssertNoThrow(try ValidationRules.validateNotEmpty("test", fieldName: "field"))
        XCTAssertNoThrow(try ValidationRules.validateNotEmpty("  test  ", fieldName: "field"))

        // Failure cases
        XCTAssertThrowsError(try ValidationRules.validateNotEmpty("", fieldName: "field"))
        XCTAssertThrowsError(try ValidationRules.validateNotEmpty("   ", fieldName: "field"))
    }
}
