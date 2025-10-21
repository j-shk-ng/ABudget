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

    func testSaveTestEntity() async throws {
        // Given: A Core Data context
        let context = coreDataStack.viewContext

        // When: Creating and saving a test entity
        let testEntity = TestEntity(context: context)
        testEntity.id = UUID()
        testEntity.name = "Test Entity"

        try await coreDataStack.saveContext()

        // Then: The entity should be saved successfully
        let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 1, "Should have exactly one test entity")
        XCTAssertEqual(results.first?.name, "Test Entity", "Entity name should match")
        XCTAssertNotNil(results.first?.id, "Entity ID should not be nil")
    }

    func testSaveMultipleEntities() async throws {
        // Given: A Core Data context
        let context = coreDataStack.viewContext

        // When: Creating and saving multiple entities
        for i in 1...5 {
            let testEntity = TestEntity(context: context)
            testEntity.id = UUID()
            testEntity.name = "Test Entity \(i)"
        }

        try await coreDataStack.saveContext()

        // Then: All entities should be saved
        let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 5, "Should have exactly 5 test entities")
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

    func testFetchTestEntities() async throws {
        // Given: Multiple test entities in the database
        let context = coreDataStack.viewContext
        let expectedNames = ["Entity 1", "Entity 2", "Entity 3"]

        for name in expectedNames {
            let entity = TestEntity(context: context)
            entity.id = UUID()
            entity.name = name
        }

        try await coreDataStack.saveContext()

        // When: Fetching all test entities
        let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
        let results = try context.fetch(fetchRequest)

        // Then: All entities should be fetched
        XCTAssertEqual(results.count, expectedNames.count, "Should fetch all entities")

        let fetchedNames = results.map { $0.name ?? "" }
        for name in expectedNames {
            XCTAssertTrue(fetchedNames.contains(name), "Should contain entity named \(name)")
        }
    }

    func testFetchWithPredicate() async throws {
        // Given: Multiple test entities with different names
        let context = coreDataStack.viewContext

        let entity1 = TestEntity(context: context)
        entity1.id = UUID()
        entity1.name = "Apple"

        let entity2 = TestEntity(context: context)
        entity2.id = UUID()
        entity2.name = "Banana"

        let entity3 = TestEntity(context: context)
        entity3.id = UUID()
        entity3.name = "Apple Pie"

        try await coreDataStack.saveContext()

        // When: Fetching entities with a predicate
        let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", "apple")
        let results = try context.fetch(fetchRequest)

        // Then: Should only fetch matching entities
        XCTAssertEqual(results.count, 2, "Should fetch 2 entities containing 'apple'")
    }

    func testFetchWithSortDescriptor() async throws {
        // Given: Multiple test entities
        let context = coreDataStack.viewContext
        let names = ["Zebra", "Apple", "Mango"]

        for name in names {
            let entity = TestEntity(context: context)
            entity.id = UUID()
            entity.name = name
        }

        try await coreDataStack.saveContext()

        // When: Fetching with sort descriptor
        let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let results = try context.fetch(fetchRequest)

        // Then: Results should be sorted
        XCTAssertEqual(results.count, 3, "Should fetch all 3 entities")
        XCTAssertEqual(results[0].name, "Apple")
        XCTAssertEqual(results[1].name, "Mango")
        XCTAssertEqual(results[2].name, "Zebra")
    }

    // MARK: - Delete Tests

    func testDeleteEntity() async throws {
        // Given: A saved test entity
        let context = coreDataStack.viewContext
        let testEntity = TestEntity(context: context)
        testEntity.id = UUID()
        testEntity.name = "To Be Deleted"

        try await coreDataStack.saveContext()

        // When: Deleting the entity
        context.delete(testEntity)
        try await coreDataStack.saveContext()

        // Then: Entity should be deleted
        let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 0, "Should have no entities after deletion")
    }

    // MARK: - Update Tests

    func testUpdateEntity() async throws {
        // Given: A saved test entity
        let context = coreDataStack.viewContext
        let testEntity = TestEntity(context: context)
        let originalId = UUID()
        testEntity.id = originalId
        testEntity.name = "Original Name"

        try await coreDataStack.saveContext()

        // When: Updating the entity
        testEntity.name = "Updated Name"
        try await coreDataStack.saveContext()

        // Then: Entity should be updated
        let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", originalId as CVarArg)
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 1, "Should have exactly one entity")
        XCTAssertEqual(results.first?.name, "Updated Name", "Name should be updated")
        XCTAssertEqual(results.first?.id, originalId, "ID should remain the same")
    }

    // MARK: - Preview Container Tests

    func testPreviewContainer() async throws {
        // Given: A preview Core Data stack
        let previewStack = CoreDataStack.preview

        // When: Fetching entities from preview
        let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
        let results = try previewStack.viewContext.fetch(fetchRequest)

        // Then: Preview data should be present
        XCTAssertEqual(results.count, 5, "Preview should contain 5 sample entities")

        // Verify the sample data
        for (_, entity) in results.enumerated() {
            XCTAssertNotNil(entity.id, "Entity ID should not be nil")
            XCTAssertTrue(entity.name?.contains("Test Item") ?? false,
                          "Entity name should contain 'Test Item'")
        }
    }

    func testPreviewContainerIsInMemory() async throws {
        // Given: A preview Core Data stack
        let previewStack = CoreDataStack.preview

        // When: Adding data to preview
        let context = previewStack.viewContext
        let entity = TestEntity(context: context)
        entity.id = UUID()
        entity.name = "Preview Test"

        try previewStack.saveContextSync()

        // Then: Data should exist in the preview context
        let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Preview Test")
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 1, "Should find the preview test entity")
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
            let entity = TestEntity(context: context)
            entity.id = UUID()
            entity.name = "Background Entity"

            do {
                try context.save()
                expectation.fulfill()
            } catch {
                XCTFail("Failed to save in background context: \(error)")
            }
        }

        // Then: Task should complete
        await fulfillment(of: [expectation], timeout: 5.0)

        // Verify the entity was saved
        let fetchRequest: NSFetchRequest<TestEntity> = TestEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Background Entity")
        let results = try coreDataStack.viewContext.fetch(fetchRequest)

        XCTAssertEqual(results.count, 1, "Background entity should be saved")
    }
}
