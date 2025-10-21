//
//  CategoryRepositoryTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
import CoreData
@testable import ABudget

@MainActor
final class CategoryRepositoryTests: XCTestCase {
    var repository: CoreDataCategoryRepository!
    var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory Core Data stack for testing
        context = createInMemoryContext()
        repository = CoreDataCategoryRepository(context: context)
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

    // MARK: - Create Tests

    func testCreateCategory() async throws {
        // Given
        let category = CategoryDTO(
            name: "Test Category",
            isDefault: false,
            sortOrder: 0
        )

        // When
        let created = try await repository.create(category)

        // Then
        XCTAssertEqual(created.name, "Test Category")
        XCTAssertFalse(created.isDefault)
        XCTAssertEqual(created.sortOrder, 0)
        XCTAssertNil(created.parentId)
    }

    func testCreateCategoryWithDefaultFlag() async throws {
        // Given
        let category = CategoryDTO(
            name: "Default Category",
            isDefault: true,
            sortOrder: 1
        )

        // When
        let created = try await repository.create(category)

        // Then
        XCTAssertTrue(created.isDefault)
    }

    func testCreateSubcategory() async throws {
        // Given
        let parent = try await repository.create(CategoryDTO(name: "Parent", sortOrder: 0))
        let subcategory = CategoryDTO(
            name: "Subcategory",
            sortOrder: 0,
            parentId: parent.id
        )

        // When
        let created = try await repository.create(subcategory)

        // Then
        XCTAssertEqual(created.parentId, parent.id)
        XCTAssertFalse(created.isRootCategory)
    }

    // MARK: - Read Tests

    func testFetchAll() async throws {
        // Given
        _ = try await repository.create(CategoryDTO(name: "Category 1", sortOrder: 1))
        _ = try await repository.create(CategoryDTO(name: "Category 2", sortOrder: 0))
        _ = try await repository.create(CategoryDTO(name: "Category 3", sortOrder: 2))

        // When
        let categories = try await repository.fetchAll()

        // Then
        XCTAssertEqual(categories.count, 3)
        // Should be sorted by sortOrder
        XCTAssertEqual(categories[0].name, "Category 2") // sortOrder 0
        XCTAssertEqual(categories[1].name, "Category 1") // sortOrder 1
        XCTAssertEqual(categories[2].name, "Category 3") // sortOrder 2
    }

    func testFetchById() async throws {
        // Given
        let created = try await repository.create(CategoryDTO(name: "Test Category", sortOrder: 0))

        // When
        let fetched = try await repository.fetchById(created.id)

        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, created.id)
        XCTAssertEqual(fetched?.name, "Test Category")
    }

    func testFetchByIdNotFound() async throws {
        // Given
        let nonExistentId = UUID()

        // When
        let fetched = try await repository.fetchById(nonExistentId)

        // Then
        XCTAssertNil(fetched)
    }

    func testFetchRootCategories() async throws {
        // Given
        let parent1 = try await repository.create(CategoryDTO(name: "Parent 1", sortOrder: 1))
        let parent2 = try await repository.create(CategoryDTO(name: "Parent 2", sortOrder: 0))
        _ = try await repository.create(CategoryDTO(name: "Child 1", sortOrder: 0, parentId: parent1.id))
        _ = try await repository.create(CategoryDTO(name: "Child 2", sortOrder: 1, parentId: parent1.id))

        // When
        let rootCategories = try await repository.fetchRootCategories()

        // Then
        XCTAssertEqual(rootCategories.count, 2)
        // Should be sorted by sortOrder
        XCTAssertEqual(rootCategories[0].name, "Parent 2") // sortOrder 0
        XCTAssertEqual(rootCategories[1].name, "Parent 1") // sortOrder 1
        XCTAssertTrue(rootCategories.allSatisfy { $0.isRootCategory })
    }

    func testFetchRootCategoriesWithChildren() async throws {
        // Given
        let parent = try await repository.create(CategoryDTO(name: "Parent", sortOrder: 0))
        _ = try await repository.create(CategoryDTO(name: "Child 1", sortOrder: 0, parentId: parent.id))
        _ = try await repository.create(CategoryDTO(name: "Child 2", sortOrder: 1, parentId: parent.id))

        // When
        let rootCategories = try await repository.fetchRootCategories()

        // Then
        XCTAssertEqual(rootCategories.count, 1)
        let fetchedParent = rootCategories[0]
        XCTAssertEqual(fetchedParent.name, "Parent")
        XCTAssertEqual(fetchedParent.subcategories.count, 2)
        XCTAssertEqual(fetchedParent.subcategories[0].name, "Child 1")
        XCTAssertEqual(fetchedParent.subcategories[1].name, "Child 2")
    }

    func testFetchSubcategories() async throws {
        // Given
        let parent = try await repository.create(CategoryDTO(name: "Parent", sortOrder: 0))
        _ = try await repository.create(CategoryDTO(name: "Child B", sortOrder: 1, parentId: parent.id))
        _ = try await repository.create(CategoryDTO(name: "Child A", sortOrder: 0, parentId: parent.id))
        _ = try await repository.create(CategoryDTO(name: "Child C", sortOrder: 2, parentId: parent.id))

        // When
        let subcategories = try await repository.fetchSubcategories(parentId: parent.id)

        // Then
        XCTAssertEqual(subcategories.count, 3)
        // Should be sorted by sortOrder
        XCTAssertEqual(subcategories[0].name, "Child A") // sortOrder 0
        XCTAssertEqual(subcategories[1].name, "Child B") // sortOrder 1
        XCTAssertEqual(subcategories[2].name, "Child C") // sortOrder 2
    }

    // MARK: - Update Tests

    func testUpdateCategory() async throws {
        // Given
        var category = try await repository.create(CategoryDTO(name: "Original Name", sortOrder: 0))

        // When
        category.name = "Updated Name"
        category.sortOrder = 5
        let updated = try await repository.update(category)

        // Then
        XCTAssertEqual(updated.name, "Updated Name")
        XCTAssertEqual(updated.sortOrder, 5)

        // Verify it was persisted
        let fetched = try await repository.fetchById(category.id)
        XCTAssertEqual(fetched?.name, "Updated Name")
        XCTAssertEqual(fetched?.sortOrder, 5)
    }

    func testUpdateCategoryNotFound() async throws {
        // Given
        let nonExistentCategory = CategoryDTO(
            id: UUID(),
            name: "Non-existent",
            sortOrder: 0
        )

        // When/Then
        do {
            _ = try await repository.update(nonExistentCategory)
            XCTFail("Should have thrown entityNotFound error")
        } catch let error as AppError {
            if case .entityNotFound = error {
                // Success - expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testUpdateCategoryUpdatesTimestamp() async throws {
        // Given
        let category = try await repository.create(CategoryDTO(name: "Test", sortOrder: 0))
        let originalUpdatedAt = category.updatedAt

        // Wait a tiny bit to ensure timestamp changes
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // When
        var updated = category
        updated.name = "Updated"
        let result = try await repository.update(updated)

        // Then
        XCTAssertGreaterThan(result.updatedAt, originalUpdatedAt)
    }

    // MARK: - Delete Tests

    func testDeleteCategory() async throws {
        // Given
        let category = try await repository.create(CategoryDTO(name: "To Delete", sortOrder: 0))

        // When
        try await repository.delete(category.id)

        // Then
        let fetched = try await repository.fetchById(category.id)
        XCTAssertNil(fetched)
    }

    func testDeleteCategoryNotFound() async throws {
        // Given
        let nonExistentId = UUID()

        // When/Then
        do {
            try await repository.delete(nonExistentId)
            XCTFail("Should have thrown entityNotFound error")
        } catch let error as AppError {
            if case .entityNotFound = error {
                // Success - expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testDeleteCategoryWithChildren() async throws {
        // Given
        let parent = try await repository.create(CategoryDTO(name: "Parent", sortOrder: 0))
        let child = try await repository.create(CategoryDTO(name: "Child", sortOrder: 0, parentId: parent.id))

        // When - delete parent (should cascade to children)
        try await repository.delete(parent.id)

        // Then
        let fetchedParent = try await repository.fetchById(parent.id)
        let fetchedChild = try await repository.fetchById(child.id)

        XCTAssertNil(fetchedParent)
        XCTAssertNil(fetchedChild) // Child should be deleted due to cascade
    }

    // MARK: - HasCategories Tests

    func testHasCategoriesWhenEmpty() async throws {
        // When
        let hasCategories = try await repository.hasCategories()

        // Then
        XCTAssertFalse(hasCategories)
    }

    func testHasCategoriesWhenNotEmpty() async throws {
        // Given
        _ = try await repository.create(CategoryDTO(name: "Test", sortOrder: 0))

        // When
        let hasCategories = try await repository.hasCategories()

        // Then
        XCTAssertTrue(hasCategories)
    }

    // MARK: - Parent-Child Relationship Tests

    func testMultipleLevelHierarchy() async throws {
        // Given
        let grandparent = try await repository.create(CategoryDTO(name: "Grandparent", sortOrder: 0))
        let parent = try await repository.create(CategoryDTO(name: "Parent", sortOrder: 0, parentId: grandparent.id))
        let child = try await repository.create(CategoryDTO(name: "Child", sortOrder: 0, parentId: parent.id))

        // When
        let fetchedGrandparent = try await repository.fetchById(grandparent.id)
        let fetchedParent = try await repository.fetchById(parent.id)
        let fetchedChild = try await repository.fetchById(child.id)

        // Then
        XCTAssertNotNil(fetchedGrandparent)
        XCTAssertEqual(fetchedGrandparent?.subcategories.count, 1)
        XCTAssertEqual(fetchedGrandparent?.subcategories.first?.name, "Parent")

        XCTAssertNotNil(fetchedParent)
        XCTAssertEqual(fetchedParent?.parentId, grandparent.id)
        XCTAssertEqual(fetchedParent?.subcategories.count, 1)

        XCTAssertNotNil(fetchedChild)
        XCTAssertEqual(fetchedChild?.parentId, parent.id)
        XCTAssertEqual(fetchedChild?.subcategories.count, 0)
    }

    func testSubcategoriesSortedByOrder() async throws {
        // Given
        let parent = try await repository.create(CategoryDTO(name: "Parent", sortOrder: 0))
        _ = try await repository.create(CategoryDTO(name: "Child C", sortOrder: 2, parentId: parent.id))
        _ = try await repository.create(CategoryDTO(name: "Child A", sortOrder: 0, parentId: parent.id))
        _ = try await repository.create(CategoryDTO(name: "Child B", sortOrder: 1, parentId: parent.id))

        // When
        let fetched = try await repository.fetchById(parent.id)

        // Then
        XCTAssertEqual(fetched?.subcategories.count, 3)
        XCTAssertEqual(fetched?.subcategories[0].name, "Child A")
        XCTAssertEqual(fetched?.subcategories[1].name, "Child B")
        XCTAssertEqual(fetched?.subcategories[2].name, "Child C")
    }

    // MARK: - Helper Properties Tests

    func testHasSubcategories() async throws {
        // Given
        let parent = try await repository.create(CategoryDTO(name: "Parent", sortOrder: 0))
        let childless = try await repository.create(CategoryDTO(name: "Childless", sortOrder: 1))
        _ = try await repository.create(CategoryDTO(name: "Child", sortOrder: 0, parentId: parent.id))

        // When
        let fetchedParent = try await repository.fetchById(parent.id)
        let fetchedChildless = try await repository.fetchById(childless.id)

        // Then
        XCTAssertTrue(fetchedParent?.hasSubcategories ?? false)
        XCTAssertFalse(fetchedChildless?.hasSubcategories ?? true)
    }
}

// MARK: - Mock Repository for ViewModel Testing

final class MockCategoryRepository: CategoryRepository {
    var categories: [CategoryDTO] = []
    var shouldThrowError = false
    var errorToThrow: AppError = .unknown(NSError(domain: "test", code: -1))

    func fetchAll() async throws -> [CategoryDTO] {
        if shouldThrowError { throw errorToThrow }
        return categories.sortedByOrder()
    }

    func fetchById(_ id: UUID) async throws -> CategoryDTO? {
        if shouldThrowError { throw errorToThrow }
        return categories.first { $0.id == id }
    }

    func fetchRootCategories() async throws -> [CategoryDTO] {
        if shouldThrowError { throw errorToThrow }
        return categories.filter { $0.isRootCategory }.sortedByOrder()
    }

    func fetchSubcategories(parentId: UUID) async throws -> [CategoryDTO] {
        if shouldThrowError { throw errorToThrow }
        return categories.filter { $0.parentId == parentId }.sortedByOrder()
    }

    func create(_ category: CategoryDTO) async throws -> CategoryDTO {
        if shouldThrowError { throw errorToThrow }
        var newCategory = category
        if newCategory.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
            newCategory = CategoryDTO(
                id: UUID(),
                name: category.name,
                isDefault: category.isDefault,
                sortOrder: category.sortOrder,
                createdAt: category.createdAt,
                updatedAt: category.updatedAt,
                parentId: category.parentId,
                subcategories: category.subcategories
            )
        }
        categories.append(newCategory)
        return newCategory
    }

    func update(_ category: CategoryDTO) async throws -> CategoryDTO {
        if shouldThrowError { throw errorToThrow }
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            throw AppError.entityNotFound
        }
        var updated = category
        updated.updatedAt = Date()
        categories[index] = updated
        return updated
    }

    func delete(_ id: UUID) async throws {
        if shouldThrowError { throw errorToThrow }
        guard let index = categories.firstIndex(where: { $0.id == id }) else {
            throw AppError.entityNotFound
        }
        categories.remove(at: index)
    }

    func hasCategories() async throws -> Bool {
        if shouldThrowError { throw errorToThrow }
        return !categories.isEmpty
    }
}
