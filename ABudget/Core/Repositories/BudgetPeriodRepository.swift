//
//  BudgetPeriodRepository.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Protocol defining the interface for BudgetPeriod data operations
protocol BudgetPeriodRepository {
    /// Fetches all budget periods
    /// - Returns: An array of all budget periods sorted by start date (newest first)
    /// - Throws: AppError if the fetch fails
    func fetchAll() async throws -> [BudgetPeriodDTO]

    /// Fetches a budget period by its ID
    /// - Parameter id: The UUID of the budget period
    /// - Returns: The budget period if found, nil otherwise
    /// - Throws: AppError if the fetch fails
    func fetchById(_ id: UUID) async throws -> BudgetPeriodDTO?

    /// Fetches the active budget period (contains current date)
    /// - Returns: The active budget period if found, nil otherwise
    /// - Throws: AppError if the fetch fails
    func fetchActivePeriod() async throws -> BudgetPeriodDTO?

    /// Fetches budget periods that overlap with a given date range
    /// - Parameters:
    ///   - startDate: The start of the date range
    ///   - endDate: The end of the date range
    /// - Returns: An array of budget periods that overlap with the date range
    /// - Throws: AppError if the fetch fails
    func fetchPeriods(from startDate: Date, to endDate: Date) async throws -> [BudgetPeriodDTO]

    /// Creates a new budget period
    /// - Parameter period: The budget period data to create
    /// - Returns: The created budget period with updated metadata
    /// - Throws: AppError if the creation fails
    func create(_ period: BudgetPeriodDTO) async throws -> BudgetPeriodDTO

    /// Updates an existing budget period
    /// - Parameter period: The budget period data with updates
    /// - Returns: The updated budget period
    /// - Throws: AppError if the update fails or period not found
    func update(_ period: BudgetPeriodDTO) async throws -> BudgetPeriodDTO

    /// Deletes a budget period by its ID
    /// - Parameter id: The UUID of the budget period to delete
    /// - Throws: AppError if the deletion fails or period not found
    func delete(_ id: UUID) async throws

    /// Adds an income source to a budget period
    /// - Parameters:
    ///   - incomeSource: The income source to add
    ///   - periodId: The UUID of the budget period
    /// - Returns: The created income source
    /// - Throws: AppError if the operation fails
    func addIncomeSource(_ incomeSource: IncomeSourceDTO, to periodId: UUID) async throws -> IncomeSourceDTO

    /// Updates an income source
    /// - Parameter incomeSource: The income source with updates
    /// - Returns: The updated income source
    /// - Throws: AppError if the update fails
    func updateIncomeSource(_ incomeSource: IncomeSourceDTO) async throws -> IncomeSourceDTO

    /// Deletes an income source
    /// - Parameter id: The UUID of the income source to delete
    /// - Throws: AppError if the deletion fails
    func deleteIncomeSource(_ id: UUID) async throws
}

/// Core Data implementation of BudgetPeriodRepository
@MainActor
final class CoreDataBudgetPeriodRepository: BudgetPeriodRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    func fetchAll() async throws -> [BudgetPeriodDTO] {
        let fetchRequest: NSFetchRequest<BudgetPeriod> = BudgetPeriod.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { BudgetPeriodDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchById(_ id: UUID) async throws -> BudgetPeriodDTO? {
        let fetchRequest: NSFetchRequest<BudgetPeriod> = BudgetPeriod.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.first.map { BudgetPeriodDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchActivePeriod() async throws -> BudgetPeriodDTO? {
        let now = Date()
        let fetchRequest: NSFetchRequest<BudgetPeriod> = BudgetPeriod.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "startDate <= %@ AND endDate >= %@",
            now as NSDate,
            now as NSDate
        )
        fetchRequest.fetchLimit = 1

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.first.map { BudgetPeriodDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchPeriods(from startDate: Date, to endDate: Date) async throws -> [BudgetPeriodDTO] {
        let fetchRequest: NSFetchRequest<BudgetPeriod> = BudgetPeriod.fetchRequest()
        // Periods overlap if: period.startDate <= endDate AND period.endDate >= startDate
        fetchRequest.predicate = NSPredicate(
            format: "startDate <= %@ AND endDate >= %@",
            endDate as NSDate,
            startDate as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { BudgetPeriodDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func create(_ period: BudgetPeriodDTO) async throws -> BudgetPeriodDTO {
        let entity = period.toEntity(in: context)

        // Create associated income sources
        for incomeSource in period.incomeSources {
            var updatedIncomeSource = incomeSource
            updatedIncomeSource.budgetPeriodId = period.id
            let incomeEntity = updatedIncomeSource.toEntity(in: context)
            incomeEntity.budgetPeriod = entity
        }

        do {
            try await saveContext()
            return BudgetPeriodDTO.from(entity: entity)
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func update(_ period: BudgetPeriodDTO) async throws -> BudgetPeriodDTO {
        let fetchRequest: NSFetchRequest<BudgetPeriod> = BudgetPeriod.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", period.id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw AppError.entityNotFound
            }

            period.updateEntity(entity, in: context)
            try await saveContext()
            return BudgetPeriodDTO.from(entity: entity)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func delete(_ id: UUID) async throws {
        let fetchRequest: NSFetchRequest<BudgetPeriod> = BudgetPeriod.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw AppError.entityNotFound
            }

            context.delete(entity)
            try await saveContext()
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.deleteFailed(error)
        }
    }

    func addIncomeSource(_ incomeSource: IncomeSourceDTO, to periodId: UUID) async throws -> IncomeSourceDTO {
        // Fetch the budget period
        let periodFetchRequest: NSFetchRequest<BudgetPeriod> = BudgetPeriod.fetchRequest()
        periodFetchRequest.predicate = NSPredicate(format: "id == %@", periodId as CVarArg)
        periodFetchRequest.fetchLimit = 1

        do {
            guard let periodEntity = try context.fetch(periodFetchRequest).first else {
                throw AppError.entityNotFound
            }

            // Create the income source
            var updatedIncomeSource = incomeSource
            updatedIncomeSource.budgetPeriodId = periodId
            let incomeEntity = updatedIncomeSource.toEntity(in: context)
            incomeEntity.budgetPeriod = periodEntity

            try await saveContext()
            return IncomeSourceDTO.from(entity: incomeEntity)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func updateIncomeSource(_ incomeSource: IncomeSourceDTO) async throws -> IncomeSourceDTO {
        let fetchRequest: NSFetchRequest<IncomeSource> = IncomeSource.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", incomeSource.id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw AppError.entityNotFound
            }

            incomeSource.updateEntity(entity, in: context)
            try await saveContext()
            return IncomeSourceDTO.from(entity: entity)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func deleteIncomeSource(_ id: UUID) async throws {
        let fetchRequest: NSFetchRequest<IncomeSource> = IncomeSource.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw AppError.entityNotFound
            }

            context.delete(entity)
            try await saveContext()
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.deleteFailed(error)
        }
    }

    // MARK: - Private Helpers

    private func saveContext() async throws {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
