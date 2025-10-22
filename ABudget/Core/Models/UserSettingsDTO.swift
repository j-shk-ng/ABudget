//
//  UserSettingsDTO.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Business model (DTO) for UserSettings
/// Represents user preferences and configuration (singleton pattern)
struct UserSettingsDTO: Identifiable, Equatable {
    let id: UUID
    var needsPercentage: Decimal
    var wantsPercentage: Decimal
    var savingsPercentage: Decimal
    var lastViewedBudgetPeriodId: UUID?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        needsPercentage: Decimal = 50,
        wantsPercentage: Decimal = 30,
        savingsPercentage: Decimal = 20,
        lastViewedBudgetPeriodId: UUID? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.needsPercentage = needsPercentage
        self.wantsPercentage = wantsPercentage
        self.savingsPercentage = savingsPercentage
        self.lastViewedBudgetPeriodId = lastViewedBudgetPeriodId
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// Total of all percentages (should equal 100)
    var totalPercentage: Decimal {
        needsPercentage + wantsPercentage + savingsPercentage
    }

    /// Checks if percentages are valid (sum equals 100)
    var hasValidPercentages: Bool {
        totalPercentage == 100
    }

    /// Checks if all percentages are non-negative
    var hasNonNegativePercentages: Bool {
        needsPercentage >= 0 && wantsPercentage >= 0 && savingsPercentage >= 0
    }

    /// Calculates the amount for needs bucket based on total income
    /// - Parameter totalIncome: The total income amount
    /// - Returns: The calculated needs amount
    func calculateNeedsAmount(from totalIncome: Decimal) -> Decimal {
        (totalIncome * needsPercentage) / 100
    }

    /// Calculates the amount for wants bucket based on total income
    /// - Parameter totalIncome: The total income amount
    /// - Returns: The calculated wants amount
    func calculateWantsAmount(from totalIncome: Decimal) -> Decimal {
        (totalIncome * wantsPercentage) / 100
    }

    /// Calculates the amount for savings bucket based on total income
    /// - Parameter totalIncome: The total income amount
    /// - Returns: The calculated savings amount
    func calculateSavingsAmount(from totalIncome: Decimal) -> Decimal {
        (totalIncome * savingsPercentage) / 100
    }

    /// Calculates bucket amounts for a given total income
    /// - Parameter totalIncome: The total income amount
    /// - Returns: A dictionary mapping bucket types to their calculated amounts
    func calculateBucketAmounts(from totalIncome: Decimal) -> [BucketType: Decimal] {
        [
            .needs: calculateNeedsAmount(from: totalIncome),
            .wants: calculateWantsAmount(from: totalIncome),
            .savings: calculateSavingsAmount(from: totalIncome)
        ]
    }

    // MARK: - Conversion from Core Data Entity

    /// Converts a Core Data UserSettings entity to a UserSettingsDTO
    /// - Parameter entity: The Core Data UserSettings entity
    /// - Returns: A UserSettingsDTO instance
    static func from(entity: UserSettings) -> UserSettingsDTO {
        UserSettingsDTO(
            id: entity.id ?? UUID(),
            needsPercentage: entity.needsPercentage as Decimal? ?? 50,
            wantsPercentage: entity.wantsPercentage as Decimal? ?? 30,
            savingsPercentage: entity.savingsPercentage as Decimal? ?? 20,
            lastViewedBudgetPeriodId: entity.lastViewedBudgetPeriodId,
            updatedAt: entity.updatedAt ?? Date()
        )
    }

    // MARK: - Conversion to Core Data Entity

    /// Updates an existing Core Data UserSettings entity with values from this DTO
    /// - Parameters:
    ///   - entity: The Core Data UserSettings entity to update
    ///   - context: The managed object context
    func updateEntity(_ entity: UserSettings, in context: NSManagedObjectContext) {
        entity.id = self.id
        entity.needsPercentage = NSDecimalNumber(decimal: self.needsPercentage)
        entity.wantsPercentage = NSDecimalNumber(decimal: self.wantsPercentage)
        entity.savingsPercentage = NSDecimalNumber(decimal: self.savingsPercentage)
        entity.lastViewedBudgetPeriodId = self.lastViewedBudgetPeriodId
        entity.updatedAt = Date() // Always update the timestamp
    }

    /// Creates a new Core Data UserSettings entity from this DTO
    /// - Parameter context: The managed object context to create the entity in
    /// - Returns: A new UserSettings entity
    func toEntity(in context: NSManagedObjectContext) -> UserSettings {
        let entity = UserSettings(context: context)
        updateEntity(entity, in: context)
        return entity
    }

    // MARK: - Factory Methods

    /// Creates default user settings with 50/30/20 rule
    static var defaultSettings: UserSettingsDTO {
        UserSettingsDTO(
            needsPercentage: 50,
            wantsPercentage: 30,
            savingsPercentage: 20
        )
    }
}
