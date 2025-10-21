//
//  CategoryFormView.swift
//  ABudget
//
//  Created by Claude on 21/10/2025.
//

import SwiftUI

struct CategoryFormView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Bindings

    @Binding var name: String
    @Binding var selectedParent: CategoryDTO?

    // MARK: - Properties

    let availableParents: [CategoryDTO]
    let isEditing: Bool
    let onSave: () -> Void

    @State private var showParentPicker = false

    // MARK: - Initialization

    init(
        name: Binding<String>,
        selectedParent: Binding<CategoryDTO?>,
        availableParents: [CategoryDTO],
        isEditing: Bool = false,
        onSave: @escaping () -> Void
    ) {
        self._name = name
        self._selectedParent = selectedParent
        self.availableParents = availableParents
        self.isEditing = isEditing
        self.onSave = onSave
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Parent Category (Optional)")) {
                    if availableParents.isEmpty {
                        Text("No parent categories available")
                            .foregroundColor(.secondary)
                    } else {
                        Button(action: {
                            showParentPicker = true
                        }) {
                            HStack {
                                Text("Parent")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(selectedParent?.name ?? "None")
                                    .foregroundColor(.secondary)
                            }
                        }

                        if selectedParent != nil {
                            Button(action: {
                                selectedParent = nil
                            }) {
                                Text("Clear Parent")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showParentPicker) {
                ParentCategoryPickerView(
                    selectedParent: $selectedParent,
                    availableParents: availableParents
                )
            }
        }
    }
}

// MARK: - Parent Category Picker

struct ParentCategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedParent: CategoryDTO?
    let availableParents: [CategoryDTO]

    var body: some View {
        NavigationView {
            List {
                ForEach(availableParents) { parent in
                    Button(action: {
                        selectedParent = parent
                        dismiss()
                    }) {
                        HStack {
                            Text(parent.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedParent?.id == parent.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Parent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Add Category") {
    CategoryFormView(
        name: .constant(""),
        selectedParent: .constant(nil),
        availableParents: [
            CategoryDTO(
                id: UUID(),
                name: "Housing",
                parentId: nil,
                isDefault: true,
                sortOrder: 0,
                subcategories: [],
                createdAt: Date(),
                updatedAt: Date()
            ),
            CategoryDTO(
                id: UUID(),
                name: "Transportation",
                parentId: nil,
                isDefault: true,
                sortOrder: 1,
                subcategories: [],
                createdAt: Date(),
                updatedAt: Date()
            )
        ],
        isEditing: false,
        onSave: {}
    )
}

#Preview("Edit Category") {
    CategoryFormView(
        name: .constant("Rent"),
        selectedParent: .constant(CategoryDTO(
            id: UUID(),
            name: "Housing",
            parentId: nil,
            isDefault: true,
            sortOrder: 0,
            subcategories: [],
            createdAt: Date(),
            updatedAt: Date()
        )),
        availableParents: [
            CategoryDTO(
                id: UUID(),
                name: "Housing",
                parentId: nil,
                isDefault: true,
                sortOrder: 0,
                subcategories: [],
                createdAt: Date(),
                updatedAt: Date()
            )
        ],
        isEditing: true,
        onSave: {}
    )
}
