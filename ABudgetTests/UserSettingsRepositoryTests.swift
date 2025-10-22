//
//  UserSettingsRepositoryTests.swift
//  ABudgetTests
//
//  Created by Claude on 2025-10-21.
//

import XCTest
import CoreData
@testable import ABudget

@MainActor
final class UserSettingsRepositoryTests: XCTestCase {
    var repository: CoreDataUserSettingsRepository!
    var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()
        context = createInMemoryContext()
        repository = CoreDataUserSettingsRepository(context: context)
    }

    override func tearDown() async throws {
        repository = nil
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

    // MARK: - Singleton Behavior Tests

    func testGetOrCreateCreatesDefaultSettingsWhenNoneExist() async throws {
        // When
        let settings = try await repository.getOrCreate()

        // Then
        XCTAssertEqual(settings.needsPercentage, 50)
        XCTAssertEqual(settings.wantsPercentage, 30)
        XCTAssertEqual(settings.savingsPercentage, 20)
        XCTAssertNil(settings.lastViewedBudgetPeriodId)
    }

    func testGetOrCreateReturnsExistingSettings() async throws {
        // Given - Create initial settings
        let initial = try await repository.getOrCreate()
        let initialId = initial.id

        // When - Call getOrCreate again
        let fetched = try await repository.getOrCreate()

        // Then - Should return the same settings
        XCTAssertEqual(fetched.id, initialId)
        XCTAssertEqual(fetched.needsPercentage, initial.needsPercentage)
    }

    func testOnlyOneSettingsInstanceExists() async throws {
        // Given - Create settings
        _ = try await repository.getOrCreate()

        // When - Try to get settings multiple times
        let settings1 = try await repository.getOrCreate()
        let settings2 = try await repository.getOrCreate()
        let settings3 = try await repository.getOrCreate()

        // Then - All should have the same ID (singleton)
        XCTAssertEqual(settings1.id, settings2.id)
        XCTAssertEqual(settings2.id, settings3.id)

        // Verify only one entity exists in database
        let fetchRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        let count = try context.count(for: fetchRequest)
        XCTAssertEqual(count, 1, "Only one UserSettings entity should exist")
    }

    func testExistsReturnsFalseInitially() async throws {
        // When
        let exists = try await repository.exists()

        // Then
        XCTAssertFalse(exists)
    }

    func testExistsReturnsTrueAfterCreation() async throws {
        // Given
        _ = try await repository.getOrCreate()

        // When
        let exists = try await repository.exists()

        // Then
        XCTAssertTrue(exists)
    }

    // MARK: - Update Tests

    func testUpdateSettings() async throws {
        // Given
        let settings = try await repository.getOrCreate()

        // When
        var updated = settings
        updated.needsPercentage = 60
        updated.wantsPercentage = 25
        updated.savingsPercentage = 15
        let result = try await repository.update(updated)

        // Then
        XCTAssertEqual(result.needsPercentage, 60)
        XCTAssertEqual(result.wantsPercentage, 25)
        XCTAssertEqual(result.savingsPercentage, 15)

        // Verify persisted
        let fetched = try await repository.getOrCreate()
        XCTAssertEqual(fetched.needsPercentage, 60)
    }

    func testUpdateSettingsCreatesIfNotExists() async throws {
        // Given - No settings exist yet
        let newSettings = UserSettingsDTO(
            needsPercentage: 40,
            wantsPercentage: 40,
            savingsPercentage: 20
        )

        // When
        let result = try await repository.update(newSettings)

        // Then
        XCTAssertEqual(result.needsPercentage, 40)
        XCTAssertEqual(result.wantsPercentage, 40)

        // Verify created
        let exists = try await repository.exists()
        XCTAssertTrue(exists)
    }

    func testUpdateLastViewedBudgetPeriod() async throws {
        // Given
        let settings = try await repository.getOrCreate()
        let periodId = UUID()

        // When
        var updated = settings
        updated.lastViewedBudgetPeriodId = periodId
        let result = try await repository.update(updated)

        // Then
        XCTAssertEqual(result.lastViewedBudgetPeriodId, periodId)

        // Verify persisted
        let fetched = try await repository.getOrCreate()
        XCTAssertEqual(fetched.lastViewedBudgetPeriodId, periodId)
    }

    // MARK: - Reset to Defaults Tests

    func testResetToDefaults() async throws {
        // Given - Create settings with custom values
        var settings = try await repository.getOrCreate()
        settings.needsPercentage = 70
        settings.wantsPercentage = 20
        settings.savingsPercentage = 10
        _ = try await repository.update(settings)

        // When
        let reset = try await repository.resetToDefaults()

        // Then
        XCTAssertEqual(reset.needsPercentage, 50)
        XCTAssertEqual(reset.wantsPercentage, 30)
        XCTAssertEqual(reset.savingsPercentage, 20)

        // Verify persisted
        let fetched = try await repository.getOrCreate()
        XCTAssertEqual(fetched.needsPercentage, 50)
    }

    func testResetToDefaultsCreatesIfNotExists() async throws {
        // When - Reset without existing settings
        let reset = try await repository.resetToDefaults()

        // Then
        XCTAssertEqual(reset.needsPercentage, 50)
        XCTAssertEqual(reset.wantsPercentage, 30)
        XCTAssertEqual(reset.savingsPercentage, 20)

        // Verify created
        let exists = try await repository.exists()
        XCTAssertTrue(exists)
    }

    // MARK: - Computed Properties Tests

    func testHasValidPercentages() {
        // Valid case
        let valid = UserSettingsDTO(
            needsPercentage: 50,
            wantsPercentage: 30,
            savingsPercentage: 20
        )
        XCTAssertTrue(valid.hasValidPercentages)

        // Invalid case
        let invalid = UserSettingsDTO(
            needsPercentage: 50,
            wantsPercentage: 30,
            savingsPercentage: 25
        )
        XCTAssertFalse(invalid.hasValidPercentages)
    }

    func testHasNonNegativePercentages() {
        // Valid case
        let valid = UserSettingsDTO(
            needsPercentage: 50,
            wantsPercentage: 30,
            savingsPercentage: 20
        )
        XCTAssertTrue(valid.hasNonNegativePercentages)

        // Invalid case
        let invalid = UserSettingsDTO(
            needsPercentage: -10,
            wantsPercentage: 60,
            savingsPercentage: 50
        )
        XCTAssertFalse(invalid.hasNonNegativePercentages)
    }

    func testCalculateBucketAmounts() {
        // Given
        let settings = UserSettingsDTO(
            needsPercentage: 50,
            wantsPercentage: 30,
            savingsPercentage: 20
        )
        let totalIncome: Decimal = 6000

        // When
        let amounts = settings.calculateBucketAmounts(from: totalIncome)

        // Then
        XCTAssertEqual(amounts[.needs], 3000)
        XCTAssertEqual(amounts[.wants], 1800)
        XCTAssertEqual(amounts[.savings], 1200)
    }

    func testCalculateNeedsAmount() {
        // Given
        let settings = UserSettingsDTO(
            needsPercentage: 50,
            wantsPercentage: 30,
            savingsPercentage: 20
        )

        // When
        let amount = settings.calculateNeedsAmount(from: 5000)

        // Then
        XCTAssertEqual(amount, 2500)
    }

    func testCalculateWantsAmount() {
        // Given
        let settings = UserSettingsDTO(
            needsPercentage: 50,
            wantsPercentage: 30,
            savingsPercentage: 20
        )

        // When
        let amount = settings.calculateWantsAmount(from: 5000)

        // Then
        XCTAssertEqual(amount, 1500)
    }

    func testCalculateSavingsAmount() {
        // Given
        let settings = UserSettingsDTO(
            needsPercentage: 50,
            wantsPercentage: 30,
            savingsPercentage: 20
        )

        // When
        let amount = settings.calculateSavingsAmount(from: 5000)

        // Then
        XCTAssertEqual(amount, 1000)
    }

    func testDefaultSettings() {
        // When
        let defaults = UserSettingsDTO.defaultSettings

        // Then
        XCTAssertEqual(defaults.needsPercentage, 50)
        XCTAssertEqual(defaults.wantsPercentage, 30)
        XCTAssertEqual(defaults.savingsPercentage, 20)
        XCTAssertTrue(defaults.hasValidPercentages)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentGetOrCreate() async throws {
        // When - Multiple concurrent calls
        async let settings1 = repository.getOrCreate()
        async let settings2 = repository.getOrCreate()
        async let settings3 = repository.getOrCreate()

        let results = try await [settings1, settings2, settings3]

        // Then - All should have the same ID
        let ids = results.map { $0.id }
        XCTAssertEqual(Set(ids).count, 1, "All concurrent calls should return the same singleton")

        // Verify only one entity exists
        let fetchRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        let count = try context.count(for: fetchRequest)
        XCTAssertEqual(count, 1)
    }

    func testUpdatePreservesId() async throws {
        // Given
        let initial = try await repository.getOrCreate()
        let originalId = initial.id

        // When - Update multiple times
        var updated = initial
        updated.needsPercentage = 60
        _ = try await repository.update(updated)

        var updated2 = try await repository.getOrCreate()
        updated2.wantsPercentage = 25
        _ = try await repository.update(updated2)

        // Then - ID should remain the same
        let final = try await repository.getOrCreate()
        XCTAssertEqual(final.id, originalId)
    }

    // MARK: - Integration with Validation Tests

    func testUpdateWithInvalidPercentagesStillPersists() async throws {
        // Note: Repository doesn't validate - that's the caller's responsibility
        // This test verifies repository behavior, not validation

        // Given
        let settings = try await repository.getOrCreate()

        // When - Update with invalid percentages (doesn't sum to 100)
        var updated = settings
        updated.needsPercentage = 50
        updated.wantsPercentage = 30
        updated.savingsPercentage = 30 // Sum = 110
        let result = try await repository.update(updated)

        // Then - Should still save (validation is caller's responsibility)
        XCTAssertEqual(result.savingsPercentage, 30)
        XCTAssertFalse(result.hasValidPercentages)

        // Can be validated separately
        XCTAssertThrowsError(try ValidationRules.validatePercentages(result))
    }
}
