//
//  CoreDataStackTests.swift
//  ABudgetTests
//
//  Created by Joshua King on 10/20/25.
//

import XCTest
import CoreData
@testable import ABudget

@MainActor
final class CoreDataStackTests: XCTestCase {

    var coreDataStack: CoreDataStack!

    override func setUp() async throws {
        try await super.setUp()
        // Create an in-memory stack for testing
        coreDataStack = CoreDataStack(inMemory: true)
    }

    override func tearDown() async throws {
        coreDataStack = nil
        try await super.tearDown()
    }

    // MARK: - Stack Initialization Tests

    func testCoreDataStackInitialization() async throws {
        // Given: A Core Data stack
        let stack = CoreDataStack(inMemory: true)

        // Then: The stack should be initialized properly
        XCTAssertNotNil(stack.persistentContainer, "Persistent container should not be nil")
        XCTAssertNotNil(stack.viewContext, "View context should not be nil")
    }

    func testViewContextConfiguration() async throws {
        // Given: A Core Data stack
        let context = coreDataStack.viewContext

        // Then: View context should be configured correctly
        XCTAssertTrue(context.automaticallyMergesChangesFromParent,
                      "View context should automatically merge changes from parent")
        XCTAssertTrue(context.mergePolicy as AnyObject === NSMergeByPropertyObjectTrumpMergePolicy,
                      "View context should use NSMergeByPropertyObjectTrumpMergePolicy")
    }

    // MARK: - Save Tests

    func testSaveCategory() async throws {
        // Given: A Core Data context
        let context = coreDataStack.viewContext

        // When: Creating and saving a test category
        let category = ABudget.Category(context: context)
        category.id = UUID()
        category.name = "Test Category"
        category.isDefault = false
        category.sortOrder = 1
        category.createdAt = Date()
        category.updatedAt = Date()

        try await coreDataStack.saveContext()

        // Then: The category should be saved successfully
        let fetchRequest: NSFetchRequest<ABudget.Category> = NSFetchRequest<ABudget.Category>(entityName: "Category")
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 1, "Should have exactly one category")
        XCTAssertEqual(results.first?.name, "Test Category", "Category name should match")
        XCTAssertNotNil(results.first?.id, "Category ID should not be nil")
    }

    func testSaveMultipleEntities() async throws {
        // Given: A Core Data context
        let context = coreDataStack.viewContext

        // When: Creating and saving multiple categories
        for i in 1...5 {
            let category = ABudget.Category(context: context)
            category.id = UUID()
            category.name = "Test Category \(i)"
            category.isDefault = i == 1
            category.sortOrder = Int16(i)
            category.createdAt = Date()
            category.updatedAt = Date()
        }

        try await coreDataStack.saveContext()

        // Then: All categories should be saved
        let fetchRequest: NSFetchRequest<ABudget.Category> = NSFetchRequest<ABudget.Category>(entityName: "Category")
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 5, "Should have exactly 5 categories")
    }

    func testSaveContextWithoutChanges() async throws {
        // Given: A context with no changes
        let context = coreDataStack.viewContext
        XCTAssertFalse(context.hasChanges, "Context should not have changes initially")

        // When: Attempting to save without changes
        // Then: Should not throw an error
        try await coreDataStack.saveContext()
    }

    // MARK: - Fetch Tests

    func testFetchCategories() async throws {
        // Given: Multiple categories in the database
        let context = coreDataStack.viewContext
        let expectedNames = ["Groceries", "Entertainment", "Transportation"]

        for (index, name) in expectedNames.enumerated() {
            let category = ABudget.Category(context: context)
            category.id = UUID()
            category.name = name
            category.isDefault = false
            category.sortOrder = Int16(index)
            category.createdAt = Date()
            category.updatedAt = Date()
        }

        try await coreDataStack.saveContext()

        // When: Fetching all categories
        let fetchRequest: NSFetchRequest<ABudget.Category> = NSFetchRequest<ABudget.Category>(entityName: "Category")
        let results = try context.fetch(fetchRequest)

        // Then: All categories should be fetched
        XCTAssertEqual(results.count, expectedNames.count, "Should fetch all categories")

        let fetchedNames = results.map { $0.name ?? "" }
        for name in expectedNames {
            XCTAssertTrue(fetchedNames.contains(name), "Should contain category named \(name)")
        }
    }

    func testFetchWithPredicate() async throws {
        // Given: Multiple categories with different names
        let context = coreDataStack.viewContext

        let category1 = ABudget.Category(context: context)
        category1.id = UUID()
        category1.name = "Food"
        category1.isDefault = false
        category1.sortOrder = 1
        category1.createdAt = Date()
        category1.updatedAt = Date()

        let category2 = ABudget.Category(context: context)
        category2.id = UUID()
        category2.name = "Transportation"
        category2.isDefault = false
        category2.sortOrder = 2
        category2.createdAt = Date()
        category2.updatedAt = Date()

        let category3 = ABudget.Category(context: context)
        category3.id = UUID()
        category3.name = "Fast Food"
        category3.isDefault = false
        category3.sortOrder = 3
        category3.createdAt = Date()
        category3.updatedAt = Date()

        try await coreDataStack.saveContext()

        // When: Fetching categories with a predicate
        let fetchRequest: NSFetchRequest<ABudget.Category> = NSFetchRequest<ABudget.Category>(entityName: "Category")
        fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", "food")
        let results = try context.fetch(fetchRequest)

        // Then: Should only fetch matching categories
        XCTAssertEqual(results.count, 2, "Should fetch 2 categories containing 'food'")
    }

    func testFetchWithSortDescriptor() async throws {
        // Given: Multiple categories
        let context = coreDataStack.viewContext
        let names = ["Utilities", "Entertainment", "Food"]

        for (index, name) in names.enumerated() {
            let category = ABudget.Category(context: context)
            category.id = UUID()
            category.name = name
            category.isDefault = false
            category.sortOrder = Int16(index)
            category.createdAt = Date()
            category.updatedAt = Date()
        }

        try await coreDataStack.saveContext()

        // When: Fetching with sort descriptor
        let fetchRequest: NSFetchRequest<ABudget.Category> = NSFetchRequest<ABudget.Category>(entityName: "Category")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let results = try context.fetch(fetchRequest)

        // Then: Results should be sorted
        XCTAssertEqual(results.count, 3, "Should fetch all 3 categories")
        XCTAssertEqual(results[0].name, "Entertainment")
        XCTAssertEqual(results[1].name, "Food")
        XCTAssertEqual(results[2].name, "Utilities")
    }

    // MARK: - Delete Tests

    func testDeleteEntity() async throws {
        // Given: A saved category
        let context = coreDataStack.viewContext
        let category = ABudget.Category(context: context)
        category.id = UUID()
        category.name = "To Be Deleted"
        category.isDefault = false
        category.sortOrder = 1
        category.createdAt = Date()
        category.updatedAt = Date()

        try await coreDataStack.saveContext()

        // When: Deleting the category
        context.delete(category)
        try await coreDataStack.saveContext()

        // Then: Category should be deleted
        let fetchRequest: NSFetchRequest<ABudget.Category> = NSFetchRequest<ABudget.Category>(entityName: "Category")
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 0, "Should have no categories after deletion")
    }

    // MARK: - Update Tests

    func testUpdateEntity() async throws {
        // Given: A saved category
        let context = coreDataStack.viewContext
        let category = ABudget.Category(context: context)
        let originalId = UUID()
        category.id = originalId
        category.name = "Original Name"
        category.isDefault = false
        category.sortOrder = 1
        category.createdAt = Date()
        category.updatedAt = Date()

        try await coreDataStack.saveContext()

        // When: Updating the category
        category.name = "Updated Name"
        category.updatedAt = Date()
        try await coreDataStack.saveContext()

        // Then: Category should be updated
        let fetchRequest: NSFetchRequest<ABudget.Category> = NSFetchRequest<ABudget.Category>(entityName: "Category")
        fetchRequest.predicate = NSPredicate(format: "id == %@", originalId as CVarArg)
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 1, "Should have exactly one category")
        XCTAssertEqual(results.first?.name, "Updated Name", "Name should be updated")
        XCTAssertEqual(results.first?.id, originalId, "ID should remain the same")
    }

    // MARK: - Preview Container Tests

    func testPreviewContainer() async throws {
        // Given: A preview Core Data stack
        let previewStack = CoreDataStack.preview

        // When: Fetching categories from preview
        let fetchRequest: NSFetchRequest<ABudget.Category> = NSFetchRequest<ABudget.Category>(entityName: "Category")
        let results = try previewStack.viewContext.fetch(fetchRequest)

        // Then: Preview data should be present
        XCTAssertEqual(results.count, 5, "Preview should contain 5 sample categories")

        // Verify the sample data
        for (_, category) in results.enumerated() {
            XCTAssertNotNil(category.id, "Category ID should not be nil")
            XCTAssertTrue(category.name?.contains("Sample Category") ?? false,
                          "Category name should contain 'Sample Category'")
        }
    }

    func testPreviewContainerIsInMemory() async throws {
        // Given: A preview Core Data stack
        let previewStack = CoreDataStack.preview

        // When: Adding data to preview
        let context = previewStack.viewContext
        let category = ABudget.Category(context: context)
        category.id = UUID()
        category.name = "Preview Test"
        category.isDefault = false
        category.sortOrder = 99
        category.createdAt = Date()
        category.updatedAt = Date()

        try previewStack.saveContextSync()

        // Then: Data should exist in the preview context
        let fetchRequest: NSFetchRequest<ABudget.Category> = NSFetchRequest<ABudget.Category>(entityName: "Category")
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Preview Test")
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 1, "Should find the preview test category")
    }

    // MARK: - Background Context Tests

    func testBackgroundContext() async throws {
        // Given: A Core Data stack
        let backgroundContext = coreDataStack.newBackgroundContext()

        // Then: Background context should be configured correctly
        XCTAssertNotNil(backgroundContext, "Background context should not be nil")
        XCTAssertTrue(backgroundContext.mergePolicy as AnyObject === NSMergeByPropertyObjectTrumpMergePolicy,
                      "Background context should use correct merge policy")
    }

    func testPerformBackgroundTask() async throws {
        // Given: A Core Data stack
        let expectation = expectation(description: "Background task completed")

        // When: Performing a background task
        coreDataStack.performBackgroundTask { context in
            let category = ABudget.Category(context: context)
            category.id = UUID()
            category.name = "Background Category"
            category.isDefault = false
            category.sortOrder = 1
            category.createdAt = Date()
            category.updatedAt = Date()

            do {
                try context.save()
                expectation.fulfill()
            } catch {
                XCTFail("Failed to save in background context: \(error)")
            }
        }

        // Then: Task should complete
        await fulfillment(of: [expectation], timeout: 5.0)

        // Verify the category was saved
        let fetchRequest: NSFetchRequest<ABudget.Category> = NSFetchRequest<ABudget.Category>(entityName: "Category")
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Background Category")
        let results = try coreDataStack.viewContext.fetch(fetchRequest)

        XCTAssertEqual(results.count, 1, "Background category should be saved")
    }
}
