//
//  CategoryRepository.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Protocol defining the interface for Category data operations
protocol CategoryRepository {
    /// Fetches all categories
    /// - Returns: An array of all categories
    /// - Throws: AppError if the fetch fails
    func fetchAll() async throws -> [CategoryDTO]

    /// Fetches a category by its ID
    /// - Parameter id: The UUID of the category
    /// - Returns: The category if found, nil otherwise
    /// - Throws: AppError if the fetch fails
    func fetchById(_ id: UUID) async throws -> CategoryDTO?

    /// Fetches only root categories (categories without a parent)
    /// - Returns: An array of root categories sorted by sortOrder
    /// - Throws: AppError if the fetch fails
    func fetchRootCategories() async throws -> [CategoryDTO]

    /// Fetches subcategories for a given parent category
    /// - Parameter parentId: The UUID of the parent category
    /// - Returns: An array of subcategories sorted by sortOrder
    /// - Throws: AppError if the fetch fails
    func fetchSubcategories(parentId: UUID) async throws -> [CategoryDTO]

    /// Creates a new category
    /// - Parameter category: The category data to create
    /// - Returns: The created category with updated metadata
    /// - Throws: AppError if the creation fails
    func create(_ category: CategoryDTO) async throws -> CategoryDTO

    /// Updates an existing category
    /// - Parameter category: The category data with updates
    /// - Returns: The updated category
    /// - Throws: AppError if the update fails or category not found
    func update(_ category: CategoryDTO) async throws -> CategoryDTO

    /// Deletes a category by its ID
    /// - Parameter id: The UUID of the category to delete
    /// - Throws: AppError if the deletion fails or category not found
    func delete(_ id: UUID) async throws

    /// Checks if any categories exist in the database
    /// - Returns: True if categories exist, false otherwise
    /// - Throws: AppError if the check fails
    func hasCategories() async throws -> Bool
}

/// Core Data implementation of CategoryRepository
@MainActor
final class CoreDataCategoryRepository: CategoryRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    func fetchAll() async throws -> [CategoryDTO] {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { CategoryDTO.fromWithoutChildren(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchById(_ id: UUID) async throws -> CategoryDTO? {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.first.map { CategoryDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchRootCategories() async throws -> [CategoryDTO] {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "parent == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { CategoryDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchSubcategories(parentId: UUID) async throws -> [CategoryDTO] {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "parent.id == %@", parentId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { CategoryDTO.fromWithoutChildren(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func create(_ category: CategoryDTO) async throws -> CategoryDTO {
        let entity = category.toEntity(in: context)

        do {
            try await saveContext()
            return CategoryDTO.from(entity: entity)
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func update(_ category: CategoryDTO) async throws -> CategoryDTO {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", category.id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw AppError.entityNotFound
            }

            category.updateEntity(entity, in: context)
            try await saveContext()
            return CategoryDTO.from(entity: entity)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func delete(_ id: UUID) async throws {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
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

    func hasCategories() async throws -> Bool {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.fetchLimit = 1

        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            throw AppError.fetchFailed(error)
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
