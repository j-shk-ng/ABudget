//
//  AppError.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Application-wide error enum for consistent error handling
enum AppError: LocalizedError {
    // Core Data errors
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case entityNotFound
    case invalidData

    // Validation errors
    case invalidInput(String)
    case duplicateEntry

    // Unknown errors
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .entityNotFound:
            return "The requested item was not found"
        case .invalidData:
            return "Invalid data provided"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .duplicateEntry:
            return "An entry with the same information already exists"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}
