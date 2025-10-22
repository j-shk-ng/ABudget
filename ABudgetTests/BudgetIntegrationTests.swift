//
//  BudgetIntegrationTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
import CoreData
@testable import ABudget

@MainActor
final class BudgetIntegrationTests: XCTestCase {
    var budgetRepository: CoreDataBudgetPeriodRepository!
    var transactionRepository: CoreDataTransactionRepository!
    var categoryRepository: CoreDataCategoryRepository!
    var allocationRepository: CoreDataCategoryAllocationRepository!
    var settingsRepository: CoreDataUserSettingsRepository!
    var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()

        context = createInMemoryContext()
        budgetRepository = CoreDataBudgetPeriodRepository(context: context)
        transactionRepository = CoreDataTransactionRepository(context: context)
        categoryRepository = CoreDataCategoryRepository(context: context)
        allocationRepository = CoreDataCategoryAllocationRepository(context: context)
        settingsRepository = CoreDataUserSettingsRepository(context: context)
    }

    override func tearDown() async throws {
        budgetRepository = nil
        transactionRepository = nil
        categoryRepository = nil
        allocationRepository = nil
        settingsRepository = nil
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
            XCTAssertNil(error)
        }

        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Complete Budget Setup Tests

    func testCreateCompleteBudgetWithAllRelationships() async throws {
        // Given - Create user settings
        let settings = try await settingsRepository.getOrCreate()
        XCTAssertEqual(settings.needsPercentage, 50)

        // Create categories
        let groceries = try await categoryRepository.create(CategoryDTO(name: "Groceries"))
        let utilities = try await categoryRepository.create(CategoryDTO(name: "Utilities"))
        let entertainment = try await categoryRepository.create(CategoryDTO(name: "Entertainment"))

        // Create budget period with income
        let income1 = IncomeSourceDTO(sourceName: "Salary", amount: 5000)
        let income2 = IncomeSourceDTO(sourceName: "Freelance", amount: 1000)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!

        let period = BudgetPeriodDTO(
            methodology: .percentage,
            startDate: startDate,
            endDate: endDate,
            incomeSources: [income1, income2]
        )
        let createdPeriod = try await budgetRepository.create(period)

        // Verify period was created with income
        XCTAssertEqual(createdPeriod.incomeSources.count, 2)
        XCTAssertEqual(createdPeriod.totalIncome, 6000)

        // Create category allocations using settings percentages
        let totalIncome = createdPeriod.totalIncome
        let needsAmount = settings.calculateNeedsAmount(from: totalIncome) // 50% = 3000
        let wantsAmount = settings.calculateWantsAmount(from: totalIncome) // 30% = 1800

        let groceryAllocation = CategoryAllocationDTO(
            plannedAmount: needsAmount / 2, // 1500 for groceries
            budgetPeriodId: createdPeriod.id,
            categoryId: groceries.id
        )
        let utilitiesAllocation = CategoryAllocationDTO(
            plannedAmount: needsAmount / 2, // 1500 for utilities
            budgetPeriodId: createdPeriod.id,
            categoryId: utilities.id
        )
        let entertainmentAllocation = CategoryAllocationDTO(
            plannedAmount: wantsAmount, // 1800 for entertainment
            budgetPeriodId: createdPeriod.id,
            categoryId: entertainment.id
        )

        _ = try await allocationRepository.create(groceryAllocation)
        _ = try await allocationRepository.create(utilitiesAllocation)
        _ = try await allocationRepository.create(entertainmentAllocation)

        // Verify allocations were created
        let allocations = try await allocationRepository.fetchAllocations(forBudgetPeriodId: createdPeriod.id)
        XCTAssertEqual(allocations.count, 3)
        XCTAssertEqual(allocations.totalPlanned, 4800)

        // Create transactions
        let transaction1 = TransactionDTO(
            date: startDate,
            subTotal: 150,
            tax: 15,
            merchant: "Whole Foods",
            bucket: .needs,
            categoryId: groceries.id,
            budgetPeriodId: createdPeriod.id
        )
        let transaction2 = TransactionDTO(
            date: startDate,
            subTotal: 100,
            merchant: "Electric Company",
            bucket: .needs,
            categoryId: utilities.id,
            budgetPeriodId: createdPeriod.id
        )
        let transaction3 = TransactionDTO(
            date: startDate,
            subTotal: 50,
            merchant: "Movie Theater",
            bucket: .wants,
            categoryId: entertainment.id,
            budgetPeriodId: createdPeriod.id
        )

        _ = try await transactionRepository.create(transaction1)
        _ = try await transactionRepository.create(transaction2)
        _ = try await transactionRepository.create(transaction3)

        // Verify transactions were created and linked
        let periodTransactions = try await transactionRepository.fetchTransactions(forBudgetPeriodId: createdPeriod.id)
        XCTAssertEqual(periodTransactions.count, 3)
        XCTAssertEqual(periodTransactions.totalAmount, 315) // 165 + 100 + 50

        // Verify transactions by category
        let groceryTransactions = try await transactionRepository.fetchTransactions(forCategoryId: groceries.id)
        XCTAssertEqual(groceryTransactions.count, 1)
        XCTAssertEqual(groceryTransactions.first?.total, 165)

        // Verify budget tracking
        let needsTransactions = periodTransactions.filtered(by: .needs)
        let wantsTransactions = periodTransactions.filtered(by: .wants)
        XCTAssertEqual(needsTransactions.totalAmount, 265)
        XCTAssertEqual(wantsTransactions.totalAmount, 50)

        // Calculate remaining budget for each category
        let groceryAlloc = try await allocationRepository.fetchAllocation(
            forBudgetPeriodId: createdPeriod.id,
            categoryId: groceries.id
        )
        let grocerySpent = groceryTransactions.totalAmount
        let groceryRemaining = groceryAlloc!.totalAvailable - grocerySpent
        XCTAssertEqual(groceryRemaining, 1335) // 1500 - 165
    }

    func testComplexBudgetPeriodWithCarryOver() async throws {
        // Given - Create first budget period
        let income = IncomeSourceDTO(sourceName: "Salary", amount: 3000)
        let period1Start = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let period1End = Calendar.current.date(byAdding: .month, value: -1, to: Date())!

        let period1 = BudgetPeriodDTO(
            methodology: .envelope,
            startDate: period1Start,
            endDate: period1End,
            incomeSources: [income]
        )
        let createdPeriod1 = try await budgetRepository.create(period1)

        // Create category
        let savings = try await categoryRepository.create(CategoryDTO(name: "Emergency Fund"))

        // Allocate to savings
        let allocation1 = CategoryAllocationDTO(
            plannedAmount: 500,
            budgetPeriodId: createdPeriod1.id,
            categoryId: savings.id
        )
        _ = try await allocationRepository.create(allocation1)

        // Spend less than allocated (leaving 200 to carry over)
        let transaction = TransactionDTO(
            date: period1Start,
            subTotal: 300,
            merchant: "Bank Transfer",
            bucket: .savings,
            categoryId: savings.id,
            budgetPeriodId: createdPeriod1.id
        )
        _ = try await transactionRepository.create(transaction)

        // Create second budget period with carry over
        let period2Start = Date()
        let period2End = Calendar.current.date(byAdding: .month, value: 1, to: period2Start)!

        let period2 = BudgetPeriodDTO(
            methodology: .envelope,
            startDate: period2Start,
            endDate: period2End,
            incomeSources: [income]
        )
        let createdPeriod2 = try await budgetRepository.create(period2)

        // Allocate with carry over from previous period
        let carryOver: Decimal = 200
        let allocation2 = CategoryAllocationDTO(
            plannedAmount: 500,
            carryOverAmount: carryOver,
            budgetPeriodId: createdPeriod2.id,
            categoryId: savings.id
        )
        let createdAllocation2 = try await allocationRepository.create(allocation2)

        // Verify carry over
        XCTAssertEqual(createdAllocation2.carryOverAmount, 200)
        XCTAssertEqual(createdAllocation2.totalAvailable, 700) // 500 + 200
        XCTAssertTrue(createdAllocation2.hasCarryOver)
    }

    func testMultipleBudgetPeriodsNonOverlapping() async throws {
        // Create multiple sequential budget periods
        var periods: [BudgetPeriodDTO] = []

        for i in 0..<3 {
            let startDate = Calendar.current.date(byAdding: .month, value: i * 2, to: Date())!
            let endDate = Calendar.current.date(byAdding: .month, value: (i * 2) + 1, to: Date())!

            let income = IncomeSourceDTO(sourceName: "Salary", amount: 4000)
            let period = BudgetPeriodDTO(
                methodology: .zeroBased,
                startDate: startDate,
                endDate: endDate,
                incomeSources: [income]
            )

            let created = try await budgetRepository.create(period)
            periods.append(created)
        }

        // Verify all periods exist
        let allPeriods = try await budgetRepository.fetchAll()
        XCTAssertEqual(allPeriods.count, 3)

        // Verify periods don't overlap
        for i in 0..<periods.count {
            for j in (i + 1)..<periods.count {
                let period1 = periods[i]
                let period2 = periods[j]

                // Periods shouldn't overlap
                let overlaps = period1.startDate <= period2.endDate && period1.endDate >= period2.startDate
                XCTAssertFalse(overlaps, "Period \(i) and \(j) should not overlap")
            }
        }
    }

    func testBudgetPerformanceTracking() async throws {
        // Create a budget period with allocations
        let income = IncomeSourceDTO(sourceName: "Salary", amount: 5000)
        let period = BudgetPeriodDTO(
            methodology: .percentage,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            incomeSources: [income]
        )
        let createdPeriod = try await budgetRepository.create(period)

        // Create categories and allocations
        let housing = try await categoryRepository.create(CategoryDTO(name: "Housing"))
        let food = try await categoryRepository.create(CategoryDTO(name: "Food"))

        _ = try await allocationRepository.create(CategoryAllocationDTO(
            plannedAmount: 2000,
            budgetPeriodId: createdPeriod.id,
            categoryId: housing.id
        ))
        _ = try await allocationRepository.create(CategoryAllocationDTO(
            plannedAmount: 600,
            budgetPeriodId: createdPeriod.id,
            categoryId: food.id
        ))

        // Add various transactions
        _ = try await transactionRepository.create(TransactionDTO(
            subTotal: 1800,
            merchant: "Rent",
            bucket: .needs,
            categoryId: housing.id,
            budgetPeriodId: createdPeriod.id
        ))
        _ = try await transactionRepository.create(TransactionDTO(
            subTotal: 150,
            merchant: "Grocery Store",
            bucket: .needs,
            categoryId: food.id,
            budgetPeriodId: createdPeriod.id
        ))
        _ = try await transactionRepository.create(TransactionDTO(
            subTotal: 75,
            merchant: "Restaurant",
            bucket: .wants,
            categoryId: food.id,
            budgetPeriodId: createdPeriod.id
        ))

        // Calculate budget performance
        let allocations = try await allocationRepository.fetchAllocations(forBudgetPeriodId: createdPeriod.id)
        let transactions = try await transactionRepository.fetchTransactions(forBudgetPeriodId: createdPeriod.id)

        let totalPlanned = allocations.totalPlanned // 2600
        let totalSpent = transactions.totalAmount // 2025
        let remaining = totalPlanned - totalSpent // 575

        XCTAssertEqual(totalPlanned, 2600)
        XCTAssertEqual(totalSpent, 2025)
        XCTAssertEqual(remaining, 575)

        // Check category-specific performance
        let housingTransactions = try await transactionRepository.fetchTransactions(forCategoryId: housing.id)
        let housingAllocation = try await allocationRepository.fetchAllocation(
            forBudgetPeriodId: createdPeriod.id,
            categoryId: housing.id
        )

        let housingSpent = housingTransactions.totalAmount
        let housingRemaining = housingAllocation!.totalAvailable - housingSpent

        XCTAssertEqual(housingSpent, 1800)
        XCTAssertEqual(housingRemaining, 200) // 2000 - 1800
    }
}
