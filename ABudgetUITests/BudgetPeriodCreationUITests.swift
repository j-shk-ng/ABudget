//
//  BudgetPeriodCreationUITests.swift
//  ABudgetUITests
//
//  Created by Claude on 2025-10-21.
//

import XCTest

final class BudgetPeriodCreationUITests: XCTestCase {

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

    func testBudgetTabShowsEmptyStateInitially() throws {
        // Tap Budget tab
        app.tabBars.buttons["Budget"].tap()

        // Verify empty state is shown
        XCTAssertTrue(app.staticTexts["No Budget Yet"].exists)
        XCTAssertTrue(app.staticTexts["Create your first budget to start tracking your finances and take control of your spending."].exists)
        XCTAssertTrue(app.buttons["Create Budget"].exists)
    }

    func testCreateBudgetButtonOpensCreationSheet() throws {
        // Tap Budget tab
        app.tabBars.buttons["Budget"].tap()

        // Tap Create Budget
        app.buttons["Create Budget"].tap()

        // Verify creation sheet appears
        XCTAssertTrue(app.navigationBars["New Budget Period"].exists)
        XCTAssertTrue(app.staticTexts["Choose Your Budget Method"].exists)
    }

    // MARK: - Step 1: Methodology Selection Tests

    func testMethodologySelectionStep() throws {
        navigateToBudgetCreation()

        // Verify we're on methodology step
        XCTAssertTrue(app.staticTexts["Choose Your Budget Method"].exists)
        XCTAssertTrue(app.staticTexts["Step 1 of 4"].exists)

        // Verify all three methodologies are shown
        XCTAssertTrue(app.staticTexts["Zero-Based Budget"].exists)
        XCTAssertTrue(app.staticTexts["Envelope Budget"].exists)
        XCTAssertTrue(app.staticTexts["Percentage-Based Budget"].exists)

        // Verify Zero-Based is selected by default
        XCTAssertTrue(app.images["checkmark.circle.fill"].exists)

        // Tap Envelope methodology
        let envelopeCard = app.buttons.containing(.staticText, identifier: "Envelope Budget").element
        envelopeCard.tap()

        // Verify Next button exists
        XCTAssertTrue(app.buttons["Next"].exists)
    }

    func testNavigationToStep2FromMethodology() throws {
        navigateToBudgetCreation()

        // Select a methodology (default is Zero-Based)
        app.buttons["Next"].tap()

        // Verify we're on step 2
        XCTAssertTrue(app.staticTexts["Set Budget Period"].exists)
        XCTAssertTrue(app.staticTexts["Step 2 of 4"].exists)
    }

    // MARK: - Step 2: Date Range Selection Tests

    func testDateRangeSelectionStep() throws {
        navigateToBudgetCreation()
        app.buttons["Next"].tap()

        // Verify we're on date range step
        XCTAssertTrue(app.staticTexts["Set Budget Period"].exists)
        XCTAssertTrue(app.staticTexts["Quick Presets"].exists)

        // Verify preset buttons exist
        XCTAssertTrue(app.buttons["This Month"].exists)
        XCTAssertTrue(app.buttons["Next Month"].exists)
        XCTAssertTrue(app.buttons["This Quarter"].exists)

        // Verify date pickers exist
        XCTAssertTrue(app.staticTexts["Custom Dates"].exists)

        // Verify Back button exists
        XCTAssertTrue(app.buttons["Back"].exists)
    }

    func testDatePresetButtons() throws {
        navigateToBudgetCreation()
        app.buttons["Next"].tap()

        // Tap "This Month" preset
        app.buttons["This Month"].tap()

        // Verify duration is shown (duration should be visible)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Duration'")).element.exists)

        // Can navigate to next step
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Step 3 of 4"].exists)
    }

    func testBackNavigationFromDateRange() throws {
        navigateToBudgetCreation()
        app.buttons["Next"].tap()

        // Go back
        app.buttons["Back"].tap()

        // Verify we're back on methodology step
        XCTAssertTrue(app.staticTexts["Choose Your Budget Method"].exists)
        XCTAssertTrue(app.staticTexts["Step 1 of 4"].exists)
    }

    // MARK: - Step 3: Income Sources Tests

    func testIncomeSourcesEmptyState() throws {
        navigateToIncomeSourcesStep()

        // Verify empty state
        XCTAssertTrue(app.staticTexts["No Income Sources Yet"].exists)
        XCTAssertTrue(app.staticTexts["Add your first income source to get started with your budget."].exists)
        XCTAssertTrue(app.buttons["Add Income Source"].exists)
    }

    func testAddingSingleIncomeSource() throws {
        navigateToIncomeSourcesStep()

        // Add income source
        app.buttons["Add Income Source"].tap()

        // Enter income source details
        let nameField = app.textFields["Source Name (e.g., Salary)"]
        nameField.tap()
        nameField.typeText("Salary")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("5000")

        // Verify total income is shown
        XCTAssertTrue(app.staticTexts["Total Income"].exists)

        // Verify can proceed to next step
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Step 4 of 4"].exists)
    }

    func testAddingMultipleIncomeSources() throws {
        navigateToIncomeSourcesStep()

        // Add first income source
        app.buttons["Add Income Source"].tap()

        let nameFields = app.textFields.matching(identifier: "Source Name (e.g., Salary)")
        nameFields.element(boundBy: 0).tap()
        nameFields.element(boundBy: 0).typeText("Salary")

        let amountFields = app.textFields.matching(identifier: "Amount")
        amountFields.element(boundBy: 0).tap()
        amountFields.element(boundBy: 0).typeText("5000")

        // Add second income source
        app.buttons["Add Another Income Source"].tap()

        nameFields.element(boundBy: 1).tap()
        nameFields.element(boundBy: 1).typeText("Freelance")

        amountFields.element(boundBy: 1).tap()
        amountFields.element(boundBy: 1).typeText("1500")

        // Verify both sources are present
        XCTAssertTrue(app.staticTexts["Salary"].exists)
        XCTAssertTrue(app.staticTexts["Freelance"].exists)
    }

    func testRemovingIncomeSource() throws {
        navigateToIncomeSourcesStep()

        // Add income source
        app.buttons["Add Income Source"].tap()

        // Remove it
        app.buttons["trash"].tap()

        // Verify empty state is shown again
        XCTAssertTrue(app.staticTexts["No Income Sources Yet"].exists)
    }

    func testValidationErrorForEmptyIncomeSources() throws {
        navigateToIncomeSourcesStep()

        // Try to proceed without adding income sources
        app.buttons["Next"].tap()

        // Verify we're still on step 3 (validation prevents navigation)
        XCTAssertTrue(app.staticTexts["Step 3 of 4"].exists)
        XCTAssertTrue(app.staticTexts["Add Income Sources"].exists)
    }

    // MARK: - Step 4: Category Allocations Tests

    func testCategoryAllocationsStep() throws {
        navigateToAllocationsStep()

        // Verify we're on allocations step
        XCTAssertTrue(app.staticTexts["Allocate Your Budget"].exists)
        XCTAssertTrue(app.staticTexts["Step 4 of 4"].exists)

        // Verify budget summary is shown
        XCTAssertTrue(app.staticTexts["Budget Progress"].exists)
        XCTAssertTrue(app.staticTexts["Total Income"].exists)
        XCTAssertTrue(app.staticTexts["Allocated"].exists)
        XCTAssertTrue(app.staticTexts["Remaining"].exists)
    }

    func testAllocationsStepWithNoCategories() throws {
        navigateToAllocationsStep()

        // If no categories exist, empty state should be shown
        if app.staticTexts["No Categories Yet"].exists {
            XCTAssertTrue(app.staticTexts["Create categories in Settings first, then return to allocate your budget."].exists)
            XCTAssertTrue(app.buttons["Go to Settings"].exists)
        }
    }

    func testCreateBudgetButton() throws {
        navigateToAllocationsStep()

        // Verify Create Budget button exists on final step
        XCTAssertTrue(app.buttons["Create Budget"].exists)
    }

    // MARK: - Cancel Flow Tests

    func testCancelButtonExistsOnAllSteps() throws {
        navigateToBudgetCreation()

        // Step 1
        XCTAssertTrue(app.buttons["Cancel"].exists)

        // Step 2
        app.buttons["Next"].tap()
        XCTAssertTrue(app.buttons["Cancel"].exists)

        // Step 3
        app.buttons["Next"].tap()
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }

    func testCancelButtonDismissesSheet() throws {
        navigateToBudgetCreation()

        app.buttons["Cancel"].tap()

        // Verify we're back to empty state
        XCTAssertTrue(app.staticTexts["No Budget Yet"].exists)
        XCTAssertFalse(app.navigationBars["New Budget Period"].exists)
    }

    // MARK: - Complete Flow Tests

    func testCompleteCreationFlow() throws {
        navigateToBudgetCreation()

        // Step 1: Select methodology
        XCTAssertTrue(app.staticTexts["Step 1 of 4"].exists)
        app.buttons["Next"].tap()

        // Step 2: Set date range
        XCTAssertTrue(app.staticTexts["Step 2 of 4"].exists)
        app.buttons["This Month"].tap()
        app.buttons["Next"].tap()

        // Step 3: Add income
        XCTAssertTrue(app.staticTexts["Step 3 of 4"].exists)
        app.buttons["Add Income Source"].tap()

        let nameField = app.textFields["Source Name (e.g., Salary)"]
        nameField.tap()
        nameField.typeText("Test Salary")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("5000")

        app.buttons["Next"].tap()

        // Step 4: Allocations (can skip)
        XCTAssertTrue(app.staticTexts["Step 4 of 4"].exists)
        XCTAssertTrue(app.buttons["Create Budget"].exists)
    }

    // MARK: - Helper Methods

    private func navigateToBudgetCreation() {
        app.tabBars.buttons["Budget"].tap()
        app.buttons["Create Budget"].tap()
    }

    private func navigateToIncomeSourcesStep() {
        navigateToBudgetCreation()
        app.buttons["Next"].tap() // Past methodology
        app.buttons["Next"].tap() // Past date range
    }

    private func navigateToAllocationsStep() {
        navigateToIncomeSourcesStep()

        // Add a dummy income source
        app.buttons["Add Income Source"].tap()

        let nameField = app.textFields["Source Name (e.g., Salary)"]
        nameField.tap()
        nameField.typeText("Test Income")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("5000")

        app.buttons["Next"].tap() // To allocations
    }
}
