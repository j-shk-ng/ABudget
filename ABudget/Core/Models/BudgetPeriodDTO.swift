//
//  BudgetPeriodDTO.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Business model (DTO) for BudgetPeriod
/// Represents a time period for budgeting with associated income sources
struct BudgetPeriodDTO: Identifiable, Equatable, Hashable {
    let id: UUID
    var methodology: BudgetMethodology
    var startDate: Date
    var endDate: Date
    let createdAt: Date
    var updatedAt: Date
    var incomeSources: [IncomeSourceDTO]

    init(
        id: UUID = UUID(),
        methodology: BudgetMethodology,
        startDate: Date,
        endDate: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        incomeSources: [IncomeSourceDTO] = []
    ) {
        self.id = id
        self.methodology = methodology
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.incomeSources = incomeSources
    }

    // MARK: - Computed Properties

    /// The date range of this budget period
    var dateRange: ClosedRange<Date> {
        startDate...endDate
    }

    /// Duration of the budget period in days
    var durationInDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    /// Total income for this budget period
    var totalIncome: Decimal {
        incomeSources.totalIncome
    }

    /// Checks if a given date falls within this budget period
    /// - Parameter date: The date to check
    /// - Returns: True if the date is within the period
    func contains(_ date: Date) -> Bool {
        dateRange.contains(date)
    }

    /// Checks if this budget period is currently active
    var isActive: Bool {
        contains(Date())
    }

    // MARK: - Conversion from Core Data Entity

    /// Converts a Core Data BudgetPeriod entity to a BudgetPeriodDTO
    /// - Parameter entity: The Core Data BudgetPeriod entity
    /// - Returns: A BudgetPeriodDTO instance
    static func from(entity: BudgetPeriod) -> BudgetPeriodDTO {
        let incomeSources = (entity.incomeSources as? Set<IncomeSource>)?
            .map { IncomeSourceDTO.from(entity: $0) }
            .sorted { $0.sourceName < $1.sourceName } ?? []

        let methodology = BudgetMethodology(rawValue: entity.methodology ?? "zeroBased") ?? .zeroBased

        return BudgetPeriodDTO(
            id: entity.id ?? UUID(),
            methodology: methodology,
            startDate: entity.startDate ?? Date(),
            endDate: entity.endDate ?? Date(),
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            incomeSources: incomeSources
        )
    }

    /// Converts a Core Data BudgetPeriod entity to a BudgetPeriodDTO without loading income sources
    /// Useful for avoiding recursive loading when relationships aren't needed
    /// - Parameter entity: The Core Data BudgetPeriod entity
    /// - Returns: A BudgetPeriodDTO instance without income sources
    static func fromWithoutIncomeSources(entity: BudgetPeriod) -> BudgetPeriodDTO {
        let methodology = BudgetMethodology(rawValue: entity.methodology ?? "zeroBased") ?? .zeroBased

        return BudgetPeriodDTO(
            id: entity.id ?? UUID(),
            methodology: methodology,
            startDate: entity.startDate ?? Date(),
            endDate: entity.endDate ?? Date(),
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            incomeSources: []
        )
    }

    // MARK: - Conversion to Core Data Entity

    /// Updates an existing Core Data BudgetPeriod entity with values from this DTO
    /// - Parameters:
    ///   - entity: The Core Data BudgetPeriod entity to update
    ///   - context: The managed object context
    func updateEntity(_ entity: BudgetPeriod, in context: NSManagedObjectContext) {
        entity.id = self.id
        entity.methodology = self.methodology.rawValue
        entity.startDate = self.startDate
        entity.endDate = self.endDate
        entity.createdAt = self.createdAt
        entity.updatedAt = Date() // Always update the timestamp
    }

    /// Creates a new Core Data BudgetPeriod entity from this DTO
    /// - Parameter context: The managed object context to create the entity in
    /// - Returns: A new BudgetPeriod entity
    func toEntity(in context: NSManagedObjectContext) -> BudgetPeriod {
        let entity = BudgetPeriod(context: context)
        updateEntity(entity, in: context)
        return entity
    }
}

// MARK: - Array Extensions

extension Array where Element == BudgetPeriodDTO {
    /// Sorts budget periods by start date (newest first)
    func sortedByDate() -> [BudgetPeriodDTO] {
        sorted { $0.startDate > $1.startDate }
    }

    /// Filters to only active budget periods
    var activeOnly: [BudgetPeriodDTO] {
        filter { $0.isActive }
    }

    /// Finds the budget period that contains a specific date
    /// - Parameter date: The date to search for
    /// - Returns: The budget period containing the date, if found
    func periodContaining(_ date: Date) -> BudgetPeriodDTO? {
        first { $0.contains(date) }
    }
}
