//
//  CategoryDTO.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Business model (DTO) for Category
/// Provides a separation between Core Data entities and business logic
struct CategoryDTO: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var isDefault: Bool
    var sortOrder: Int16
    let createdAt: Date
    var updatedAt: Date
    var parentId: UUID?
    var subcategories: [CategoryDTO]

    init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool = false,
        sortOrder: Int16 = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        parentId: UUID? = nil,
        subcategories: [CategoryDTO] = []
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.parentId = parentId
        self.subcategories = subcategories
    }

    // MARK: - Helper Computed Properties

    /// Indicates whether this category has subcategories
    var hasSubcategories: Bool {
        !subcategories.isEmpty
    }

    /// Indicates whether this is a root category (no parent)
    var isRootCategory: Bool {
        parentId == nil
    }

    /// Number of subcategories
    var subcategoryCount: Int {
        subcategories.count
    }

    // MARK: - Conversion from Core Data Entity

    /// Converts a Core Data Category entity to a CategoryDTO
    /// - Parameter entity: The Core Data Category entity
    /// - Returns: A CategoryDTO instance
    static func from(entity: Category) -> CategoryDTO {
        let subcategories = (entity.children as? Set<Category>)?
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { CategoryDTO.from(entity: $0) } ?? []

        return CategoryDTO(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            isDefault: entity.isDefault,
            sortOrder: entity.sortOrder,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            parentId: entity.parent?.id,
            subcategories: subcategories
        )
    }

    /// Converts a Core Data Category entity to a CategoryDTO without loading children
    /// Useful for avoiding recursive loading when children relationships aren't needed
    /// - Parameter entity: The Core Data Category entity
    /// - Returns: A CategoryDTO instance without subcategories
    static func fromWithoutChildren(entity: Category) -> CategoryDTO {
        CategoryDTO(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            isDefault: entity.isDefault,
            sortOrder: entity.sortOrder,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            parentId: entity.parent?.id,
            subcategories: []
        )
    }

    // MARK: - Conversion to Core Data Entity

    /// Updates an existing Core Data Category entity with values from this DTO
    /// - Parameter entity: The Core Data Category entity to update
    func updateEntity(_ entity: Category, in context: NSManagedObjectContext) {
        entity.id = self.id
        entity.name = self.name
        entity.isDefault = self.isDefault
        entity.sortOrder = self.sortOrder
        entity.createdAt = self.createdAt
        entity.updatedAt = Date() // Always update the timestamp

        // Handle parent relationship
        if let parentId = self.parentId {
            let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", parentId as CVarArg)
            fetchRequest.fetchLimit = 1

            if let parent = try? context.fetch(fetchRequest).first {
                entity.parent = parent
            }
        } else {
            entity.parent = nil
        }
    }

    /// Creates a new Core Data Category entity from this DTO
    /// - Parameter context: The managed object context to create the entity in
    /// - Returns: A new Category entity
    func toEntity(in context: NSManagedObjectContext) -> Category {
        let entity = Category(context: context)
        updateEntity(entity, in: context)
        return entity
    }
}

// MARK: - Array Extensions

extension Array where Element == CategoryDTO {
    /// Sorts categories by their sortOrder
    func sortedByOrder() -> [CategoryDTO] {
        sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Filters to only root categories (categories without a parent)
    func rootCategories() -> [CategoryDTO] {
        filter { $0.isRootCategory }
    }

    /// Filters to only subcategories (categories with a parent)
    func subcategoriesOnly() -> [CategoryDTO] {
        filter { !$0.isRootCategory }
    }
}
