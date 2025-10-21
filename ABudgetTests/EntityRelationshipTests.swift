//
//  EntityRelationshipTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
import CoreData
@testable import ABudget

@MainActor
final class EntityRelationshipTests: XCTestCase {
    var transactionRepository: CoreDataTransactionRepository!
    var budgetRepository: CoreDataBudgetPeriodRepository!
    var categoryRepository: CoreDataCategoryRepository!
    var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory Core Data stack for testing
        context = createInMemoryContext()
        transactionRepository = CoreDataTransactionRepository(context: context)
        budgetRepository = CoreDataBudgetPeriodRepository(context: context)
        categoryRepository = CoreDataCategoryRepository(context: context)
    }

    override func tearDown() async throws {
        transactionRepository = nil
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

    // MARK: - BudgetPeriod - IncomeSource Relationship Tests

    func testBudgetPeriodToIncomeSourceRelationship() async throws {
        // Given
        let income1 = IncomeSourceDTO(sourceName: "Salary", amount: 5000)
        let income2 = IncomeSourceDTO(sourceName: "Freelance", amount: 1500)
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [income1, income2]
        )

        // When
        let created = try await budgetRepository.create(period)

        // Then - Budget period should have income sources
        XCTAssertEqual(created.incomeSources.count, 2)

        // Verify income sources have reference to budget period
        for income in created.incomeSources {
            XCTAssertEqual(income.budgetPeriodId, created.id)
        }
    }

    func testDeleteBudgetPeriodCascadesIncomeSources() async throws {
        // Given
        let income = IncomeSourceDTO(sourceName: "Salary", amount: 5000)
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [income]
        )
        let created = try await budgetRepository.create(period)

        // When - Delete the budget period
        try await budgetRepository.delete(created.id)

        // Then - Income sources should be deleted (cascade rule)
        let fetchRequest: NSFetchRequest<IncomeSource> = IncomeSource.fetchRequest()
        let remainingIncome = try context.fetch(fetchRequest)
        XCTAssertEqual(remainingIncome.count, 0, "Income sources should be deleted when budget period is deleted")
    }

    // MARK: - BudgetPeriod - Transaction Relationship Tests

    func testBudgetPeriodToTransactionRelationship() async throws {
        // Given
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        let createdPeriod = try await budgetRepository.create(period)

        let transaction = TransactionDTO(
            date: Date(),
            subTotal: 100,
            tax: 10,
            merchant: "Test Store",
            bucket: .needs,
            budgetPeriodId: createdPeriod.id
        )

        // When
        let createdTransaction = try await transactionRepository.create(transaction)

        // Then
        XCTAssertEqual(createdTransaction.budgetPeriodId, createdPeriod.id)

        // Verify we can fetch transactions for the budget period
        let periodTransactions = try await transactionRepository.fetchTransactions(forBudgetPeriodId: createdPeriod.id)
        XCTAssertEqual(periodTransactions.count, 1)
    }

    func testDeleteBudgetPeriodNullifiesTransactions() async throws {
        // Given
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        let createdPeriod = try await budgetRepository.create(period)

        let transaction = TransactionDTO(
            date: Date(),
            subTotal: 100,
            merchant: "Test Store",
            bucket: .needs,
            budgetPeriodId: createdPeriod.id
        )
        let createdTransaction = try await transactionRepository.create(transaction)

        // When - Delete the budget period
        try await budgetRepository.delete(createdPeriod.id)

        // Then - Transaction should still exist but with null budget period (Nullify rule)
        let fetchedTransaction = try await transactionRepository.fetchById(createdTransaction.id)
        XCTAssertNotNil(fetchedTransaction, "Transaction should still exist")
        XCTAssertNil(fetchedTransaction?.budgetPeriodId, "Budget period should be nullified")
    }

    func testTransactionAutoAssignmentToBudgetPeriod() async throws {
        // Given
        let now = Date()
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Calendar.current.date(byAdding: .day, value: -10, to: now)!,
            endDate: Calendar.current.date(byAdding: .day, value: 10, to: now)!
        )
        let createdPeriod = try await budgetRepository.create(period)

        // When - Create transaction without explicit budget period
        let transaction = TransactionDTO(
            date: now,
            subTotal: 100,
            merchant: "Test Store",
            bucket: .needs
        )
        let createdTransaction = try await transactionRepository.create(transaction)

        // Then - Should auto-assign to the active budget period
        XCTAssertEqual(createdTransaction.budgetPeriodId, createdPeriod.id)
    }

    // MARK: - Category - Transaction Relationship Tests

    func testCategoryToTransactionRelationship() async throws {
        // Given
        let category = CategoryDTO(name: "Groceries")
        let createdCategory = try await categoryRepository.create(category)

        let transaction = TransactionDTO(
            date: Date(),
            subTotal: 100,
            merchant: "Grocery Store",
            bucket: .needs,
            categoryId: createdCategory.id
        )

        // When
        let createdTransaction = try await transactionRepository.create(transaction)

        // Then
        XCTAssertEqual(createdTransaction.categoryId, createdCategory.id)

        // Verify we can fetch transactions for the category
        let categoryTransactions = try await transactionRepository.fetchTransactions(forCategoryId: createdCategory.id)
        XCTAssertEqual(categoryTransactions.count, 1)
    }

    func testSubCategoryToTransactionRelationship() async throws {
        // Given
        let parentCategory = CategoryDTO(name: "Food")
        let createdParent = try await categoryRepository.create(parentCategory)

        let subCategory = CategoryDTO(name: "Fast Food", parentId: createdParent.id)
        let createdSub = try await categoryRepository.create(subCategory)

        let transaction = TransactionDTO(
            date: Date(),
            subTotal: 20,
            merchant: "McDonald's",
            bucket: .wants,
            categoryId: createdParent.id,
            subCategoryId: createdSub.id
        )

        // When
        let createdTransaction = try await transactionRepository.create(transaction)

        // Then
        XCTAssertEqual(createdTransaction.categoryId, createdParent.id)
        XCTAssertEqual(createdTransaction.subCategoryId, createdSub.id)
    }

    func testDeleteCategoryNullifyTransactions() async throws {
        // Given
        let category = CategoryDTO(name: "Shopping")
        let createdCategory = try await categoryRepository.create(category)

        let transaction = TransactionDTO(
            date: Date(),
            subTotal: 50,
            merchant: "Store",
            bucket: .wants,
            categoryId: createdCategory.id
        )
        let createdTransaction = try await transactionRepository.create(transaction)

        // When - Delete the category
        try await categoryRepository.delete(createdCategory.id)

        // Then - Transaction should still exist but with null category (Nullify rule)
        let fetchedTransaction = try await transactionRepository.fetchById(createdTransaction.id)
        XCTAssertNotNil(fetchedTransaction, "Transaction should still exist")
        XCTAssertNil(fetchedTransaction?.categoryId, "Category should be nullified")
    }

    func testFetchTransactionsByCategoryIncludesSubcategory() async throws {
        // Given
        let groceries = CategoryDTO(name: "Groceries")
        let createdGroceries = try await categoryRepository.create(groceries)

        // Create transaction with category as subcategory
        let transaction = TransactionDTO(
            date: Date(),
            subTotal: 100,
            merchant: "Store",
            bucket: .needs,
            subCategoryId: createdGroceries.id
        )
        _ = try await transactionRepository.create(transaction)

        // When - Fetch by category ID
        let transactions = try await transactionRepository.fetchTransactions(forCategoryId: createdGroceries.id)

        // Then - Should include transactions where category is used as subcategory
        XCTAssertEqual(transactions.count, 1)
    }

    // MARK: - Category Hierarchy Cascade Delete Tests

    func testDeleteParentCategoryCascadesChildren() async throws {
        // Given
        let parent = CategoryDTO(name: "Parent")
        let createdParent = try await categoryRepository.create(parent)

        let child1 = CategoryDTO(name: "Child 1", parentId: createdParent.id)
        let child2 = CategoryDTO(name: "Child 2", parentId: createdParent.id)

        _ = try await categoryRepository.create(child1)
        _ = try await categoryRepository.create(child2)

        // Verify setup
        let children = try await categoryRepository.fetchSubcategories(parentId: createdParent.id)
        XCTAssertEqual(children.count, 2)

        // When - Delete parent
        try await categoryRepository.delete(createdParent.id)

        // Then - Children should be deleted (cascade rule)
        let allCategories = try await categoryRepository.fetchAll()
        XCTAssertEqual(allCategories.count, 0, "All categories should be deleted")
    }

    // MARK: - Complex Relationship Tests

    func testCompleteTransactionWithAllRelationships() async throws {
        // Given - Create all related entities
        let period = BudgetPeriodDTO(
            methodology: .envelope,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [IncomeSourceDTO(sourceName: "Salary", amount: 5000)]
        )
        let createdPeriod = try await budgetRepository.create(period)

        let category = CategoryDTO(name: "Shopping")
        let createdCategory = try await categoryRepository.create(category)

        let subCategory = CategoryDTO(name: "Electronics", parentId: createdCategory.id)
        let createdSubCategory = try await categoryRepository.create(subCategory)

        // When - Create transaction with all relationships
        let transaction = TransactionDTO(
            date: Date(),
            subTotal: 500,
            tax: 50,
            merchant: "Best Buy",
            bucket: .wants,
            transactionDescription: "New laptop",
            categoryId: createdCategory.id,
            subCategoryId: createdSubCategory.id,
            budgetPeriodId: createdPeriod.id
        )
        let createdTransaction = try await transactionRepository.create(transaction)

        // Then - Verify all relationships
        XCTAssertEqual(createdTransaction.budgetPeriodId, createdPeriod.id)
        XCTAssertEqual(createdTransaction.categoryId, createdCategory.id)
        XCTAssertEqual(createdTransaction.subCategoryId, createdSubCategory.id)
        XCTAssertEqual(createdTransaction.total, 550)

        // Verify we can fetch from all angles
        let periodTransactions = try await transactionRepository.fetchTransactions(forBudgetPeriodId: createdPeriod.id)
        let categoryTransactions = try await transactionRepository.fetchTransactions(forCategoryId: createdCategory.id)
        let bucketTransactions = try await transactionRepository.fetchTransactions(forBucket: .wants)

        XCTAssertEqual(periodTransactions.count, 1)
        XCTAssertEqual(categoryTransactions.count, 1)
        XCTAssertEqual(bucketTransactions.count, 1)
    }

    func testDeleteCategoryDoesNotAffectTransactionWithOnlySubcategory() async throws {
        // Given
        let parent = CategoryDTO(name: "Parent")
        let createdParent = try await categoryRepository.create(parent)

        let child = CategoryDTO(name: "Child", parentId: createdParent.id)
        let createdChild = try await categoryRepository.create(child)

        let transaction = TransactionDTO(
            date: Date(),
            subTotal: 100,
            merchant: "Store",
            bucket: .needs,
            subCategoryId: createdChild.id  // Only subcategory, no main category
        )
        let createdTransaction = try await transactionRepository.create(transaction)

        // When - Delete parent (which cascades to child)
        try await categoryRepository.delete(createdParent.id)

        // Then - Transaction should still exist with nullified subcategory
        let fetchedTransaction = try await transactionRepository.fetchById(createdTransaction.id)
        XCTAssertNotNil(fetchedTransaction)
        XCTAssertNil(fetchedTransaction?.subCategoryId)
    }

    // MARK: - Data Integrity Tests

    func testBudgetPeriodDateRangeIntegrity() async throws {
        // Given
        let start = Date()
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: start,
            endDate: end
        )

        // When
        let created = try await budgetRepository.create(period)

        // Then
        XCTAssertTrue(created.startDate < created.endDate)
        XCTAssertTrue(created.contains(Date()))
    }

    func testTransactionDecimalAccuracy() async throws {
        // Given
        let transaction = TransactionDTO(
            date: Date(),
            subTotal: Decimal(string: "99.999")!,
            tax: Decimal(string: "8.888")!,
            merchant: "Store",
            bucket: .needs
        )

        // When
        let created = try await transactionRepository.create(transaction)

        // Then - Decimal precision should be maintained
        XCTAssertEqual(created.subTotal, Decimal(string: "99.999")!)
        XCTAssertEqual(created.tax, Decimal(string: "8.888")!)
        XCTAssertEqual(created.total, Decimal(string: "108.887")!)
    }

    func testIncomeSourceDecimalAccuracy() async throws {
        // Given
        let income = IncomeSourceDTO(
            sourceName: "Salary",
            amount: Decimal(string: "5432.10")!
        )
        let period = BudgetPeriodDTO(
            methodology: .zeroBased,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [income]
        )

        // When
        let created = try await budgetRepository.create(period)

        // Then
        XCTAssertEqual(created.totalIncome, Decimal(string: "5432.10")!)
    }
}
