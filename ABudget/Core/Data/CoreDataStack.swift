//
//  CoreDataStack.swift
//  ABudget
//
//  Created by Joshua King on 10/20/25.
//

import Foundation
import CoreData

/// Manages the Core Data stack for the ABudget application
@MainActor
final class CoreDataStack: ObservableObject {

    // MARK: - Singleton

    static let shared = CoreDataStack()

    // MARK: - Properties

    /// The persistent container for the application
    let persistentContainer: NSPersistentContainer

    /// The main view context for UI operations
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    // MARK: - Initialization

    /// Initialize the Core Data stack
    /// - Parameter inMemory: If true, uses an in-memory store (useful for previews and testing)
    init(inMemory: Bool = false) {
        persistentContainer = NSPersistentContainer(name: "ABudget")

        if inMemory {
            persistentContainer.persistentStoreDescriptor.url = URL(fileURLWithPath: "/dev/null")
        }

        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                // In a production app, you should handle this error appropriately
                fatalError("Unable to load persistent stores: \(error.localizedDescription)")
            }
        }

        // Configure the view context
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Preview Support

    /// Creates a preview instance with in-memory storage
    static var preview: CoreDataStack {
        let stack = CoreDataStack(inMemory: true)

        // Add sample data for previews
        let context = stack.viewContext
        for i in 1...5 {
            let testEntity = TestEntity(context: context)
            testEntity.id = UUID()
            testEntity.name = "Test Item \(i)"
        }

        do {
            try context.save()
        } catch {
            print("Failed to save preview data: \(error.localizedDescription)")
        }

        return stack
    }

    // MARK: - Save Context

    /// Saves the view context if there are changes
    func saveContext() async throws {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            throw CoreDataError.saveFailed(error.localizedDescription)
        }
    }

    /// Saves the view context synchronously (use sparingly, prefer async version)
    func saveContextSync() throws {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            throw CoreDataError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Background Context

    /// Creates a new background context for performing operations off the main thread
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Performs a task on a background context
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
}

// MARK: - Errors

enum CoreDataError: Error, LocalizedError {
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Save failed: \(message)"
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        }
    }
}
