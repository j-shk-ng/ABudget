//
//  CategoryAllocationRepository.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Protocol defining the interface for CategoryAllocation data operations
protocol CategoryAllocationRepository {
    /// Fetches all category allocations
    /// - Returns: An array of all category allocations
    /// - Throws: AppError if the fetch fails
    func fetchAll() async throws -> [CategoryAllocationDTO]

    /// Fetches a category allocation by its ID
    /// - Parameter id: The UUID of the category allocation
    /// - Returns: The category allocation if found, nil otherwise
    /// - Throws: AppError if the fetch fails
    func fetchById(_ id: UUID) async throws -> CategoryAllocationDTO?

    /// Fetches all category allocations for a specific budget period
    /// - Parameter periodId: The UUID of the budget period
    /// - Returns: An array of category allocations for the budget period
    /// - Throws: AppError if the fetch fails
    func fetchAllocations(forBudgetPeriodId periodId: UUID) async throws -> [CategoryAllocationDTO]

    /// Fetches all category allocations for a specific category
    /// - Parameter categoryId: The UUID of the category
    /// - Returns: An array of category allocations for the category
    /// - Throws: AppError if the fetch fails
    func fetchAllocations(forCategoryId categoryId: UUID) async throws -> [CategoryAllocationDTO]

    /// Fetches a category allocation for a specific budget period and category
    /// - Parameters:
    ///   - periodId: The UUID of the budget period
    ///   - categoryId: The UUID of the category
    /// - Returns: The category allocation if found, nil otherwise
    /// - Throws: AppError if the fetch fails
    func fetchAllocation(forBudgetPeriodId periodId: UUID, categoryId: UUID) async throws -> CategoryAllocationDTO?

    /// Creates a new category allocation
    /// - Parameter allocation: The category allocation data to create
    /// - Returns: The created category allocation with updated metadata
    /// - Throws: AppError if the creation fails
    func create(_ allocation: CategoryAllocationDTO) async throws -> CategoryAllocationDTO

    /// Updates an existing category allocation
    /// - Parameter allocation: The category allocation data with updates
    /// - Returns: The updated category allocation
    /// - Throws: AppError if the update fails or allocation not found
    func update(_ allocation: CategoryAllocationDTO) async throws -> CategoryAllocationDTO

    /// Deletes a category allocation by its ID
    /// - Parameter id: The UUID of the category allocation to delete
    /// - Throws: AppError if the deletion fails or allocation not found
    func delete(_ id: UUID) async throws

    /// Deletes all category allocations for a specific budget period
    /// - Parameter periodId: The UUID of the budget period
    /// - Throws: AppError if the deletion fails
    func deleteAllocations(forBudgetPeriodId periodId: UUID) async throws
}

/// Core Data implementation of CategoryAllocationRepository
@MainActor
final class CoreDataCategoryAllocationRepository: CategoryAllocationRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    func fetchAll() async throws -> [CategoryAllocationDTO] {
        let fetchRequest: NSFetchRequest<CategoryAllocation> = CategoryAllocation.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "plannedAmount", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { CategoryAllocationDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchById(_ id: UUID) async throws -> CategoryAllocationDTO? {
        let fetchRequest: NSFetchRequest<CategoryAllocation> = CategoryAllocation.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.first.map { CategoryAllocationDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchAllocations(forBudgetPeriodId periodId: UUID) async throws -> [CategoryAllocationDTO] {
        let fetchRequest: NSFetchRequest<CategoryAllocation> = CategoryAllocation.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "budgetPeriod.id == %@", periodId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "plannedAmount", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { CategoryAllocationDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchAllocations(forCategoryId categoryId: UUID) async throws -> [CategoryAllocationDTO] {
        let fetchRequest: NSFetchRequest<CategoryAllocation> = CategoryAllocation.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "category.id == %@", categoryId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "budgetPeriod.startDate", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { CategoryAllocationDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchAllocation(forBudgetPeriodId periodId: UUID, categoryId: UUID) async throws -> CategoryAllocationDTO? {
        let fetchRequest: NSFetchRequest<CategoryAllocation> = CategoryAllocation.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "budgetPeriod.id == %@ AND category.id == %@",
            periodId as CVarArg,
            categoryId as CVarArg
        )
        fetchRequest.fetchLimit = 1

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.first.map { CategoryAllocationDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func create(_ allocation: CategoryAllocationDTO) async throws -> CategoryAllocationDTO {
        let entity = allocation.toEntity(in: context)

        do {
            try await saveContext()
            return CategoryAllocationDTO.from(entity: entity)
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func update(_ allocation: CategoryAllocationDTO) async throws -> CategoryAllocationDTO {
        let fetchRequest: NSFetchRequest<CategoryAllocation> = CategoryAllocation.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", allocation.id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw AppError.entityNotFound
            }

            allocation.updateEntity(entity, in: context)
            try await saveContext()
            return CategoryAllocationDTO.from(entity: entity)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func delete(_ id: UUID) async throws {
        let fetchRequest: NSFetchRequest<CategoryAllocation> = CategoryAllocation.fetchRequest()
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

    func deleteAllocations(forBudgetPeriodId periodId: UUID) async throws {
        let fetchRequest: NSFetchRequest<CategoryAllocation> = CategoryAllocation.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "budgetPeriod.id == %@", periodId as CVarArg)

        do {
            let entities = try context.fetch(fetchRequest)
            entities.forEach { context.delete($0) }
            try await saveContext()
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
