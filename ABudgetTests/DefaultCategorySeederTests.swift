//
//  DefaultCategorySeederTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
import CoreData
@testable import ABudget

@MainActor
final class DefaultCategorySeederTests: XCTestCase {
    var repository: CoreDataCategoryRepository!
    var seeder: DefaultCategorySeeder!
    var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory Core Data stack for testing
        context = createInMemoryContext()
        repository = CoreDataCategoryRepository(context: context)
        seeder = DefaultCategorySeeder(repository: repository)
    }

    override func tearDown() async throws {
        seeder = nil
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

    // MARK: - Seed If Needed Tests

    func testSeedIfNeededWhenDatabaseIsEmpty() async throws {
        // Given - database is empty
        let hasCategories = try await repository.hasCategories()
        XCTAssertFalse(hasCategories)

        // When
        try await seeder.seedIfNeeded()

        // Then
        let allCategories = try await repository.fetchAll()
        XCTAssertGreaterThan(allCategories.count, 0)

        let rootCategories = try await repository.fetchRootCategories()
        XCTAssertEqual(rootCategories.count, 4) // Housing, Transportation, Food, Personal
    }

    func testSeedIfNeededWhenDatabaseAlreadyHasData() async throws {
        // Given - create existing category
        _ = try await repository.create(CategoryDTO(name: "Existing Category", sortOrder: 0))
        let initialCount = try await repository.fetchAll().count
        XCTAssertEqual(initialCount, 1)

        // When
        try await seeder.seedIfNeeded()

        // Then - should not add new categories
        let finalCount = try await repository.fetchAll().count
        XCTAssertEqual(finalCount, initialCount)
    }

    // MARK: - Default Categories Tests

    func testSeedsCorrectNumberOfRootCategories() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()
        XCTAssertEqual(rootCategories.count, 4)
    }

    func testSeedsHousingCategory() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()
        let housing = rootCategories.first { $0.name == "Housing" }

        XCTAssertNotNil(housing)
        XCTAssertTrue(housing?.isDefault ?? false)
        XCTAssertEqual(housing?.sortOrder, 0)
        XCTAssertEqual(housing?.subcategories.count, 3)

        // Verify subcategories
        let subcategoryNames = housing?.subcategories.map { $0.name }.sorted()
        XCTAssertEqual(subcategoryNames, ["Maintenance", "Rent/Mortgage", "Utilities"])

        // Verify all subcategories are marked as default
        XCTAssertTrue(housing?.subcategories.allSatisfy { $0.isDefault } ?? false)
    }

    func testSeedsTransportationCategory() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()
        let transportation = rootCategories.first { $0.name == "Transportation" }

        XCTAssertNotNil(transportation)
        XCTAssertTrue(transportation?.isDefault ?? false)
        XCTAssertEqual(transportation?.sortOrder, 1)
        XCTAssertEqual(transportation?.subcategories.count, 3)

        // Verify subcategories
        let subcategoryNames = transportation?.subcategories.map { $0.name }.sorted()
        XCTAssertEqual(subcategoryNames, ["Fuel", "Public Transit", "Vehicle Maintenance"])
    }

    func testSeedsFoodCategory() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()
        let food = rootCategories.first { $0.name == "Food" }

        XCTAssertNotNil(food)
        XCTAssertTrue(food?.isDefault ?? false)
        XCTAssertEqual(food?.sortOrder, 2)
        XCTAssertEqual(food?.subcategories.count, 2)

        // Verify subcategories
        let subcategoryNames = food?.subcategories.map { $0.name }.sorted()
        XCTAssertEqual(subcategoryNames, ["Dining Out", "Groceries"])
    }

    func testSeedsPersonalCategory() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()
        let personal = rootCategories.first { $0.name == "Personal" }

        XCTAssertNotNil(personal)
        XCTAssertTrue(personal?.isDefault ?? false)
        XCTAssertEqual(personal?.sortOrder, 3)
        XCTAssertEqual(personal?.subcategories.count, 3)

        // Verify subcategories
        let subcategoryNames = personal?.subcategories.map { $0.name }.sorted()
        XCTAssertEqual(subcategoryNames, ["Clothing", "Entertainment", "Healthcare"])
    }

    func testSeedsCorrectTotalNumberOfCategories() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let allCategories = try await repository.fetchAll()
        // 4 root categories + (3 + 3 + 2 + 3) subcategories = 15 total
        XCTAssertEqual(allCategories.count, 15)
    }

    // MARK: - Sorting Tests

    func testRootCategoriesAreSortedByOrder() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()

        XCTAssertEqual(rootCategories[0].name, "Housing")       // sortOrder 0
        XCTAssertEqual(rootCategories[1].name, "Transportation") // sortOrder 1
        XCTAssertEqual(rootCategories[2].name, "Food")          // sortOrder 2
        XCTAssertEqual(rootCategories[3].name, "Personal")      // sortOrder 3
    }

    func testSubcategoriesAreSortedByOrder() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()
        let housing = rootCategories.first { $0.name == "Housing" }

        XCTAssertEqual(housing?.subcategories[0].name, "Rent/Mortgage")  // sortOrder 0
        XCTAssertEqual(housing?.subcategories[1].name, "Utilities")      // sortOrder 1
        XCTAssertEqual(housing?.subcategories[2].name, "Maintenance")    // sortOrder 2
    }

    // MARK: - Parent-Child Relationship Tests

    func testSubcategoriesHaveCorrectParentIds() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()
        let housing = rootCategories.first { $0.name == "Housing" }

        XCTAssertNotNil(housing)
        for subcategory in housing?.subcategories ?? [] {
            XCTAssertEqual(subcategory.parentId, housing?.id)
            XCTAssertFalse(subcategory.isRootCategory)
        }
    }

    func testFetchSubcategoriesReturnsCorrectCategories() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()
        let transportation = rootCategories.first { $0.name == "Transportation" }

        guard let transportationId = transportation?.id else {
            XCTFail("Transportation category not found")
            return
        }

        let subcategories = try await repository.fetchSubcategories(parentId: transportationId)
        XCTAssertEqual(subcategories.count, 3)

        let subcategoryNames = subcategories.map { $0.name }
        XCTAssertTrue(subcategoryNames.contains("Fuel"))
        XCTAssertTrue(subcategoryNames.contains("Public Transit"))
        XCTAssertTrue(subcategoryNames.contains("Vehicle Maintenance"))
    }

    func testRootCategoriesHaveNilParentId() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()

        for category in rootCategories {
            XCTAssertNil(category.parentId)
            XCTAssertTrue(category.isRootCategory)
        }
    }

    // MARK: - Force Seeding Tests

    func testForceSeedingAddsDataEvenWhenDatabaseHasData() async throws {
        // Given - create existing category
        _ = try await repository.create(CategoryDTO(name: "Existing Category", sortOrder: 0))
        let initialCount = try await repository.fetchAll().count
        XCTAssertEqual(initialCount, 1)

        // When
        try await seeder.forceSeeding()

        // Then - should add all default categories
        let finalCount = try await repository.fetchAll().count
        XCTAssertEqual(finalCount, 16) // 1 existing + 4 root + 11 subcategories = 16
    }

    // MARK: - isDefault Flag Tests

    func testAllSeededCategoriesHaveIsDefaultFlag() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let allCategories = try await repository.fetchAll()

        for category in allCategories {
            XCTAssertTrue(category.isDefault, "Category '\(category.name)' should have isDefault = true")
        }
    }

    // MARK: - Helper Property Tests

    func testHasSubcategoriesProperty() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()

        for category in rootCategories {
            XCTAssertTrue(category.hasSubcategories)
            XCTAssertGreaterThan(category.subcategoryCount, 0)
        }
    }

    func testSubcategoriesDoNotHaveSubcategories() async throws {
        // When
        try await seeder.seedIfNeeded()

        // Then
        let rootCategories = try await repository.fetchRootCategories()
        let housing = rootCategories.first { $0.name == "Housing" }

        for subcategory in housing?.subcategories ?? [] {
            XCTAssertFalse(subcategory.hasSubcategories)
            XCTAssertEqual(subcategory.subcategoryCount, 0)
        }
    }
}
