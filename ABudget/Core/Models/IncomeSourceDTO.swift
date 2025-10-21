//
//  IncomeSourceDTO.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Business model (DTO) for IncomeSource
/// Represents a source of income for a budget period
struct IncomeSourceDTO: Identifiable, Equatable, Hashable {
    let id: UUID
    var sourceName: String
    var amount: Decimal
    var budgetPeriodId: UUID?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sourceName: String,
        amount: Decimal,
        budgetPeriodId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceName = sourceName
        self.amount = amount
        self.budgetPeriodId = budgetPeriodId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Conversion from Core Data Entity

    /// Converts a Core Data IncomeSource entity to an IncomeSourceDTO
    /// - Parameter entity: The Core Data IncomeSource entity
    /// - Returns: An IncomeSourceDTO instance
    static func from(entity: IncomeSource) -> IncomeSourceDTO {
        IncomeSourceDTO(
            id: entity.id ?? UUID(),
            sourceName: entity.sourceName ?? "",
            amount: entity.amount as Decimal? ?? 0,
            budgetPeriodId: entity.budgetPeriod?.id,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date()
        )
    }

    // MARK: - Conversion to Core Data Entity

    /// Updates an existing Core Data IncomeSource entity with values from this DTO
    /// - Parameters:
    ///   - entity: The Core Data IncomeSource entity to update
    ///   - context: The managed object context
    func updateEntity(_ entity: IncomeSource, in context: NSManagedObjectContext) {
        entity.id = self.id
        entity.sourceName = self.sourceName
        entity.amount = NSDecimalNumber(decimal: self.amount)
        entity.createdAt = self.createdAt
        entity.updatedAt = Date() // Always update the timestamp

        // Handle budget period relationship
        if let budgetPeriodId = self.budgetPeriodId {
            let fetchRequest: NSFetchRequest<BudgetPeriod> = BudgetPeriod.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", budgetPeriodId as CVarArg)
            fetchRequest.fetchLimit = 1

            if let budgetPeriod = try? context.fetch(fetchRequest).first {
                entity.budgetPeriod = budgetPeriod
            }
        } else {
            entity.budgetPeriod = nil
        }
    }

    /// Creates a new Core Data IncomeSource entity from this DTO
    /// - Parameter context: The managed object context to create the entity in
    /// - Returns: A new IncomeSource entity
    func toEntity(in context: NSManagedObjectContext) -> IncomeSource {
        let entity = IncomeSource(context: context)
        updateEntity(entity, in: context)
        return entity
    }
}

// MARK: - Array Extensions

extension Array where Element == IncomeSourceDTO {
    /// Calculates the total income from all sources
    var totalIncome: Decimal {
        reduce(0) { $0 + $1.amount }
    }

    /// Sorts income sources alphabetically by name
    func sortedByName() -> [IncomeSourceDTO] {
        sorted { $0.sourceName < $1.sourceName }
    }
}
