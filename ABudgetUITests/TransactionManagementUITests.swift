//
//  TransactionManagementUITests.swift
//  ABudgetUITests
//
//  Created by Claude on 2025-10-21.
//

import XCTest

final class TransactionManagementUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Initial State Tests

    func testTransactionsTabShowsEmptyStateInitially() throws {
        navigateToTransactionsTab()

        // Verify empty state is shown
        XCTAssertTrue(app.staticTexts["No Transactions Yet"].exists)
        XCTAssertTrue(app.staticTexts["Start tracking your spending by adding your first transaction."].exists)
        XCTAssertTrue(app.buttons["Add Transaction"].exists)
    }

    func testAddTransactionButtonOpensForm() throws {
        navigateToTransactionsTab()

        // Tap Add Transaction from empty state
        app.buttons["Add Transaction"].tap()

        // Verify form appears
        XCTAssertTrue(app.navigationBars["Add Transaction"].exists)
    }

    // MARK: - Add Transaction Tests

    func testAddingBasicTransaction() throws {
        navigateToTransactionsTab()
        openAddTransactionForm()

        // Fill in required fields
        let subtotalField = app.textFields["Subtotal"]
        subtotalField.tap()
        subtotalField.typeText("50.00")

        let merchantField = app.textFields["Merchant"]
        merchantField.tap()
        merchantField.typeText("Whole Foods")

        // Save
        app.buttons["Add"].tap()

        // Verify form closes and transaction appears
        XCTAssertFalse(app.navigationBars["Add Transaction"].exists)
        XCTAssertTrue(app.staticTexts["Whole Foods"].exists)
    }

    func testAddingTransactionWithAllFields() throws {
        navigateToTransactionsTab()
        openAddTransactionForm()

        // Subtotal
        let subtotalField = app.textFields["Subtotal"]
        subtotalField.tap()
        subtotalField.typeText("45.99")

        // Tax
        let taxField = app.textFields["Tax (Optional)"]
        taxField.tap()
        taxField.typeText("4.14")

        // Verify total is calculated
        XCTAssertTrue(app.staticTexts["$50.13"].exists) // Total

        // Merchant
        let merchantField = app.textFields["Merchant"]
        merchantField.tap()
        merchantField.typeText("Target")

        // Description
        let descriptionField = app.textFields["Description (Optional)"]
        descriptionField.tap()
        descriptionField.typeText("Weekly shopping")

        // Select bucket
        let wantsBucket = app.buttons["Wants"]
        if wantsBucket.exists {
            wantsBucket.tap()
        }

        // Save
        app.buttons["Add"].tap()

        // Verify transaction appears
        XCTAssertTrue(app.staticTexts["Target"].exists)
    }

    func testAddButtonDisabledWhenInvalid() throws {
        navigateToTransactionsTab()
        openAddTransactionForm()

        // Add button should be disabled initially
        XCTAssertFalse(app.buttons["Add"].isEnabled)

        // Add merchant only
        let merchantField = app.textFields["Merchant"]
        merchantField.tap()
        merchantField.typeText("Store")

        // Still disabled (no amount)
        XCTAssertFalse(app.buttons["Add"].isEnabled)

        // Add subtotal
        let subtotalField = app.textFields["Subtotal"]
        subtotalField.tap()
        subtotalField.typeText("10")

        // Now should be enabled
        XCTAssertTrue(app.buttons["Add"].isEnabled)
    }

    func testCancelButtonClosesForm() throws {
        navigateToTransactionsTab()
        openAddTransactionForm()

        // Enter some data
        let merchantField = app.textFields["Merchant"]
        merchantField.tap()
        merchantField.typeText("Test")

        // Cancel
        app.buttons["Cancel"].tap()

        // Verify form closes
        XCTAssertFalse(app.navigationBars["Add Transaction"].exists)
    }

    // MARK: - Edit Transaction Tests

    func testEditingTransaction() throws {
        // First add a transaction
        addTestTransaction(merchant: "Original Merchant", amount: "25.00")

        // Tap on the transaction
        app.staticTexts["Original Merchant"].tap()

        // Verify edit form appears
        XCTAssertTrue(app.navigationBars["Edit Transaction"].exists)

        // Change merchant
        let merchantField = app.textFields["Merchant"]
        merchantField.tap()
        merchantField.clearAndTypeText("Updated Merchant")

        // Save
        app.buttons["Save"].tap()

        // Verify updated transaction appears
        XCTAssertTrue(app.staticTexts["Updated Merchant"].exists)
        XCTAssertFalse(app.staticTexts["Original Merchant"].exists)
    }

    func testSwipeToEdit() throws {
        addTestTransaction(merchant: "Swipe Test", amount: "15.00")

        // Swipe left on transaction
        let transactionRow = app.staticTexts["Swipe Test"]
        transactionRow.swipeLeft()

        // Tap Edit button
        app.buttons["Edit"].tap()

        // Verify edit form appears
        XCTAssertTrue(app.navigationBars["Edit Transaction"].exists)
    }

    // MARK: - Delete Transaction Tests

    func testSwipeToDelete() throws {
        addTestTransaction(merchant: "Delete Test", amount: "20.00")

        // Verify transaction exists
        XCTAssertTrue(app.staticTexts["Delete Test"].exists)

        // Swipe right to delete
        let transactionRow = app.staticTexts["Delete Test"]
        transactionRow.swipeRight()

        // Tap Delete button
        app.buttons["Delete"].tap()

        // Verify transaction is removed
        XCTAssertFalse(app.staticTexts["Delete Test"].exists)
    }

    // MARK: - Search Tests

    func testSearchingTransactions() throws {
        // Add multiple transactions
        addTestTransaction(merchant: "Walmart", amount: "50.00")
        addTestTransaction(merchant: "Target", amount: "30.00")
        addTestTransaction(merchant: "Whole Foods", amount: "75.00")

        // Tap search field
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("Walmart")

        // Verify filtered results
        XCTAssertTrue(app.staticTexts["Walmart"].exists)
        XCTAssertFalse(app.staticTexts["Target"].exists)
        XCTAssertFalse(app.staticTexts["Whole Foods"].exists)

        // Clear search
        if app.buttons["Clear text"].exists {
            app.buttons["Clear text"].tap()
        }

        // Verify all transactions shown again
        XCTAssertTrue(app.staticTexts["Walmart"].exists)
        XCTAssertTrue(app.staticTexts["Target"].exists)
        XCTAssertTrue(app.staticTexts["Whole Foods"].exists)
    }

    // MARK: - Filter Tests

    func testOpeningFilterSheet() throws {
        navigateToTransactionsTab()

        // Open menu
        app.buttons["ellipsis.circle"].tap()

        // Tap Filter
        app.buttons["Filter"].tap()

        // Verify filter sheet appears
        XCTAssertTrue(app.navigationBars["Filter Transactions"].exists)
    }

    func testFilterByBucket() throws {
        // Add transactions with different buckets
        addTestTransaction(merchant: "Grocery Store", amount: "50.00") // Needs (default)

        // Open filter sheet
        app.buttons["ellipsis.circle"].tap()
        app.buttons["Filter"].tap()

        // Select Needs bucket
        app.buttons["Needs"].tap()

        // Close filter
        app.buttons["Done"].tap()

        // Verify filter chip appears
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Needs'")).element.exists)
    }

    func testClearAllFilters() throws {
        navigateToTransactionsTab()

        // Open filter and set a filter
        app.buttons["ellipsis.circle"].tap()
        app.buttons["Filter"].tap()
        app.buttons["Needs"].tap()
        app.buttons["Done"].tap()

        // Verify filter chip exists
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'active'")).element.exists)

        // Tap Clear All
        app.buttons["Clear All"].tap()

        // Verify filter chip is gone
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'active'")).element.exists)
    }

    // MARK: - Sort Tests

    func testSortingTransactions() throws {
        navigateToTransactionsTab()

        // Open menu
        app.buttons["ellipsis.circle"].tap()

        // Verify Sort menu exists
        app.buttons["Sort"].tap()

        // Verify sort options
        XCTAssertTrue(app.buttons["Newest First"].exists)
        XCTAssertTrue(app.buttons["Oldest First"].exists)
        XCTAssertTrue(app.buttons["Highest Amount"].exists)
        XCTAssertTrue(app.buttons["Lowest Amount"].exists)
        XCTAssertTrue(app.buttons["Merchant A-Z"].exists)
        XCTAssertTrue(app.buttons["Merchant Z-A"].exists)
    }

    // MARK: - Pull to Refresh Tests

    func testPullToRefresh() throws {
        addTestTransaction(merchant: "Test Transaction", amount: "10.00")

        // Pull to refresh
        let transactionsList = app.descendants(matching: .any).matching(identifier: "Test Transaction").firstMatch
        transactionsList.swipeDown(velocity: .fast)

        // Verify transaction still appears (data reloaded)
        XCTAssertTrue(app.staticTexts["Test Transaction"].exists)
    }

    // MARK: - Empty State with Filters Tests

    func testEmptyStateWithActiveFilters() throws {
        addTestTransaction(merchant: "Store", amount: "10.00")

        // Apply search that matches nothing
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("NonexistentMerchant")

        // Verify filtered empty state
        XCTAssertTrue(app.staticTexts["No Transactions Found"].exists)
        XCTAssertTrue(app.staticTexts["Try adjusting your filters to see more results."].exists)
        XCTAssertTrue(app.buttons["Clear Filters"].exists)
    }

    // MARK: - Bucket Display Tests

    func testBucketColorCoding() throws {
        addTestTransaction(merchant: "Needs Test", amount: "10.00")

        // Verify bucket badge is displayed
        XCTAssertTrue(app.staticTexts["Needs"].exists)
    }

    // MARK: - Helper Methods

    private func navigateToTransactionsTab() {
        app.tabBars.buttons["Transactions"].tap()
    }

    private func openAddTransactionForm() {
        if app.buttons["Add Transaction"].exists {
            // From empty state
            app.buttons["Add Transaction"].tap()
        } else {
            // From menu
            app.buttons["ellipsis.circle"].tap()
            app.buttons["Add Transaction"].tap()
        }
    }

    private func addTestTransaction(merchant: String, amount: String) {
        navigateToTransactionsTab()
        openAddTransactionForm()

        let subtotalField = app.textFields["Subtotal"]
        subtotalField.tap()
        subtotalField.typeText(amount)

        let merchantField = app.textFields["Merchant"]
        merchantField.tap()
        merchantField.typeText(merchant)

        app.buttons["Add"].tap()

        // Wait for form to close
        _ = app.navigationBars["Add Transaction"].waitForNonExistence(timeout: 2)
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let stringValue = self.value as? String else {
            return
        }

        // Select all and delete
        self.tap()
        self.press(forDuration: 1.0)

        if app.menuItems["Select All"].exists {
            app.menuItems["Select All"].tap()
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)

        // Type new text
        self.typeText(text)
    }

    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
