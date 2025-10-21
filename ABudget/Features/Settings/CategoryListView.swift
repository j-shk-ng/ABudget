//
//  CategoryListView.swift
//  ABudget
//
//  Created by Claude on 21/10/2025.
//

import SwiftUI

struct CategoryListView: View {
    // MARK: - State Object

    @StateObject private var viewModel: CategoryListViewModel

    // MARK: - State

    @State private var showAddCategory = false
    @State private var editingCategory: CategoryDTO?
    @State private var categoryToDelete: CategoryDTO?
    @State private var showDeleteConfirmation = false

    @State private var newCategoryName = ""
    @State private var newCategoryParent: CategoryDTO?

    // MARK: - Initialization

    init(viewModel: CategoryListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && !viewModel.hasCategories {
                    loadingView
                } else if !viewModel.hasCategories {
                    emptyStateView
                } else {
                    categoryListView
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        newCategoryName = ""
                        newCategoryParent = nil
                        showAddCategory = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                CategoryFormView(
                    name: $newCategoryName,
                    selectedParent: $newCategoryParent,
                    availableParents: viewModel.rootCategories,
                    isEditing: false,
                    onSave: {
                        Task {
                            await viewModel.addCategory(
                                name: newCategoryName,
                                parent: newCategoryParent
                            )
                        }
                    }
                )
            }
            .sheet(item: $editingCategory) { category in
                CategoryFormView(
                    name: Binding(
                        get: { category.name },
                        set: { newCategoryName = $0 }
                    ),
                    selectedParent: Binding(
                        get: {
                            if let parentId = category.parentId {
                                return viewModel.categories.first { $0.id == parentId }
                            }
                            return nil
                        },
                        set: { newCategoryParent = $0 }
                    ),
                    availableParents: viewModel.rootCategories.filter { $0.id != category.id },
                    isEditing: true,
                    onSave: {
                        Task {
                            await viewModel.updateCategory(
                                category,
                                name: newCategoryName,
                                parent: newCategoryParent
                            )
                        }
                    }
                )
            }
            .alert("Delete Category", isPresented: $showDeleteConfirmation, presenting: categoryToDelete) { category in
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteCategory(category)
                    }
                }
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
            } message: { category in
                Text("Are you sure you want to delete '\(category.name)'? This action cannot be undone.")
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.clearError() } }
            ), presenting: viewModel.error) { error in
                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }
                Button("Retry") {
                    Task {
                        await viewModel.retryLastOperation()
                    }
                }
            } message: { error in
                Text(error.localizedDescription)
            }
            .task {
                await viewModel.loadCategories()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading categories...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Categories")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add your first category to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: {
                newCategoryName = ""
                newCategoryParent = nil
                showAddCategory = true
            }) {
                Label("Add Category", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Category List View

    private var categoryListView: some View {
        List {
            ForEach(viewModel.rootCategories) { category in
                CategoryRowView(
                    category: category,
                    isExpanded: viewModel.isExpanded(category.id),
                    subcategories: viewModel.subcategories(for: category),
                    onTap: {
                        newCategoryName = category.name
                        newCategoryParent = nil
                        if let parentId = category.parentId {
                            newCategoryParent = viewModel.categories.first { $0.id == parentId }
                        }
                        editingCategory = category
                    },
                    onToggleExpand: {
                        withAnimation {
                            viewModel.toggleExpanded(category.id)
                        }
                    },
                    onDelete: {
                        categoryToDelete = category
                        showDeleteConfirmation = true
                    }
                )

                if viewModel.isExpanded(category.id) {
                    ForEach(viewModel.subcategories(for: category)) { subcategory in
                        SubcategoryRowView(
                            category: subcategory,
                            onTap: {
                                newCategoryName = subcategory.name
                                newCategoryParent = category
                                editingCategory = subcategory
                            },
                            onDelete: {
                                categoryToDelete = subcategory
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Category Row View

struct CategoryRowView: View {
    let category: CategoryDTO
    let isExpanded: Bool
    let subcategories: [CategoryDTO]
    let onTap: () -> Void
    let onToggleExpand: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            if !subcategories.isEmpty {
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 20)
            }

            Button(action: onTap) {
                HStack {
                    Text(category.name)
                        .fontWeight(.medium)

                    Spacer()

                    if !subcategories.isEmpty {
                        Text("\(subcategories.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Subcategory Row View

struct SubcategoryRowView: View {
    let category: CategoryDTO
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Color.clear
                    .frame(width: 20)

                Image(systemName: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(category.name)
                    .foregroundColor(.primary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview("Category List") {
    let repository = CoreDataCategoryRepository(
        context: CoreDataStack.preview.viewContext
    )

    CategoryListView(
        viewModel: CategoryListViewModel(
            repository: repository,
            seeder: DefaultCategorySeeder(
                repository: repository
            )
        )
    )
}

#Preview("Empty State") {
    let repository = CoreDataCategoryRepository(
        context: CoreDataStack.preview.viewContext
    )

    return CategoryListView(
        viewModel: CategoryListViewModel(
            repository: repository,
            seeder: DefaultCategorySeeder(
                repository: repository
            )
        )
    )
}
