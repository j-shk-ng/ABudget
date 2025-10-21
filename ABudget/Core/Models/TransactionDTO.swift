//
//  TransactionDTO.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreData

/// Business model (DTO) for Transaction
/// Represents a financial transaction with categorization and budget tracking
struct TransactionDTO: Identifiable, Equatable, Hashable {
    let id: UUID
    var date: Date
    var subTotal: Decimal
    var tax: Decimal?
    var merchant: String
    var bucket: BucketType
    var transactionDescription: String?
    let createdAt: Date
    var updatedAt: Date

    // Relationships
    var categoryId: UUID?
    var subCategoryId: UUID?
    var budgetPeriodId: UUID?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        subTotal: Decimal,
        tax: Decimal? = nil,
        merchant: String,
        bucket: BucketType,
        transactionDescription: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        categoryId: UUID? = nil,
        subCategoryId: UUID? = nil,
        budgetPeriodId: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.subTotal = subTotal
        self.tax = tax
        self.merchant = merchant
        self.bucket = bucket
        self.transactionDescription = transactionDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.categoryId = categoryId
        self.subCategoryId = subCategoryId
        self.budgetPeriodId = budgetPeriodId
    }

    // MARK: - Computed Properties

    /// The total amount of the transaction (subtotal + tax)
    var total: Decimal {
        subTotal + (tax ?? 0)
    }

    /// Formatted total as a currency string
    var totalFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: total as NSDecimalNumber) ?? "$0.00"
    }

    /// Formatted date as a short string
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Conversion from Core Data Entity

    /// Converts a Core Data Transaction entity to a TransactionDTO
    /// - Parameter entity: The Core Data Transaction entity
    /// - Returns: A TransactionDTO instance
    static func from(entity: Transaction) -> TransactionDTO {
        let bucket = BucketType(rawValue: entity.bucket ?? "needs") ?? .needs

        return TransactionDTO(
            id: entity.id ?? UUID(),
            date: entity.date ?? Date(),
            subTotal: entity.subTotal as Decimal? ?? 0,
            tax: entity.tax as Decimal?,
            merchant: entity.merchant ?? "",
            bucket: bucket,
            transactionDescription: entity.transactionDescription,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            categoryId: entity.category?.id,
            subCategoryId: entity.subCategory?.id,
            budgetPeriodId: entity.budgetPeriod?.id
        )
    }

    // MARK: - Conversion to Core Data Entity

    /// Updates an existing Core Data Transaction entity with values from this DTO
    /// - Parameters:
    ///   - entity: The Core Data Transaction entity to update
    ///   - context: The managed object context
    func updateEntity(_ entity: Transaction, in context: NSManagedObjectContext) {
        entity.id = self.id
        entity.date = self.date
        entity.subTotal = NSDecimalNumber(decimal: self.subTotal)
        entity.tax = self.tax.map { NSDecimalNumber(decimal: $0) }
        entity.merchant = self.merchant
        entity.bucket = self.bucket.rawValue
        entity.transactionDescription = self.transactionDescription
        entity.createdAt = self.createdAt
        entity.updatedAt = Date() // Always update the timestamp

        // Handle category relationship
        if let categoryId = self.categoryId {
            let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
            fetchRequest.fetchLimit = 1

            if let category = try? context.fetch(fetchRequest).first {
                entity.category = category
            }
        } else {
            entity.category = nil
        }

        // Handle subcategory relationship
        if let subCategoryId = self.subCategoryId {
            let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", subCategoryId as CVarArg)
            fetchRequest.fetchLimit = 1

            if let subCategory = try? context.fetch(fetchRequest).first {
                entity.subCategory = subCategory
            }
        } else {
            entity.subCategory = nil
        }

        // Handle budget period relationship
        if let budgetPeriodId = self.budgetPeriodId {
            let fetchRequest: NSFetchRequest<BudgetPeriod> = BudgetPeriod.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", budgetPeriodId as CVarArg)
            fetchRequest.fetchLimit = 1

            if let budgetPeriod = try? context.fetch(fetchRequest).first {
                entity.budgetPeriod = budgetPeriod
            }
        } else {
            entity.budgetPeriod = nil
        }
    }

    /// Creates a new Core Data Transaction entity from this DTO
    /// - Parameter context: The managed object context to create the entity in
    /// - Returns: A new Transaction entity
    func toEntity(in context: NSManagedObjectContext) -> Transaction {
        let entity = Transaction(context: context)
        updateEntity(entity, in: context)
        return entity
    }
}

// MARK: - Array Extensions

extension Array where Element == TransactionDTO {
    /// Calculates the total amount of all transactions
    var totalAmount: Decimal {
        reduce(0) { $0 + $1.total }
    }

    /// Sorts transactions by date (newest first)
    func sortedByDate() -> [TransactionDTO] {
        sorted { $0.date > $1.date }
    }

    /// Groups transactions by merchant
    func groupedByMerchant() -> [String: [TransactionDTO]] {
        Dictionary(grouping: self) { $0.merchant }
    }

    /// Groups transactions by bucket type
    func groupedByBucket() -> [BucketType: [TransactionDTO]] {
        Dictionary(grouping: self) { $0.bucket }
    }

    /// Filters transactions by bucket type
    /// - Parameter bucket: The bucket type to filter by
    /// - Returns: Filtered transactions
    func filtered(by bucket: BucketType) -> [TransactionDTO] {
        filter { $0.bucket == bucket }
    }

    /// Filters transactions by date range
    /// - Parameter dateRange: The date range to filter by
    /// - Returns: Filtered transactions
    func filtered(by dateRange: ClosedRange<Date>) -> [TransactionDTO] {
        filter { dateRange.contains($0.date) }
    }

    /// Filters transactions by category
    /// - Parameter categoryId: The category ID to filter by
    /// - Returns: Filtered transactions
    func filtered(byCategoryId categoryId: UUID) -> [TransactionDTO] {
        filter { $0.categoryId == categoryId || $0.subCategoryId == categoryId }
    }
}
