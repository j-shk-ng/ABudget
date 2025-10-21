//
//  TransactionRepository.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Protocol defining the interface for Transaction data operations
protocol TransactionRepository {
    /// Fetches all transactions
    /// - Returns: An array of all transactions sorted by date (newest first)
    /// - Throws: AppError if the fetch fails
    func fetchAll() async throws -> [TransactionDTO]

    /// Fetches a transaction by its ID
    /// - Parameter id: The UUID of the transaction
    /// - Returns: The transaction if found, nil otherwise
    /// - Throws: AppError if the fetch fails
    func fetchById(_ id: UUID) async throws -> TransactionDTO?

    /// Fetches transactions within a date range
    /// - Parameters:
    ///   - startDate: The start of the date range
    ///   - endDate: The end of the date range
    /// - Returns: An array of transactions within the date range
    /// - Throws: AppError if the fetch fails
    func fetchTransactions(from startDate: Date, to endDate: Date) async throws -> [TransactionDTO]

    /// Fetches transactions for a specific category
    /// - Parameter categoryId: The UUID of the category
    /// - Returns: An array of transactions in the category
    /// - Throws: AppError if the fetch fails
    func fetchTransactions(forCategoryId categoryId: UUID) async throws -> [TransactionDTO]

    /// Fetches transactions for a specific budget period
    /// - Parameter periodId: The UUID of the budget period
    /// - Returns: An array of transactions in the budget period
    /// - Throws: AppError if the fetch fails
    func fetchTransactions(forBudgetPeriodId periodId: UUID) async throws -> [TransactionDTO]

    /// Fetches transactions for a specific bucket type
    /// - Parameter bucket: The bucket type to filter by
    /// - Returns: An array of transactions in the bucket
    /// - Throws: AppError if the fetch fails
    func fetchTransactions(forBucket bucket: BucketType) async throws -> [TransactionDTO]

    /// Fetches transactions for a specific merchant
    /// - Parameter merchant: The merchant name to filter by
    /// - Returns: An array of transactions for the merchant
    /// - Throws: AppError if the fetch fails
    func fetchTransactions(forMerchant merchant: String) async throws -> [TransactionDTO]

    /// Creates a new transaction
    /// - Parameter transaction: The transaction data to create
    /// - Returns: The created transaction with updated metadata
    /// - Throws: AppError if the creation fails
    func create(_ transaction: TransactionDTO) async throws -> TransactionDTO

    /// Updates an existing transaction
    /// - Parameter transaction: The transaction data with updates
    /// - Returns: The updated transaction
    /// - Throws: AppError if the update fails or transaction not found
    func update(_ transaction: TransactionDTO) async throws -> TransactionDTO

    /// Deletes a transaction by its ID
    /// - Parameter id: The UUID of the transaction to delete
    /// - Throws: AppError if the deletion fails or transaction not found
    func delete(_ id: UUID) async throws

    /// Deletes multiple transactions
    /// - Parameter ids: Array of transaction IDs to delete
    /// - Throws: AppError if the deletion fails
    func deleteMultiple(_ ids: [UUID]) async throws
}

/// Core Data implementation of TransactionRepository
@MainActor
final class CoreDataTransactionRepository: TransactionRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    func fetchAll() async throws -> [TransactionDTO] {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { TransactionDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchById(_ id: UUID) async throws -> TransactionDTO? {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.first.map { TransactionDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchTransactions(from startDate: Date, to endDate: Date) async throws -> [TransactionDTO] {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { TransactionDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchTransactions(forCategoryId categoryId: UUID) async throws -> [TransactionDTO] {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "category.id == %@ OR subCategory.id == %@",
            categoryId as CVarArg,
            categoryId as CVarArg
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { TransactionDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchTransactions(forBudgetPeriodId periodId: UUID) async throws -> [TransactionDTO] {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "budgetPeriod.id == %@", periodId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { TransactionDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchTransactions(forBucket bucket: BucketType) async throws -> [TransactionDTO] {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "bucket == %@", bucket.rawValue)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { TransactionDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func fetchTransactions(forMerchant merchant: String) async throws -> [TransactionDTO] {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "merchant == %@", merchant)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { TransactionDTO.from(entity: $0) }
        } catch {
            throw AppError.fetchFailed(error)
        }
    }

    func create(_ transaction: TransactionDTO) async throws -> TransactionDTO {
        let entity = transaction.toEntity(in: context)

        // Auto-assign to budget period if not already assigned
        if transaction.budgetPeriodId == nil {
            if let activePeriod = try await findBudgetPeriod(containing: transaction.date) {
                entity.budgetPeriod = activePeriod
            }
        }

        do {
            try await saveContext()
            return TransactionDTO.from(entity: entity)
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func update(_ transaction: TransactionDTO) async throws -> TransactionDTO {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw AppError.entityNotFound
            }

            transaction.updateEntity(entity, in: context)
            try await saveContext()
            return TransactionDTO.from(entity: entity)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.saveFailed(error)
        }
    }

    func delete(_ id: UUID) async throws {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
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

    func deleteMultiple(_ ids: [UUID]) async throws {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)

        do {
            let entities = try context.fetch(fetchRequest)
            entities.forEach { context.delete($0) }
            try await saveContext()
        } catch {
            throw AppError.deleteFailed(error)
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

    private func findBudgetPeriod(containing date: Date) async throws -> BudgetPeriod? {
        let fetchRequest: NSFetchRequest<BudgetPeriod> = BudgetPeriod.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "startDate <= %@ AND endDate >= %@",
            date as NSDate,
            date as NSDate
        )
        fetchRequest.fetchLimit = 1

        return try context.fetch(fetchRequest).first
    }
}
