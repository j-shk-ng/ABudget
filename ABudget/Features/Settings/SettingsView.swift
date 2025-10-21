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
        NavigationStack {
            VStack {
                Spacer()

                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
