//
//  CategoryAllocationDTO.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Business model (DTO) for CategoryAllocation
/// Represents the planned budget allocation for a category in a specific budget period
struct CategoryAllocationDTO: Identifiable, Equatable, Hashable {
    let id: UUID
    var plannedAmount: Decimal
    var carryOverAmount: Decimal
    let createdAt: Date
    var updatedAt: Date

    // Relationships
    var budgetPeriodId: UUID?
    var categoryId: UUID?

    init(
        id: UUID = UUID(),
        plannedAmount: Decimal,
        carryOverAmount: Decimal = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        budgetPeriodId: UUID? = nil,
        categoryId: UUID? = nil
    ) {
        self.id = id
        self.plannedAmount = plannedAmount
        self.carryOverAmount = carryOverAmount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.budgetPeriodId = budgetPeriodId
        self.categoryId = categoryId
    }

    // MARK: - Computed Properties

    /// Total available amount (planned + carry over)
    var totalAvailable: Decimal {
        plannedAmount + carryOverAmount
    }

    /// Checks if this allocation has carry over funds
    var hasCarryOver: Bool {
        carryOverAmount > 0
    }

    // MARK: - Conversion from Core Data Entity

    /// Converts a Core Data CategoryAllocation entity to a CategoryAllocationDTO
    /// - Parameter entity: The Core Data CategoryAllocation entity
    /// - Returns: A CategoryAllocationDTO instance
    static func from(entity: CategoryAllocation) -> CategoryAllocationDTO {
        CategoryAllocationDTO(
            id: entity.id ?? UUID(),
            plannedAmount: entity.plannedAmount as Decimal? ?? 0,
            carryOverAmount: entity.carryOverAmount as Decimal? ?? 0,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            budgetPeriodId: entity.budgetPeriod?.id,
            categoryId: entity.category?.id
        )
    }

    // MARK: - Conversion to Core Data Entity

    /// Updates an existing Core Data CategoryAllocation entity with values from this DTO
    /// - Parameters:
    ///   - entity: The Core Data CategoryAllocation entity to update
    ///   - context: The managed object context
    func updateEntity(_ entity: CategoryAllocation, in context: NSManagedObjectContext) {
        entity.id = self.id
        entity.plannedAmount = NSDecimalNumber(decimal: self.plannedAmount)
        entity.carryOverAmount = NSDecimalNumber(decimal: self.carryOverAmount)
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

        // Handle category relationship
        if let categoryId = self.categoryId {
            let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
            fetchRequest.fetchLimit = 1

            if let category = try? context.fetch(fetchRequest).first {
                entity.category = category
            }
        } else {
            entity.category = nil
        }
    }

    /// Creates a new Core Data CategoryAllocation entity from this DTO
    /// - Parameter context: The managed object context to create the entity in
    /// - Returns: A new CategoryAllocation entity
    func toEntity(in context: NSManagedObjectContext) -> CategoryAllocation {
        let entity = CategoryAllocation(context: context)
        updateEntity(entity, in: context)
        return entity
    }
}

// MARK: - Array Extensions

extension Array where Element == CategoryAllocationDTO {
    /// Calculates the total planned amount across all allocations
    var totalPlanned: Decimal {
        reduce(0) { $0 + $1.plannedAmount }
    }

    /// Calculates the total carry over amount across all allocations
    var totalCarryOver: Decimal {
        reduce(0) { $0 + $1.carryOverAmount }
    }

    /// Calculates the total available amount across all allocations
    var totalAvailable: Decimal {
        reduce(0) { $0 + $1.totalAvailable }
    }

    /// Filters allocations that have carry over funds
    var withCarryOver: [CategoryAllocationDTO] {
        filter { $0.hasCarryOver }
    }

    /// Sorts allocations by planned amount (highest first)
    func sortedByAmount() -> [CategoryAllocationDTO] {
        sorted { $0.plannedAmount > $1.plannedAmount }
    }
}
