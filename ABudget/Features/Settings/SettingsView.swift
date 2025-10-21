//
//  SettingsView.swift
//  ABudget
//
//  Created by Joshua King on 10/20/25.
//

import SwiftUI

struct SettingsView: View {

    // MARK: - Body

    var body: some View {
        let repository = CoreDataCategoryRepository(
            context: CoreDataStack.shared.mainContext
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
}

// MARK: - Preview

#Preview {
    SettingsView()
}
