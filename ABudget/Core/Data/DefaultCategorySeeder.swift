//
//  DefaultCategorySeeder.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Seeds the database with default categories if empty
@MainActor
final class DefaultCategorySeeder {
    private let repository: CategoryRepository

    init(repository: CategoryRepository) {
        self.repository = repository
    }

    /// Seeds default categories if the database is empty
    /// - Throws: AppError if seeding fails
    func seedIfNeeded() async throws {
        // Check if categories already exist
        let hasCategories = try await repository.hasCategories()
        guard !hasCategories else { return }

        // Seed default categories
        try await seedDefaultCategories()
    }

    /// Seeds the default categories with their subcategories
    /// - Throws: AppError if seeding fails
    private func seedDefaultCategories() async throws {
        let defaultCategories = [
            // Housing category with subcategories
            CategorySeed(
                name: "Housing",
                sortOrder: 0,
                subcategories: [
                    SubcategorySeed(name: "Rent/Mortgage", sortOrder: 0),
                    SubcategorySeed(name: "Utilities", sortOrder: 1),
                    SubcategorySeed(name: "Maintenance", sortOrder: 2)
                ]
            ),
            // Transportation category with subcategories
            CategorySeed(
                name: "Transportation",
                sortOrder: 1,
                subcategories: [
                    SubcategorySeed(name: "Fuel", sortOrder: 0),
                    SubcategorySeed(name: "Public Transit", sortOrder: 1),
                    SubcategorySeed(name: "Vehicle Maintenance", sortOrder: 2)
                ]
            ),
            // Food category with subcategories
            CategorySeed(
                name: "Food",
                sortOrder: 2,
                subcategories: [
                    SubcategorySeed(name: "Groceries", sortOrder: 0),
                    SubcategorySeed(name: "Dining Out", sortOrder: 1)
                ]
            ),
            // Personal category with subcategories
            CategorySeed(
                name: "Personal",
                sortOrder: 3,
                subcategories: [
                    SubcategorySeed(name: "Healthcare", sortOrder: 0),
                    SubcategorySeed(name: "Entertainment", sortOrder: 1),
                    SubcategorySeed(name: "Clothing", sortOrder: 2)
                ]
            )
        ]

        // Create each category and its subcategories
        for categorySeed in defaultCategories {
            try await createCategoryWithSubcategories(categorySeed)
        }
    }

    /// Creates a category with its subcategories
    /// - Parameter seed: The category seed data
    /// - Throws: AppError if creation fails
    private func createCategoryWithSubcategories(_ seed: CategorySeed) async throws {
        // Create the parent category
        let parentCategory = CategoryDTO(
            name: seed.name,
            isDefault: true,
            sortOrder: seed.sortOrder
        )

        let createdParent = try await repository.create(parentCategory)

        // Create subcategories
        for subcategorySeed in seed.subcategories {
            let subcategory = CategoryDTO(
                name: subcategorySeed.name,
                isDefault: true,
                sortOrder: subcategorySeed.sortOrder,
                parentId: createdParent.id
            )

            _ = try await repository.create(subcategory)
        }
    }

    /// Force seeds default categories regardless of existing data
    /// Useful for testing or resetting data
    /// - Throws: AppError if seeding fails
    func forceSeeding() async throws {
        try await seedDefaultCategories()
    }
}

// MARK: - Helper Structs

private struct CategorySeed {
    let name: String
    let sortOrder: Int16
    let subcategories: [SubcategorySeed]
}

private struct SubcategorySeed {
    let name: String
    let sortOrder: Int16
}
