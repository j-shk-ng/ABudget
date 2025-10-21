//
//  CategoryListViewModel.swift
//  ABudget
//
//  Created by Claude on 21/10/2025.
//

import Foundation
import Combine

@MainActor
class CategoryListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var categories: [CategoryDTO] = []
    @Published var isLoading: Bool = false
    @Published var error: AppError?
    @Published var expandedCategoryIds: Set<UUID> = []

    // MARK: - Dependencies

    private let repository: CategoryRepository
    private let seeder: DefaultCategorySeeder
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var rootCategories: [CategoryDTO] {
        categories.rootCategories()
    }

    var hasCategories: Bool {
        !categories.isEmpty
    }

    // MARK: - Initialization

    init(repository: CategoryRepository, seeder: DefaultCategorySeeder) {
        self.repository = repository
        self.seeder = seeder
    }

    // MARK: - Public Methods

    func loadCategories() async {
        isLoading = true
        error = nil

        do {
            // Seed default categories if needed
            try await seeder.seedIfNeeded()

            // Fetch all categories
            categories = try await repository.fetchAll()
            isLoading = false
        } catch let appError as AppError {
            error = appError
            isLoading = false
        } catch {
            self.error = .unknown
            isLoading = false
        }
    }

    func addCategory(name: String, parent: CategoryDTO? = nil) async {
        // Optimistic update
        let temporaryId = UUID()
        let newCategory = CategoryDTO(
            id: temporaryId,
            name: name,
            parentId: parent?.id,
            isDefault: false,
            sortOrder: Int16(categories.count),
            subcategories: [],
            createdAt: Date(),
            updatedAt: Date()
        )

        categories.append(newCategory)

        do {
            let categoryToCreate = CategoryDTO(
                name: name,
                parentId: parent?.id,
                isDefault: false,
                sortOrder: Int16(categories.count)
            )

            let createdCategory = try await repository.create(categoryToCreate)

            // Replace temporary category with real one
            if let index = categories.firstIndex(where: { $0.id == temporaryId }) {
                categories[index] = createdCategory
            }

            // Reload to get fresh data
            await loadCategories()
        } catch let appError as AppError {
            // Rollback optimistic update
            categories.removeAll { $0.id == temporaryId }
            error = appError
        } catch {
            // Rollback optimistic update
            categories.removeAll { $0.id == temporaryId }
            self.error = .unknown
        }
    }

    func updateCategory(_ category: CategoryDTO, name: String, parent: CategoryDTO? = nil) async {
        // Store original for rollback
        let originalCategories = categories

        // Optimistic update
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            var updatedCategory = category
            updatedCategory.name = name
            updatedCategory.parentId = parent?.id
            updatedCategory.updatedAt = Date()
            categories[index] = updatedCategory
        }

        do {
            var categoryToUpdate = category
            categoryToUpdate.name = name
            categoryToUpdate.parentId = parent?.id
            categoryToUpdate.updatedAt = Date()

            _ = try await repository.update(categoryToUpdate)

            // Reload to get fresh data
            await loadCategories()
        } catch let appError as AppError {
            // Rollback optimistic update
            categories = originalCategories
            error = appError
        } catch {
            // Rollback optimistic update
            categories = originalCategories
            self.error = .unknown
        }
    }

    func deleteCategory(_ category: CategoryDTO) async {
        // Store original for rollback
        let originalCategories = categories

        // Optimistic update
        categories.removeAll { $0.id == category.id }

        do {
            try await repository.delete(id: category.id)

            // Reload to get fresh data with cascade deletions
            await loadCategories()
        } catch let appError as AppError {
            // Rollback optimistic update
            categories = originalCategories
            error = appError
        } catch {
            // Rollback optimistic update
            categories = originalCategories
            self.error = .unknown
        }
    }

    func toggleExpanded(_ categoryId: UUID) {
        if expandedCategoryIds.contains(categoryId) {
            expandedCategoryIds.remove(categoryId)
        } else {
            expandedCategoryIds.insert(categoryId)
        }
    }

    func isExpanded(_ categoryId: UUID) -> Bool {
        expandedCategoryIds.contains(categoryId)
    }

    func subcategories(for parent: CategoryDTO) -> [CategoryDTO] {
        categories.filter { $0.parentId == parent.id }.sortedByOrder()
    }

    func clearError() {
        error = nil
    }

    func retryLastOperation() async {
        await loadCategories()
    }
}
