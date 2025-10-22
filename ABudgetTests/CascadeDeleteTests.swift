//
//  CascadeDeleteTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
import CoreData
@testable import ABudget

@MainActor
final class CascadeDeleteTests: XCTestCase {
    var budgetRepository: CoreDataBudgetPeriodRepository!
    var transactionRepository: CoreDataTransactionRepository!
    var categoryRepository: CoreDataCategoryRepository!
    var allocationRepository: CoreDataCategoryAllocationRepository!
    var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()

        context = createInMemoryContext()
        budgetRepository = CoreDataBudgetPeriodRepository(context: context)
        transactionRepository = CoreDataTransactionRepository(context: context)
        categoryRepository = CoreDataCategoryRepository(context: context)
        allocationRepository = CoreDataCategoryAllocationRepository(context: context)
    }

    override func tearDown() async throws {
        budgetRepository = nil
        transactionRepository = nil
        categoryRepository = nil
        allocationRepository = nil
        context = nil
        try await super.tearDown()
    }

    private func createInMemoryContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "ABudget")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { description, error in
            XCTAssertNil(error)
        }

        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Cascade Delete Tests

    func testDeleteBudgetPeriodCascadesIncomeSourcesAndAllocations() async throws {
        // Given
        let income1 = IncomeSourceDTO(sourceName: "Salary", amount: 5000)
        let income2 = IncomeSourceDTO(sourceName: "Bonus", amount: 1000)
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [income1, income2]
        )
        let createdPeriod = try await budgetRepository.create(period)

        // Create category allocations
        let category = try await categoryRepository.create(CategoryDTO(name: "Test"))
        let allocation = CategoryAllocationDTO(
            plannedAmount: 1000,
            budgetPeriodId: createdPeriod.id,
            categoryId: category.id
        )
        _ = try await allocationRepository.create(allocation)

        // Verify setup
        XCTAssertEqual(createdPeriod.incomeSources.count, 2)
        let allocations = try await allocationRepository.fetchAllocations(forBudgetPeriodId: createdPeriod.id)
        XCTAssertEqual(allocations.count, 1)

        // When - Delete budget period
        try await budgetRepository.delete(createdPeriod.id)

        // Then - Income sources should be deleted (cascade)
        let fetchRequest: NSFetchRequest<IncomeSource> = IncomeSource.fetchRequest()
        let remainingIncome = try context.fetch(fetchRequest)
        XCTAssertEqual(remainingIncome.count, 0, "Income sources should be cascade deleted")

        // Category allocations should be deleted (cascade)
        let remainingAllocations = try await allocationRepository.fetchAllocations(forBudgetPeriodId: createdPeriod.id)
        XCTAssertEqual(remainingAllocations.count, 0, "Allocations should be cascade deleted")
    }

    func testDeleteBudgetPeriodNullifiesTransactions() async throws {
        // Given
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [IncomeSourceDTO(sourceName: "Salary", amount: 5000)]
        )
        let createdPeriod = try await budgetRepository.create(period)

        let transaction = TransactionDTO(
            subTotal: 100,
            merchant: "Store",
            bucket: .needs,
            budgetPeriodId: createdPeriod.id
        )
        let createdTransaction = try await transactionRepository.create(transaction)

        // Verify transaction is linked
        XCTAssertEqual(createdTransaction.budgetPeriodId, createdPeriod.id)

        // When - Delete budget period
        try await budgetRepository.delete(createdPeriod.id)

        // Then - Transaction should still exist but with null budget period (Nullify rule)
        let fetchedTransaction = try await transactionRepository.fetchById(createdTransaction.id)
        XCTAssertNotNil(fetchedTransaction, "Transaction should not be deleted")
        XCTAssertNil(fetchedTransaction?.budgetPeriodId, "Budget period should be nullified")
    }

    func testDeleteCategoryNullifiesTransactionsAndAllocations() async throws {
        // Given
        let category = try await categoryRepository.create(CategoryDTO(name: "Groceries"))

        // Create budget period with allocation
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [IncomeSourceDTO(sourceName: "Salary", amount: 5000)]
        )
        let createdPeriod = try await budgetRepository.create(period)

        let allocation = CategoryAllocationDTO(
            plannedAmount: 500,
            budgetPeriodId: createdPeriod.id,
            categoryId: category.id
        )
        let createdAllocation = try await allocationRepository.create(allocation)

        // Create transaction
        let transaction = TransactionDTO(
            subTotal: 100,
            merchant: "Store",
            bucket: .needs,
            categoryId: category.id
        )
        let createdTransaction = try await transactionRepository.create(transaction)

        // When - Delete category
        try await categoryRepository.delete(category.id)

        // Then - Transaction should still exist with null category
        let fetchedTransaction = try await transactionRepository.fetchById(createdTransaction.id)
        XCTAssertNotNil(fetchedTransaction)
        XCTAssertNil(fetchedTransaction?.categoryId)

        // Allocation should still exist with null category
        let fetchedAllocation = try await allocationRepository.fetchById(createdAllocation.id)
        XCTAssertNotNil(fetchedAllocation)
        XCTAssertNil(fetchedAllocation?.categoryId)
    }

    func testDeleteParentCategoryCascadesChildrenAndNullifiesRelationships() async throws {
        // Given
        let parent = try await categoryRepository.create(CategoryDTO(name: "Shopping"))
        let child1 = try await categoryRepository.create(CategoryDTO(name: "Clothing", parentId: parent.id))
        let child2 = try await categoryRepository.create(CategoryDTO(name: "Electronics", parentId: parent.id))

        // Create transaction linked to child
        let transaction = TransactionDTO(
            subTotal: 50,
            merchant: "Store",
            bucket: .wants,
            categoryId: child1.id
        )
        let createdTransaction = try await transactionRepository.create(transaction)

        // Verify setup
        let children = try await categoryRepository.fetchSubcategories(parentId: parent.id)
        XCTAssertEqual(children.count, 2)

        // When - Delete parent
        try await categoryRepository.delete(parent.id)

        // Then - Children should be deleted (cascade)
        let allCategories = try await categoryRepository.fetchAll()
        XCTAssertEqual(allCategories.count, 0, "Parent and children should be deleted")

        // Transaction should exist with null category
        let fetchedTransaction = try await transactionRepository.fetchById(createdTransaction.id)
        XCTAssertNotNil(fetchedTransaction)
        XCTAssertNil(fetchedTransaction?.categoryId)
    }

    // MARK: - Orphaned Data Tests

    func testOrphanedTransactionWithoutCategory() async throws {
        // Given - Create transaction without category
        let transaction = TransactionDTO(
            subTotal: 100,
            merchant: "Unknown Store",
            bucket: .needs
        )

        // When
        let created = try await transactionRepository.create(transaction)

        // Then - Transaction should be created without category
        XCTAssertNil(created.categoryId)
        XCTAssertNil(created.subCategoryId)

        // Should be able to fetch it
        let fetched = try await transactionRepository.fetchById(created.id)
        XCTAssertNotNil(fetched)
    }

    func testOrphanedTransactionWithoutBudgetPeriod() async throws {
        // Given - Create transaction with date but no active budget period
        let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let transaction = TransactionDTO(
            date: futureDate,
            subTotal: 100,
            merchant: "Future Store",
            bucket: .needs
        )

        // When
        let created = try await transactionRepository.create(transaction)

        // Then - Transaction should be created without budget period
        XCTAssertNil(created.budgetPeriodId)

        // Should be able to fetch it
        let fetched = try await transactionRepository.fetchById(created.id)
        XCTAssertNotNil(fetched)
    }

    func testFindOrphanedTransactions() async throws {
        // Given - Create mix of categorized and uncategorized transactions
        let category = try await categoryRepository.create(CategoryDTO(name: "Food"))

        let categorized = TransactionDTO(
            subTotal: 50,
            merchant: "Store A",
            bucket: .needs,
            categoryId: category.id
        )
        let orphaned1 = TransactionDTO(
            subTotal: 100,
            merchant: "Store B",
            bucket: .needs
        )
        let orphaned2 = TransactionDTO(
            subTotal: 75,
            merchant: "Store C",
            bucket: .wants
        )

        _ = try await transactionRepository.create(categorized)
        _ = try await transactionRepository.create(orphaned1)
        _ = try await transactionRepository.create(orphaned2)

        // When - Fetch all transactions
        let allTransactions = try await transactionRepository.fetchAll()

        // Then - Filter orphaned transactions (no category)
        let orphanedTransactions = allTransactions.filter { $0.categoryId == nil }
        XCTAssertEqual(orphanedTransactions.count, 2)
        XCTAssertEqual(orphanedTransactions.totalAmount, 175)
    }

    func testBudgetPeriodWithNoTransactions() async throws {
        // Given - Create budget period with no transactions
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [IncomeSourceDTO(sourceName: "Salary", amount: 5000)]
        )
        let created = try await budgetRepository.create(period)

        // When - Fetch transactions for this period
        let transactions = try await transactionRepository.fetchTransactions(forBudgetPeriodId: created.id)

        // Then - Should return empty array
        XCTAssertEqual(transactions.count, 0)
    }

    func testComplexCascadeScenario() async throws {
        // Given - Complex setup with multiple relationships
        let parent = try await categoryRepository.create(CategoryDTO(name: "Parent"))
        let child = try await categoryRepository.create(CategoryDTO(name: "Child", parentId: parent.id))

        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [
                IncomeSourceDTO(sourceName: "Income 1", amount: 3000),
                IncomeSourceDTO(sourceName: "Income 2", amount: 2000)
            ]
        )
        let createdPeriod = try await budgetRepository.create(period)

        // Create allocations for both parent and child
        _ = try await allocationRepository.create(CategoryAllocationDTO(
            plannedAmount: 1000,
            budgetPeriodId: createdPeriod.id,
            categoryId: parent.id
        ))
        _ = try await allocationRepository.create(CategoryAllocationDTO(
            plannedAmount: 500,
            budgetPeriodId: createdPeriod.id,
            categoryId: child.id
        ))

        // Create transactions
        _ = try await transactionRepository.create(TransactionDTO(
            subTotal: 100,
            merchant: "Store 1",
            bucket: .needs,
            categoryId: parent.id,
            budgetPeriodId: createdPeriod.id
        ))
        _ = try await transactionRepository.create(TransactionDTO(
            subTotal: 50,
            merchant: "Store 2",
            bucket: .needs,
            categoryId: child.id,
            subCategoryId: child.id,
            budgetPeriodId: createdPeriod.id
        ))

        // When - Delete budget period
        try await budgetRepository.delete(createdPeriod.id)

        // Then - Verify cascade behavior
        let incomeFetch: NSFetchRequest<IncomeSource> = IncomeSource.fetchRequest()
        XCTAssertEqual(try context.fetch(incomeFetch).count, 0)

        let allocations = try await allocationRepository.fetchAll()
        XCTAssertEqual(allocations.count, 0)

        let transactions = try await transactionRepository.fetchAll()
        XCTAssertEqual(transactions.count, 2) // Transactions still exist
        XCTAssertTrue(transactions.allSatisfy { $0.budgetPeriodId == nil }) // But nullified
    }

    func testCategoryDeletionWithMultipleRelationships() async throws {
        // Given
        let category = try await categoryRepository.create(CategoryDTO(name: "Test Category"))

        // Create budget period
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [IncomeSourceDTO(sourceName: "Salary", amount: 5000)]
        )
        let createdPeriod = try await budgetRepository.create(period)

        // Create multiple allocations across different periods
        _ = try await allocationRepository.create(CategoryAllocationDTO(
            plannedAmount: 500,
            budgetPeriodId: createdPeriod.id,
            categoryId: category.id
        ))

        // Create multiple transactions
        for i in 1...3 {
            _ = try await transactionRepository.create(TransactionDTO(
                subTotal: Decimal(i * 50),
                merchant: "Store \(i)",
                bucket: .needs,
                categoryId: category.id
            ))
        }

        // When - Delete category
        try await categoryRepository.delete(category.id)

        // Then - All relationships should be nullified
        let allocations = try await allocationRepository.fetchAll()
        XCTAssertTrue(allocations.allSatisfy { $0.categoryId == nil })

        let transactions = try await transactionRepository.fetchAll()
        XCTAssertEqual(transactions.count, 3)
        XCTAssertTrue(transactions.allSatisfy { $0.categoryId == nil })
    }
}
