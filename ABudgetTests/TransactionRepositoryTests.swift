//
//  TransactionRepositoryTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
import CoreData
@testable import ABudget

@MainActor
final class TransactionRepositoryTests: XCTestCase {
    var repository: CoreDataTransactionRepository!
    var budgetRepository: CoreDataBudgetPeriodRepository!
    var categoryRepository: CoreDataCategoryRepository!
    var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory Core Data stack for testing
        context = createInMemoryContext()
        repository = CoreDataTransactionRepository(context: context)
        budgetRepository = CoreDataBudgetPeriodRepository(context: context)
        categoryRepository = CoreDataCategoryRepository(context: context)
    }

    override func tearDown() async throws {
        repository = nil
        budgetRepository = nil
        categoryRepository = nil
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

    private func createTestTransaction(
        date: Date = Date(),
        subTotal: Decimal = 100.00,
        tax: Decimal? = 10.00,
        merchant: String = "Test Merchant",
        bucket: BucketType = .needs,
        description: String? = nil,
        categoryId: UUID? = nil,
        budgetPeriodId: UUID? = nil
    ) -> TransactionDTO {
        TransactionDTO(
            date: date,
            subTotal: subTotal,
            tax: tax,
            merchant: merchant,
            bucket: bucket,
            transactionDescription: description,
            categoryId: categoryId,
            budgetPeriodId: budgetPeriodId
        )
    }

    private func createTestCategory(name: String = "Test Category") async throws -> CategoryDTO {
        let category = CategoryDTO(name: name)
        return try await categoryRepository.create(category)
    }

    private func createTestBudgetPeriod(
        startDate: Date = Date(),
        endDate: Date? = nil
    ) async throws -> BudgetPeriodDTO {
        let end = endDate ?? Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: startDate,
            endDate: end
        )
        return try await budgetRepository.create(period)
    }

    // MARK: - Create Tests

    func testCreateTransaction() async throws {
        // Given
        let transaction = createTestTransaction(
            subTotal: 50.00,
            tax: 5.00,
            merchant: "Grocery Store"
        )

        // When
        let created = try await repository.create(transaction)

        // Then
        XCTAssertEqual(created.subTotal, 50.00)
        XCTAssertEqual(created.tax, 5.00)
        XCTAssertEqual(created.total, 55.00)
        XCTAssertEqual(created.merchant, "Grocery Store")
        XCTAssertEqual(created.bucket, .needs)
    }

    func testCreateTransactionWithoutTax() async throws {
        // Given
        let transaction = createTestTransaction(subTotal: 100.00, tax: nil)

        // When
        let created = try await repository.create(transaction)

        // Then
        XCTAssertEqual(created.total, 100.00)
        XCTAssertNil(created.tax)
    }

    func testCreateTransactionAutoAssignsBudgetPeriod() async throws {
        // Given
        let now = Date()
        let period = try await createTestBudgetPeriod(startDate: now)
        let transaction = createTestTransaction(date: now)

        // When
        let created = try await repository.create(transaction)

        // Then
        XCTAssertNotNil(created.budgetPeriodId)
        XCTAssertEqual(created.budgetPeriodId, period.id)
    }

    func testCreateTransactionWithCategory() async throws {
        // Given
        let category = try await createTestCategory(name: "Groceries")
        let transaction = createTestTransaction(categoryId: category.id)

        // When
        let created = try await repository.create(transaction)

        // Then
        XCTAssertEqual(created.categoryId, category.id)
    }

    // MARK: - Fetch Tests

    func testFetchAll() async throws {
        // Given
        _ = try await repository.create(createTestTransaction(merchant: "Store A"))
        _ = try await repository.create(createTestTransaction(merchant: "Store B"))

        // When
        let transactions = try await repository.fetchAll()

        // Then
        XCTAssertEqual(transactions.count, 2)
    }

    func testFetchAllSortedByDateDescending() async throws {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

        _ = try await repository.create(createTestTransaction(date: twoDaysAgo))
        _ = try await repository.create(createTestTransaction(date: today))
        _ = try await repository.create(createTestTransaction(date: yesterday))

        // When
        let transactions = try await repository.fetchAll()

        // Then
        XCTAssertEqual(transactions.count, 3)
        XCTAssertTrue(transactions[0].date > transactions[1].date)
        XCTAssertTrue(transactions[1].date > transactions[2].date)
    }

    func testFetchById() async throws {
        // Given
        let transaction = createTestTransaction()
        let created = try await repository.create(transaction)

        // When
        let fetched = try await repository.fetchById(created.id)

        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, created.id)
        XCTAssertEqual(fetched?.merchant, created.merchant)
    }

    func testFetchByIdNotFound() async throws {
        // When
        let fetched = try await repository.fetchById(UUID())

        // Then
        XCTAssertNil(fetched)
    }

    func testFetchTransactionsInDateRange() async throws {
        // Given
        let today = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: today)!

        _ = try await repository.create(createTestTransaction(date: twoWeeksAgo))
        _ = try await repository.create(createTestTransaction(date: weekAgo))
        _ = try await repository.create(createTestTransaction(date: today))

        // When - Fetch last week
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: today)!
        let transactions = try await repository.fetchTransactions(from: startDate, to: today)

        // Then
        XCTAssertEqual(transactions.count, 2) // Should not include the two-week-old transaction
    }

    func testFetchTransactionsByCategory() async throws {
        // Given
        let groceries = try await createTestCategory(name: "Groceries")
        let dining = try await createTestCategory(name: "Dining")

        _ = try await repository.create(createTestTransaction(merchant: "Grocery Store", categoryId: groceries.id))
        _ = try await repository.create(createTestTransaction(merchant: "Restaurant", categoryId: dining.id))
        _ = try await repository.create(createTestTransaction(merchant: "Supermarket", categoryId: groceries.id))

        // When
        let groceryTransactions = try await repository.fetchTransactions(forCategoryId: groceries.id)

        // Then
        XCTAssertEqual(groceryTransactions.count, 2)
    }

    func testFetchTransactionsByBudgetPeriod() async throws {
        // Given
        let period1 = try await createTestBudgetPeriod()
        let period2Start = Calendar.current.date(byAdding: .month, value: 2, to: Date())!
        let period2 = try await createTestBudgetPeriod(startDate: period2Start)

        _ = try await repository.create(createTestTransaction(budgetPeriodId: period1.id))
        _ = try await repository.create(createTestTransaction(budgetPeriodId: period1.id))
        _ = try await repository.create(createTestTransaction(budgetPeriodId: period2.id))

        // When
        let period1Transactions = try await repository.fetchTransactions(forBudgetPeriodId: period1.id)

        // Then
        XCTAssertEqual(period1Transactions.count, 2)
    }

    func testFetchTransactionsByBucket() async throws {
        // Given
        _ = try await repository.create(createTestTransaction(bucket: .needs))
        _ = try await repository.create(createTestTransaction(bucket: .wants))
        _ = try await repository.create(createTestTransaction(bucket: .needs))
        _ = try await repository.create(createTestTransaction(bucket: .savings))

        // When
        let needsTransactions = try await repository.fetchTransactions(forBucket: .needs)
        let wantsTransactions = try await repository.fetchTransactions(forBucket: .wants)

        // Then
        XCTAssertEqual(needsTransactions.count, 2)
        XCTAssertEqual(wantsTransactions.count, 1)
    }

    func testFetchTransactionsByMerchant() async throws {
        // Given
        _ = try await repository.create(createTestTransaction(merchant: "Amazon"))
        _ = try await repository.create(createTestTransaction(merchant: "Amazon"))
        _ = try await repository.create(createTestTransaction(merchant: "Target"))

        // When
        let amazonTransactions = try await repository.fetchTransactions(forMerchant: "Amazon")

        // Then
        XCTAssertEqual(amazonTransactions.count, 2)
    }

    // MARK: - Update Tests

    func testUpdateTransaction() async throws {
        // Given
        let transaction = createTestTransaction(merchant: "Old Merchant")
        let created = try await repository.create(transaction)

        // When
        var updated = created
        updated.merchant = "New Merchant"
        updated.subTotal = 200.00
        let result = try await repository.update(updated)

        // Then
        XCTAssertEqual(result.merchant, "New Merchant")
        XCTAssertEqual(result.subTotal, 200.00)
        XCTAssertEqual(result.id, created.id)

        // Verify in database
        let fetched = try await repository.fetchById(created.id)
        XCTAssertEqual(fetched?.merchant, "New Merchant")
    }

    func testUpdateTransactionCategory() async throws {
        // Given
        let category1 = try await createTestCategory(name: "Category 1")
        let category2 = try await createTestCategory(name: "Category 2")
        let transaction = createTestTransaction(categoryId: category1.id)
        let created = try await repository.create(transaction)

        // When
        var updated = created
        updated.categoryId = category2.id
        let result = try await repository.update(updated)

        // Then
        XCTAssertEqual(result.categoryId, category2.id)
    }

    func testUpdateNonexistentTransaction() async throws {
        // Given
        let transaction = createTestTransaction()

        // When/Then
        do {
            _ = try await repository.update(transaction)
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

    func testDeleteTransaction() async throws {
        // Given
        let transaction = createTestTransaction()
        let created = try await repository.create(transaction)

        // When
        try await repository.delete(created.id)

        // Then
        let fetched = try await repository.fetchById(created.id)
        XCTAssertNil(fetched)
    }

    func testDeleteNonexistentTransaction() async throws {
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

    func testDeleteMultipleTransactions() async throws {
        // Given
        let t1 = try await repository.create(createTestTransaction())
        let t2 = try await repository.create(createTestTransaction())
        let t3 = try await repository.create(createTestTransaction())

        // When
        try await repository.deleteMultiple([t1.id, t2.id])

        // Then
        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, t3.id)
    }

    // MARK: - Decimal Handling Tests

    func testDecimalPrecision() async throws {
        // Given
        let transaction = createTestTransaction(
            subTotal: Decimal(string: "123.456")!,
            tax: Decimal(string: "12.345")!
        )

        // When
        let created = try await repository.create(transaction)

        // Then
        XCTAssertEqual(created.subTotal, Decimal(string: "123.456")!)
        XCTAssertEqual(created.tax, Decimal(string: "12.345")!)
        XCTAssertEqual(created.total, Decimal(string: "135.801")!)
    }

    func testLargeDecimalAmounts() async throws {
        // Given
        let transaction = createTestTransaction(
            subTotal: Decimal(string: "999999.99")!,
            tax: Decimal(string: "100000.01")!
        )

        // When
        let created = try await repository.create(transaction)

        // Then
        XCTAssertEqual(created.subTotal, Decimal(string: "999999.99")!)
        XCTAssertEqual(created.tax, Decimal(string: "100000.01")!)
        XCTAssertEqual(created.total, Decimal(string: "1100000.00")!)
    }

    // MARK: - Computed Properties Tests

    func testTransactionTotal() {
        // Given
        let transaction = createTestTransaction(subTotal: 100, tax: 8.5)

        // Then
        XCTAssertEqual(transaction.total, 108.5)
    }

    func testTransactionTotalWithoutTax() {
        // Given
        let transaction = createTestTransaction(subTotal: 100, tax: nil)

        // Then
        XCTAssertEqual(transaction.total, 100)
    }

    // MARK: - Array Extension Tests

    func testTransactionArrayTotalAmount() async throws {
        // Given
        _ = try await repository.create(createTestTransaction(subTotal: 50, tax: 5))
        _ = try await repository.create(createTestTransaction(subTotal: 100, tax: 10))
        _ = try await repository.create(createTestTransaction(subTotal: 75, tax: nil))

        // When
        let transactions = try await repository.fetchAll()
        let total = transactions.totalAmount

        // Then
        XCTAssertEqual(total, 240) // 55 + 110 + 75
    }

    func testTransactionArrayGroupedByBucket() async throws {
        // Given
        _ = try await repository.create(createTestTransaction(bucket: .needs))
        _ = try await repository.create(createTestTransaction(bucket: .wants))
        _ = try await repository.create(createTestTransaction(bucket: .needs))

        // When
        let transactions = try await repository.fetchAll()
        let grouped = transactions.groupedByBucket()

        // Then
        XCTAssertEqual(grouped[.needs]?.count, 2)
        XCTAssertEqual(grouped[.wants]?.count, 1)
        XCTAssertNil(grouped[.savings])
    }

    func testTransactionArrayFilteredByDateRange() async throws {
        // Given
        let today = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: today)!

        _ = try await repository.create(createTestTransaction(date: twoWeeksAgo))
        _ = try await repository.create(createTestTransaction(date: weekAgo))
        _ = try await repository.create(createTestTransaction(date: today))

        // When
        let transactions = try await repository.fetchAll()
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: today)!
        let filtered = transactions.filtered(by: startDate...today)

        // Then
        XCTAssertEqual(filtered.count, 2)
    }
}
