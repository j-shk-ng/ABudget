//
//  BudgetPrefillerTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
@testable import ABudget

final class BudgetPrefillerTests: XCTestCase {
    var prefiller: BudgetPrefiller!

    override func setUp() {
        super.setUp()
        prefiller = BudgetPrefiller()
    }

    override func tearDown() {
        prefiller = nil
        super.tearDown()
    }

    // MARK: - Full Period Prefill Tests

    func testPrefillNewBudgetPeriod() {
        // Given
        let previousPeriod = TestHelpers.createBudgetPeriod(
            methodology: .envelope,
            incomeSources: [
                TestHelpers.createIncomeSource(sourceName: "Salary", amount: 5000),
                TestHelpers.createIncomeSource(sourceName: "Freelance", amount: 1500)
            ]
        )

        let category1 = UUID()
        let category2 = UUID()
        let previousAllocations = [
            TestHelpers.createAllocation(plannedAmount: 2000, categoryId: category1),
            TestHelpers.createAllocation(plannedAmount: 1500, categoryId: category2)
        ]

        let previousTransactions = [
            TestHelpers.createTransaction(subTotal: 1500, tax: 0, categoryId: category1),
            TestHelpers.createTransaction(subTotal: 1000, tax: 0, categoryId: category2)
        ]

        let startDate = TestHelpers.addMonths(1, to: Date())
        let endDate = TestHelpers.addMonths(2, to: Date())

        // When
        let draft = prefiller.prefillNewBudgetPeriod(
            from: previousPeriod,
            allocations: previousAllocations,
            transactions: previousTransactions,
            startDate: startDate,
            endDate: endDate
        )

        // Then
        XCTAssertEqual(draft.methodology, .envelope)
        XCTAssertEqual(draft.startDate, startDate)
        XCTAssertEqual(draft.endDate, endDate)
        XCTAssertEqual(draft.incomeSources.count, 2)
        XCTAssertEqual(draft.allocations.count, 2)

        // Check incomes were copied
        XCTAssertEqual(draft.incomeSources[0].sourceName, "Salary")
        XCTAssertEqual(draft.incomeSources[0].amount, 5000)

        // Check allocations have carry-over
        let alloc1 = draft.allocations.first { $0.categoryId == category1 }
        XCTAssertEqual(alloc1?.plannedAmount, 2000)
        XCTAssertEqual(alloc1?.carryOverAmount, 500) // 2000 - 1500 spent
    }

    func testPrefillNewBudgetPeriodWithCustomMethodology() {
        // Given
        let previousPeriod = TestHelpers.createBudgetPeriod(methodology: .envelope)
        let startDate = TestHelpers.addMonths(1, to: Date())
        let endDate = TestHelpers.addMonths(2, to: Date())

        // When
        let draft = prefiller.prefillNewBudgetPeriod(
            from: previousPeriod,
            allocations: [],
            transactions: [],
            startDate: startDate,
            endDate: endDate,
            methodology: .percentage
        )

        // Then
        XCTAssertEqual(draft.methodology, .percentage)
    }

    // MARK: - Income Copying Tests

    func testCopyIncomes() {
        // Given
        let period = TestHelpers.createBudgetPeriod(
            incomeSources: [
                TestHelpers.createIncomeSource(sourceName: "Salary", amount: 5000),
                TestHelpers.createIncomeSource(sourceName: "Bonus", amount: 2000)
            ]
        )

        // When
        let incomeDrafts = prefiller.copyIncomes(from: period)

        // Then
        XCTAssertEqual(incomeDrafts.count, 2)
        XCTAssertEqual(incomeDrafts[0].sourceName, "Salary")
        XCTAssertEqual(incomeDrafts[0].amount, 5000)
        XCTAssertNotNil(incomeDrafts[0].originalId)
    }

    func testCopyIncomesWithAdjustment() {
        // Given
        let period = TestHelpers.createBudgetPeriod(
            incomeSources: [
                TestHelpers.createIncomeSource(sourceName: "Salary", amount: 5000)
            ]
        )

        // When - 10% increase
        let incomeDrafts = prefiller.copyIncomesWithAdjustment(
            from: period,
            adjustmentFactor: 1.1
        )

        // Then
        XCTAssertEqual(incomeDrafts[0].amount, 5500)
    }

    // MARK: - Allocation Copying Tests

    func testCopyAllocationsWithCarryOver() {
        // Given
        let category = UUID()
        let allocations = [
            TestHelpers.createAllocation(plannedAmount: 1000, categoryId: category)
        ]
        let transactions = [
            TestHelpers.createTransaction(subTotal: 600, tax: 0, categoryId: category)
        ]

        // When
        let allocationDrafts = prefiller.copyAllocations(
            from: allocations,
            transactions: transactions
        )

        // Then
        XCTAssertEqual(allocationDrafts.count, 1)
        XCTAssertEqual(allocationDrafts[0].plannedAmount, 1000)
        XCTAssertEqual(allocationDrafts[0].carryOverAmount, 400) // 1000 - 600 spent
        XCTAssertEqual(allocationDrafts[0].categoryId, category)
    }

    func testCopyAllocationsNoCarryOverWhenOverBudget() {
        // Given
        let category = UUID()
        let allocations = [
            TestHelpers.createAllocation(plannedAmount: 500, categoryId: category)
        ]
        let transactions = [
            TestHelpers.createTransaction(subTotal: 600, tax: 0, categoryId: category)
        ]

        // When
        let allocationDrafts = prefiller.copyAllocations(
            from: allocations,
            transactions: transactions
        )

        // Then
        XCTAssertEqual(allocationDrafts[0].carryOverAmount, 0) // No carry over when over budget
    }

    func testCopyAllocationsWithoutCarryOver() {
        // Given
        let category = UUID()
        let allocations = [
            TestHelpers.createAllocation(plannedAmount: 1000, carryOverAmount: 100, categoryId: category)
        ]

        // When
        let allocationDrafts = prefiller.copyAllocationsWithoutCarryOver(from: allocations)

        // Then
        XCTAssertEqual(allocationDrafts[0].carryOverAmount, 0)
        XCTAssertEqual(allocationDrafts[0].plannedAmount, 1000)
    }

    func testCopyAllocationsWithAdjustment() {
        // Given
        let category = UUID()
        let allocations = [
            TestHelpers.createAllocation(plannedAmount: 1000, categoryId: category)
        ]
        let transactions = [
            TestHelpers.createTransaction(subTotal: 600, tax: 0, categoryId: category)
        ]

        // When - 20% increase
        let allocationDrafts = prefiller.copyAllocationsWithAdjustment(
            from: allocations,
            transactions: transactions,
            adjustmentFactor: 1.2,
            includeCarryOver: true
        )

        // Then
        XCTAssertEqual(allocationDrafts[0].plannedAmount, 1200) // 1000 * 1.2
        XCTAssertEqual(allocationDrafts[0].carryOverAmount, 400) // Still 1000 - 600
    }

    func testCopyAllocationsWithAdjustmentNoCarryOver() {
        // Given
        let category = UUID()
        let allocations = [
            TestHelpers.createAllocation(plannedAmount: 1000, categoryId: category)
        ]

        // When
        let allocationDrafts = prefiller.copyAllocationsWithAdjustment(
            from: allocations,
            transactions: [],
            adjustmentFactor: 0.9,
            includeCarryOver: false
        )

        // Then
        XCTAssertEqual(allocationDrafts[0].plannedAmount, 900)
        XCTAssertEqual(allocationDrafts[0].carryOverAmount, 0)
    }

    // MARK: - Selective Copying Tests

    func testCopySelectiveAllocations() {
        // Given
        let category1 = UUID()
        let category2 = UUID()
        let category3 = UUID()

        let allocations = [
            TestHelpers.createAllocation(plannedAmount: 1000, categoryId: category1),
            TestHelpers.createAllocation(plannedAmount: 500, categoryId: category2),
            TestHelpers.createAllocation(plannedAmount: 750, categoryId: category3)
        ]

        let selectedCategories: Set<UUID> = [category1, category3]

        // When
        let allocationDrafts = prefiller.copySelectiveAllocations(
            from: allocations,
            forCategories: selectedCategories,
            transactions: []
        )

        // Then
        XCTAssertEqual(allocationDrafts.count, 2)
        XCTAssertTrue(allocationDrafts.contains { $0.categoryId == category1 })
        XCTAssertTrue(allocationDrafts.contains { $0.categoryId == category3 })
        XCTAssertFalse(allocationDrafts.contains { $0.categoryId == category2 })
    }

    // MARK: - Validation Tests

    func testValidateDraftSuccess() {
        // Given
        let draft = BudgetPeriodDraft(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: TestHelpers.addMonths(1, to: Date()),
            incomeSources: [
                IncomeSourceDraft(sourceName: "Salary", amount: 5000)
            ],
            allocations: [
                CategoryAllocationDraft(categoryId: UUID(), plannedAmount: 1000)
            ]
        )

        // When
        let result = prefiller.validateDraft(draft)

        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.errors.count, 0)
    }

    func testValidateDraftInvalidDateRange() {
        // Given
        let startDate = Date()
        let endDate = TestHelpers.addDays(-1, to: startDate)
        let draft = BudgetPeriodDraft(
            methodology: .zeroBased,
            startDate: startDate,
            endDate: endDate,
            incomeSources: [IncomeSourceDraft(sourceName: "Salary", amount: 5000)],
            allocations: []
        )

        // When
        let result = prefiller.validateDraft(draft)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("after start") })
    }

    func testValidateDraftNoIncomeSources() {
        // Given
        let draft = BudgetPeriodDraft(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: TestHelpers.addMonths(1, to: Date()),
            incomeSources: [],
            allocations: []
        )

        // When
        let result = prefiller.validateDraft(draft)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("income source is required") })
    }

    func testValidateDraftInvalidIncomeAmount() {
        // Given
        let draft = BudgetPeriodDraft(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: TestHelpers.addMonths(1, to: Date()),
            incomeSources: [
                IncomeSourceDraft(sourceName: "Salary", amount: 0)
            ],
            allocations: []
        )

        // When
        let result = prefiller.validateDraft(draft)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("greater than 0") })
    }

    func testValidateDraftNegativeAllocation() {
        // Given
        let draft = BudgetPeriodDraft(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: TestHelpers.addMonths(1, to: Date()),
            incomeSources: [IncomeSourceDraft(sourceName: "Salary", amount: 5000)],
            allocations: [
                CategoryAllocationDraft(categoryId: UUID(), plannedAmount: -100)
            ]
        )

        // When
        let result = prefiller.validateDraft(draft)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("cannot be negative") })
    }

    // MARK: - Summary Calculation Tests

    func testCalculateDraftSummary() {
        // Given
        let draft = BudgetPeriodDraft(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: TestHelpers.addMonths(1, to: Date()),
            incomeSources: [
                IncomeSourceDraft(sourceName: "Salary", amount: 5000),
                IncomeSourceDraft(sourceName: "Bonus", amount: 1000)
            ],
            allocations: [
                CategoryAllocationDraft(categoryId: UUID(), plannedAmount: 2000, carryOverAmount: 100),
                CategoryAllocationDraft(categoryId: UUID(), plannedAmount: 1500, carryOverAmount: 50)
            ]
        )

        // When
        let summary = prefiller.calculateDraftSummary(draft)

        // Then
        XCTAssertEqual(summary.totalIncome, 6000)
        XCTAssertEqual(summary.totalPlanned, 3500)
        XCTAssertEqual(summary.totalCarryOver, 150)
        XCTAssertEqual(summary.totalAvailable, 3650)
        XCTAssertEqual(summary.allocatedPercentage, Decimal(3500) / 6000 * 100)
        XCTAssertEqual(summary.remainingToAllocate, 2500)
        XCTAssertFalse(summary.isFullyAllocated)
        XCTAssertFalse(summary.isOverAllocated)
    }

    func testCalculateDraftSummaryFullyAllocated() {
        // Given
        let draft = BudgetPeriodDraft(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: TestHelpers.addMonths(1, to: Date()),
            incomeSources: [IncomeSourceDraft(sourceName: "Salary", amount: 5000)],
            allocations: [
                CategoryAllocationDraft(categoryId: UUID(), plannedAmount: 3000),
                CategoryAllocationDraft(categoryId: UUID(), plannedAmount: 2000)
            ]
        )

        // When
        let summary = prefiller.calculateDraftSummary(draft)

        // Then
        XCTAssertTrue(summary.isFullyAllocated)
        XCTAssertFalse(summary.isOverAllocated)
        XCTAssertEqual(summary.remainingToAllocate, 0)
    }

    func testCalculateDraftSummaryOverAllocated() {
        // Given
        let draft = BudgetPeriodDraft(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: TestHelpers.addMonths(1, to: Date()),
            incomeSources: [IncomeSourceDraft(sourceName: "Salary", amount: 3000)],
            allocations: [
                CategoryAllocationDraft(categoryId: UUID(), plannedAmount: 2000),
                CategoryAllocationDraft(categoryId: UUID(), plannedAmount: 1500)
            ]
        )

        // When
        let summary = prefiller.calculateDraftSummary(draft)

        // Then
        XCTAssertTrue(summary.isOverAllocated)
        XCTAssertEqual(summary.remainingToAllocate, -500)
    }

    // MARK: - Edge Cases

    func testCopyAllocationsSkipsNilCategoryId() {
        // Given
        let allocations = [
            TestHelpers.createAllocation(plannedAmount: 1000, categoryId: nil)
        ]

        // When
        let drafts = prefiller.copyAllocations(from: allocations, transactions: [])

        // Then
        XCTAssertEqual(drafts.count, 0)
    }

    func testCopyIncomesEmptyPeriod() {
        // Given
        let period = TestHelpers.createBudgetPeriod(incomeSources: [])

        // When
        let drafts = prefiller.copyIncomes(from: period)

        // Then
        XCTAssertEqual(drafts.count, 0)
    }
}
