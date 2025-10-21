//
//  BudgetPeriodRepositoryTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
import CoreData
@testable import ABudget

@MainActor
final class BudgetPeriodRepositoryTests: XCTestCase {
    var repository: CoreDataBudgetPeriodRepository!
    var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory Core Data stack for testing
        context = createInMemoryContext()
        repository = CoreDataBudgetPeriodRepository(context: context)
    }

    override func tearDown() async throws {
        repository = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func createInMemoryContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "ABudget")

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { description, error in
            XCTAssertNil(error, "Failed to load in-memory store: \(error?.localizedDescription ?? "unknown error")")
        }

        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return context
    }

    private func createTestPeriod(
        methodology: BudgetMethodology = .zeroBased,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
        incomeSources: [IncomeSourceDTO] = []
    ) -> BudgetPeriodDTO {
        BudgetPeriodDTO(
            methodology: methodology,
            startDate: startDate,
            endDate: endDate,
            incomeSources: incomeSources
        )
    }

    private func createTestIncomeSource(
        sourceName: String = "Test Income",
        amount: Decimal = 5000
    ) -> IncomeSourceDTO {
        IncomeSourceDTO(sourceName: sourceName, amount: amount)
    }

    // MARK: - Create Tests

    func testCreateBudgetPeriod() async throws {
        // Given
        let period = createTestPeriod(methodology: .envelope)

        // When
        let created = try await repository.create(period)

        // Then
        XCTAssertEqual(created.methodology, .envelope)
        XCTAssertEqual(created.startDate.timeIntervalSince1970, period.startDate.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(created.endDate.timeIntervalSince1970, period.endDate.timeIntervalSince1970, accuracy: 1)
    }

    func testCreateBudgetPeriodWithIncomeSources() async throws {
        // Given
        let income1 = createTestIncomeSource(sourceName: "Salary", amount: 5000)
        let income2 = createTestIncomeSource(sourceName: "Freelance", amount: 1500)
        let period = createTestPeriod(incomeSources: [income1, income2])

        // When
        let created = try await repository.create(period)

        // Then
        XCTAssertEqual(created.incomeSources.count, 2)
        XCTAssertEqual(created.totalIncome, 6500)
        XCTAssertTrue(created.incomeSources.contains { $0.sourceName == "Salary" })
        XCTAssertTrue(created.incomeSources.contains { $0.sourceName == "Freelance" })
    }

    // MARK: - Fetch Tests

    func testFetchAll() async throws {
        // Given
        let period1 = createTestPeriod(methodology: .zeroBased)
        let period2 = createTestPeriod(methodology: .percentage)

        _ = try await repository.create(period1)
        _ = try await repository.create(period2)

        // When
        let periods = try await repository.fetchAll()

        // Then
        XCTAssertEqual(periods.count, 2)
    }

    func testFetchById() async throws {
        // Given
        let period = createTestPeriod()
        let created = try await repository.create(period)

        // When
        let fetched = try await repository.fetchById(created.id)

        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, created.id)
        XCTAssertEqual(fetched?.methodology, created.methodology)
    }

    func testFetchByIdNotFound() async throws {
        // When
        let fetched = try await repository.fetchById(UUID())

        // Then
        XCTAssertNil(fetched)
    }

    func testFetchActivePeriod() async throws {
        // Given
        let now = Date()
        let pastPeriod = createTestPeriod(
            startDate: Calendar.current.date(byAdding: .month, value: -2, to: now)!,
            endDate: Calendar.current.date(byAdding: .month, value: -1, to: now)!
        )
        let activePeriod = createTestPeriod(
            startDate: Calendar.current.date(byAdding: .day, value: -15, to: now)!,
            endDate: Calendar.current.date(byAdding: .day, value: 15, to: now)!
        )

        _ = try await repository.create(pastPeriod)
        let created = try await repository.create(activePeriod)

        // When
        let fetched = try await repository.fetchActivePeriod()

        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, created.id)
        XCTAssertTrue(fetched?.isActive ?? false)
    }

    func testFetchActivePeriodWhenNone() async throws {
        // When
        let fetched = try await repository.fetchActivePeriod()

        // Then
        XCTAssertNil(fetched)
    }

    func testFetchPeriodsInDateRange() async throws {
        // Given
        let now = Date()
        let period1Start = Calendar.current.date(byAdding: .month, value: -2, to: now)!
        let period1End = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        let period2Start = Calendar.current.date(byAdding: .day, value: -15, to: now)!
        let period2End = Calendar.current.date(byAdding: .day, value: 15, to: now)!

        let period1 = createTestPeriod(startDate: period1Start, endDate: period1End)
        let period2 = createTestPeriod(startDate: period2Start, endDate: period2End)

        _ = try await repository.create(period1)
        _ = try await repository.create(period2)

        // When - Fetch periods overlapping with the last month
        let searchStart = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        let searchEnd = now
        let fetched = try await repository.fetchPeriods(from: searchStart, to: searchEnd)

        // Then - Should find period2 (active period) and possibly period1 if it overlaps
        XCTAssertGreaterThanOrEqual(fetched.count, 1)
        XCTAssertTrue(fetched.contains { $0.startDate == period2Start })
    }

    // MARK: - Update Tests

    func testUpdateBudgetPeriod() async throws {
        // Given
        let period = createTestPeriod(methodology: .zeroBased)
        let created = try await repository.create(period)

        // When
        var updated = created
        updated.methodology = .percentage
        let result = try await repository.update(updated)

        // Then
        XCTAssertEqual(result.methodology, .percentage)
        XCTAssertEqual(result.id, created.id)

        // Verify in database
        let fetched = try await repository.fetchById(created.id)
        XCTAssertEqual(fetched?.methodology, .percentage)
    }

    func testUpdateNonexistentPeriod() async throws {
        // Given
        let period = createTestPeriod()

        // When/Then
        do {
            _ = try await repository.update(period)
            XCTFail("Should throw entityNotFound error")
        } catch let error as AppError {
            if case .entityNotFound = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Delete Tests

    func testDeleteBudgetPeriod() async throws {
        // Given
        let period = createTestPeriod()
        let created = try await repository.create(period)

        // When
        try await repository.delete(created.id)

        // Then
        let fetched = try await repository.fetchById(created.id)
        XCTAssertNil(fetched)
    }

    func testDeleteNonexistentPeriod() async throws {
        // When/Then
        do {
            try await repository.delete(UUID())
            XCTFail("Should throw entityNotFound error")
        } catch let error as AppError {
            if case .entityNotFound = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testDeletePeriodCascadesIncomeSources() async throws {
        // Given
        let income1 = createTestIncomeSource(sourceName: "Salary", amount: 5000)
        let income2 = createTestIncomeSource(sourceName: "Freelance", amount: 1500)
        let period = createTestPeriod(incomeSources: [income1, income2])
        let created = try await repository.create(period)

        // When
        try await repository.delete(created.id)

        // Then - Income sources should be deleted (cascade)
        let fetchRequest: NSFetchRequest<IncomeSource> = IncomeSource.fetchRequest()
        let remainingIncome = try context.fetch(fetchRequest)
        XCTAssertEqual(remainingIncome.count, 0)
    }

    // MARK: - Income Source Tests

    func testAddIncomeSource() async throws {
        // Given
        let period = createTestPeriod()
        let created = try await repository.create(period)
        let income = createTestIncomeSource(sourceName: "Bonus", amount: 2000)

        // When
        let addedIncome = try await repository.addIncomeSource(income, to: created.id)

        // Then
        XCTAssertEqual(addedIncome.sourceName, "Bonus")
        XCTAssertEqual(addedIncome.amount, 2000)
        XCTAssertEqual(addedIncome.budgetPeriodId, created.id)

        // Verify period has the income source
        let fetched = try await repository.fetchById(created.id)
        XCTAssertEqual(fetched?.incomeSources.count, 1)
    }

    func testAddIncomeSourceToNonexistentPeriod() async throws {
        // Given
        let income = createTestIncomeSource()

        // When/Then
        do {
            _ = try await repository.addIncomeSource(income, to: UUID())
            XCTFail("Should throw entityNotFound error")
        } catch let error as AppError {
            if case .entityNotFound = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testUpdateIncomeSource() async throws {
        // Given
        let income = createTestIncomeSource(sourceName: "Salary", amount: 5000)
        let period = createTestPeriod(incomeSources: [income])
        let created = try await repository.create(period)

        let createdIncome = created.incomeSources.first!

        // When
        var updated = createdIncome
        updated.amount = 5500
        let result = try await repository.updateIncomeSource(updated)

        // Then
        XCTAssertEqual(result.amount, 5500)
        XCTAssertEqual(result.sourceName, "Salary")

        // Verify in period
        let fetched = try await repository.fetchById(created.id)
        XCTAssertEqual(fetched?.totalIncome, 5500)
    }

    func testDeleteIncomeSource() async throws {
        // Given
        let income = createTestIncomeSource(sourceName: "Salary", amount: 5000)
        let period = createTestPeriod(incomeSources: [income])
        let created = try await repository.create(period)

        let createdIncome = created.incomeSources.first!

        // When
        try await repository.deleteIncomeSource(createdIncome.id)

        // Then
        let fetched = try await repository.fetchById(created.id)
        XCTAssertEqual(fetched?.incomeSources.count, 0)
        XCTAssertEqual(fetched?.totalIncome, 0)
    }

    // MARK: - Computed Properties Tests

    func testBudgetPeriodContainsDate() {
        // Given
        let now = Date()
        let period = createTestPeriod(
            startDate: Calendar.current.date(byAdding: .day, value: -10, to: now)!,
            endDate: Calendar.current.date(byAdding: .day, value: 10, to: now)!
        )

        // Then
        XCTAssertTrue(period.contains(now))
        XCTAssertFalse(period.contains(Calendar.current.date(byAdding: .day, value: -15, to: now)!))
        XCTAssertFalse(period.contains(Calendar.current.date(byAdding: .day, value: 15, to: now)!))
    }

    func testBudgetPeriodDuration() {
        // Given
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 30, to: start)!
        let period = createTestPeriod(startDate: start, endDate: end)

        // Then
        XCTAssertEqual(period.durationInDays, 30)
    }

    func testBudgetPeriodTotalIncome() async throws {
        // Given
        let income1 = createTestIncomeSource(sourceName: "Salary", amount: 5000)
        let income2 = createTestIncomeSource(sourceName: "Freelance", amount: 1500)
        let period = createTestPeriod(incomeSources: [income1, income2])
        let created = try await repository.create(period)

        // Then
        XCTAssertEqual(created.totalIncome, 6500)
    }
}
