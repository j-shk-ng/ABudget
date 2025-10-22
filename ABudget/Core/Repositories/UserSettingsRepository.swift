//
//  UserSettingsRepository.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Protocol defining the interface for UserSettings data operations
/// UserSettings follows a singleton pattern - only one instance exists
protocol UserSettingsRepository {
    /// Fetches the user settings, creating default settings if none exist
    /// - Returns: The user settings (guaranteed to return a value)
    /// - Throws: AppError if the operation fails
    func getOrCreate() async throws -> UserSettingsDTO

    /// Updates the user settings
    /// - Parameter settings: The settings data with updates
    /// - Returns: The updated settings
    /// - Throws: AppError if the update fails
    func update(_ settings: UserSettingsDTO) async throws -> UserSettingsDTO

    /// Resets settings to default values (50/30/20 rule)
    /// - Returns: The reset settings
    /// - Throws: AppError if the operation fails
    func resetToDefaults() async throws -> UserSettingsDTO

    /// Checks if settings exist in the database
    /// - Returns: True if settings exist, false otherwise
    /// - Throws: AppError if the check fails
    func exists() async throws -> Bool
}

/// Core Data implementation of UserSettingsRepository
@MainActor
final class CoreDataUserSettingsRepository: UserSettingsRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    func getOrCreate() async throws -> UserSettingsDTO {
        // Try to fetch existing settings
        let fetchRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        fetchRequest.fetchLimit = 1

        do {
            let entities = try context.fetch(fetchRequest)

            if let existingSettings = entities.first {
                return UserSettingsDTO.from(entity: existingSettings)
            } else {
                // Create default settings if none exist
                return try await createDefaultSettings()
            }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func update(_ settings: UserSettingsDTO) async throws -> UserSettingsDTO {
        let fetchRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        fetchRequest.fetchLimit = 1

        do {
            let entity: UserSettings

            if let existingEntity = try context.fetch(fetchRequest).first {
                entity = existingEntity
            } else {
                // If no settings exist, create one
                entity = UserSettings(context: context)
            }

            settings.updateEntity(entity, in: context)
            try await saveContext()
            return UserSettingsDTO.from(entity: entity)
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func resetToDefaults() async throws -> UserSettingsDTO {
        let fetchRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        fetchRequest.fetchLimit = 1

        do {
            let entity: UserSettings

            if let existingEntity = try context.fetch(fetchRequest).first {
                entity = existingEntity
            } else {
                entity = UserSettings(context: context)
            }

            // Reset to default percentages (50/30/20 rule)
            let defaultSettings = UserSettingsDTO.defaultSettings
            defaultSettings.updateEntity(entity, in: context)

            try await saveContext()
            return UserSettingsDTO.from(entity: entity)
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func exists() async throws -> Bool {
        let fetchRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        fetchRequest.fetchLimit = 1

        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    // MARK: - Private Helpers

    private func createDefaultSettings() async throws -> UserSettingsDTO {
        let defaultSettings = UserSettingsDTO.defaultSettings
        let entity = defaultSettings.toEntity(in: context)

        do {
            try await saveContext()
            return UserSettingsDTO.from(entity: entity)
        } catch {
            throw AppError.saveFailed(error)
        }
    }

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
