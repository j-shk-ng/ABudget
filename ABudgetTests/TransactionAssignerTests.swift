//
//  TransactionAssignerTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
@testable import ABudget

final class TransactionAssignerTests: XCTestCase {
    var assigner: TransactionAssigner!

    override func setUp() {
        super.setUp()
        assigner = TransactionAssigner()
    }

    override func tearDown() {
        assigner = nil
        super.tearDown()
    }

    // MARK: - Transaction Assignment Tests

    func testAssignTransactionToBudgetPeriod() {
        // Given
        let jan1 = TestHelpers.date(year: 2025, month: 1, day: 1)
        let jan31 = TestHelpers.date(year: 2025, month: 1, day: 31)
        let feb1 = TestHelpers.date(year: 2025, month: 2, day: 1)
        let feb28 = TestHelpers.date(year: 2025, month: 2, day: 28)

        let period1 = TestHelpers.createBudgetPeriod(startDate: jan1, endDate: jan31)
        let period2 = TestHelpers.createBudgetPeriod(startDate: feb1, endDate: feb28)

        let transaction = TestHelpers.createTransaction(date: TestHelpers.date(year: 2025, month: 1, day: 15))

        // When
        let assigned = assigner.assignTransactionToBudgetPeriod(
            transaction: transaction,
            periods: [period1, period2]
        )

        // Then
        XCTAssertEqual(assigned?.id, period1.id)
    }

    func testAssignTransactionToCorrectPeriodWhenMultipleExist() {
        // Given
        let periods = TestHelpers.createSequentialPeriods(count: 3)
        let transaction = TestHelpers.createTransaction(
            date: TestHelpers.addMonths(1, to: Date())
        )

        // When
        let assigned = assigner.assignTransactionToBudgetPeriod(
            transaction: transaction,
            periods: periods
        )

        // Then
        XCTAssertNotNil(assigned)
        XCTAssertTrue(assigned!.contains(transaction.date))
    }

    func testAssignTransactionNoPeriodFound() {
        // Given
        let periods = [TestHelpers.createBudgetPeriod(startDate: TestHelpers.addMonths(2, to: Date()))]
        let transaction = TestHelpers.createTransaction(date: Date())

        // When
        let assigned = assigner.assignTransactionToBudgetPeriod(
            transaction: transaction,
            periods: periods
        )

        // Then
        XCTAssertNil(assigned)
    }

    func testAssignMultipleTransactionsToPeriods() {
        // Given
        let period1 = TestHelpers.createBudgetPeriod(startDate: Date())
        let period2 = TestHelpers.createBudgetPeriod(startDate: TestHelpers.addMonths(2, to: Date()))

        let transactions = [
            TestHelpers.createTransaction(date: Date()),
            TestHelpers.createTransaction(date: TestHelpers.addDays(5, to: Date())),
            TestHelpers.createTransaction(date: TestHelpers.addMonths(2, to: Date()))
        ]

        // When
        let assignments = assigner.assignTransactionsToBudgetPeriods(
            transactions: transactions,
            periods: [period1, period2]
        )

        // Then
        XCTAssertEqual(assignments[period1.id]?.count, 2)
        XCTAssertEqual(assignments[period2.id]?.count, 1)
    }

    // MARK: - Orphaned Transaction Tests

    func testFindOrphanedTransactions() {
        // Given
        let period = TestHelpers.createBudgetPeriod(startDate: Date())
        let transactions = [
            TestHelpers.createTransaction(date: Date()), // Will be assigned
            TestHelpers.createTransaction(date: TestHelpers.addMonths(-2, to: Date())), // Orphaned - before period
            TestHelpers.createTransaction(date: TestHelpers.addMonths(3, to: Date())) // Orphaned - after period
        ]

        // When
        let orphaned = assigner.findOrphanedTransactions(
            transactions: transactions,
            periods: [period]
        )

        // Then
        XCTAssertEqual(orphaned.count, 2)
    }

    func testIsOrphaned() {
        // Given
        let period = TestHelpers.createBudgetPeriod(startDate: Date())
        let assignedTx = TestHelpers.createTransaction(date: Date())
        let orphanedTx = TestHelpers.createTransaction(date: TestHelpers.addMonths(5, to: Date()))

        // When/Then
        XCTAssertFalse(assigner.isOrphaned(transaction: assignedTx, periods: [period]))
        XCTAssertTrue(assigner.isOrphaned(transaction: orphanedTx, periods: [period]))
    }

    func testGetAssignmentStatusAssigned() {
        // Given
        let period = TestHelpers.createBudgetPeriod(startDate: Date())
        let transaction = TestHelpers.createTransaction(date: Date())

        // When
        let status = assigner.getAssignmentStatus(transaction: transaction, periods: [period])

        // Then
        if case .assigned(let periodId, _) = status {
            XCTAssertEqual(periodId, period.id)
            XCTAssertTrue(status.isAssigned)
            XCTAssertFalse(status.isOrphaned)
        } else {
            XCTFail("Expected assigned status")
        }
    }

    func testGetAssignmentStatusOrphaned() {
        // Given
        let period = TestHelpers.createBudgetPeriod(startDate: TestHelpers.addMonths(2, to: Date()))
        let transaction = TestHelpers.createTransaction(date: Date())

        // When
        let status = assigner.getAssignmentStatus(transaction: transaction, periods: [period])

        // Then
        if case .orphaned(let reason) = status {
            XCTAssertFalse(reason.isEmpty)
            XCTAssertFalse(status.isAssigned)
            XCTAssertTrue(status.isOrphaned)
        } else {
            XCTFail("Expected orphaned status")
        }
    }

    // MARK: - Reassignment Tests

    func testReassignTransactionsOnPeriodChange() {
        // Given
        let oldPeriod = TestHelpers.createBudgetPeriod(startDate: Date())
        let newPeriod = TestHelpers.createBudgetPeriod(startDate: TestHelpers.addMonths(2, to: Date()))

        let transactions = [
            TestHelpers.createTransaction(date: Date()),
            TestHelpers.createTransaction(date: TestHelpers.addDays(5, to: Date())),
            TestHelpers.createTransaction(date: TestHelpers.addMonths(2, to: Date())),
            TestHelpers.createTransaction(date: TestHelpers.addMonths(-2, to: Date())) // Orphaned
        ]

        // When
        let result = assigner.reassignTransactionsOnPeriodChange(
            transactions: transactions,
            updatedPeriods: [oldPeriod, newPeriod]
        )

        // Then
        XCTAssertEqual(result.totalProcessed, 4)
        XCTAssertEqual(result.assignedCount, 3)
        XCTAssertEqual(result.orphanedCount, 1)
        XCTAssertEqual(result.successRate, 75)
    }

    func testReassignmentResultComputedProperties() {
        // Given
        let period1Id = UUID()
        let result = ReassignmentResult(
            assignedTransactions: [
                period1Id: [
                    TestHelpers.createTransaction(),
                    TestHelpers.createTransaction()
                ]
            ],
            orphanedTransactions: [TestHelpers.createTransaction()],
            totalProcessed: 3
        )

        // Then
        XCTAssertEqual(result.assignedCount, 2)
        XCTAssertEqual(result.orphanedCount, 1)
        XCTAssertEqual(result.successRate, Decimal(2) / 3 * 100)
    }

    // MARK: - Period Suggestion Tests

    func testSuggestPeriodForOrphanedTransaction() {
        // Given
        let jan1 = TestHelpers.date(year: 2025, month: 1, day: 1)
        let jan31 = TestHelpers.date(year: 2025, month: 1, day: 31)
        let apr1 = TestHelpers.date(year: 2025, month: 4, day: 1)
        let apr30 = TestHelpers.date(year: 2025, month: 4, day: 30)

        let period1 = TestHelpers.createBudgetPeriod(startDate: jan1, endDate: jan31)
        let period2 = TestHelpers.createBudgetPeriod(startDate: apr1, endDate: apr30)

        // Transaction in February (gap between periods)
        let transaction = TestHelpers.createTransaction(date: TestHelpers.date(year: 2025, month: 2, day: 15))

        // When
        let suggested = assigner.suggestPeriodForOrphanedTransaction(
            transaction: transaction,
            periods: [period1, period2]
        )

        // Then
        XCTAssertNotNil(suggested)
        XCTAssertEqual(suggested?.id, period1.id) // Closest to Jan period
    }

    func testSuggestPeriodNoPeriods() {
        // Given
        let transaction = TestHelpers.createTransaction()

        // When
        let suggested = assigner.suggestPeriodForOrphanedTransaction(
            transaction: transaction,
            periods: []
        )

        // Then
        XCTAssertNil(suggested)
    }

    // MARK: - Period Overlap Detection Tests

    func testFindOverlappingPeriodsNoOverlap() {
        // Given
        let periods = [
            TestHelpers.createBudgetPeriod(
                startDate: TestHelpers.date(year: 2025, month: 1, day: 1),
                endDate: TestHelpers.date(year: 2025, month: 1, day: 31)
            ),
            TestHelpers.createBudgetPeriod(
                startDate: TestHelpers.date(year: 2025, month: 2, day: 1),
                endDate: TestHelpers.date(year: 2025, month: 2, day: 28)
            )
        ]
        let transaction = TestHelpers.createTransaction(date: TestHelpers.date(year: 2025, month: 1, day: 15))

        // When
        let overlapping = assigner.findOverlappingPeriods(transaction: transaction, periods: periods)

        // Then
        XCTAssertEqual(overlapping.count, 1)
    }

    func testFindOverlappingPeriodsWithOverlap() {
        // Given
        let date = TestHelpers.date(year: 2025, month: 1, day: 15)
        let periods = [
            TestHelpers.createBudgetPeriod(
                startDate: TestHelpers.date(year: 2025, month: 1, day: 1),
                endDate: TestHelpers.date(year: 2025, month: 1, day: 20)
            ),
            TestHelpers.createBudgetPeriod(
                startDate: TestHelpers.date(year: 2025, month: 1, day: 10),
                endDate: TestHelpers.date(year: 2025, month: 1, day: 31)
            )
        ]
        let transaction = TestHelpers.createTransaction(date: date)

        // When
        let overlapping = assigner.findOverlappingPeriods(transaction: transaction, periods: periods)

        // Then
        XCTAssertEqual(overlapping.count, 2) // Both periods contain this date
    }

    func testHasOverlappingPeriods() {
        // Given - Non-overlapping periods
        let nonOverlapping = [
            TestHelpers.createBudgetPeriod(
                startDate: TestHelpers.date(year: 2025, month: 1, day: 1),
                endDate: TestHelpers.date(year: 2025, month: 1, day: 31)
            ),
            TestHelpers.createBudgetPeriod(
                startDate: TestHelpers.date(year: 2025, month: 2, day: 1),
                endDate: TestHelpers.date(year: 2025, month: 2, day: 28)
            )
        ]

        // When/Then
        XCTAssertFalse(assigner.hasOverlappingPeriods(periods: nonOverlapping))

        // Given - Overlapping periods
        let overlapping = [
            TestHelpers.createBudgetPeriod(
                startDate: TestHelpers.date(year: 2025, month: 1, day: 1),
                endDate: TestHelpers.date(year: 2025, month: 1, day: 31)
            ),
            TestHelpers.createBudgetPeriod(
                startDate: TestHelpers.date(year: 2025, month: 1, day: 15),
                endDate: TestHelpers.date(year: 2025, month: 2, day: 15)
            )
        ]

        // When/Then
        XCTAssertTrue(assigner.hasOverlappingPeriods(periods: overlapping))
    }

    // MARK: - Edge Cases

    func testAssignTransactionEmptyPeriods() {
        let transaction = TestHelpers.createTransaction()
        let assigned = assigner.assignTransactionToBudgetPeriod(transaction: transaction, periods: [])
        XCTAssertNil(assigned)
    }

    func testFindOrphanedTransactionsEmptyTransactions() {
        let orphaned = assigner.findOrphanedTransactions(transactions: [], periods: [])
        XCTAssertEqual(orphaned.count, 0)
    }

    func testReassignTransactionsEmptyInput() {
        let result = assigner.reassignTransactionsOnPeriodChange(transactions: [], updatedPeriods: [])
        XCTAssertEqual(result.totalProcessed, 0)
        XCTAssertEqual(result.assignedCount, 0)
        XCTAssertEqual(result.orphanedCount, 0)
    }
}
