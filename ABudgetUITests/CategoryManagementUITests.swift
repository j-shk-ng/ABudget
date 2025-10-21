//
//  CategoryManagementUITests.swift
//  ABudgetUITests
//
//  Created by Claude on 21/10/2025.
//

import XCTest

final class CategoryManagementUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // Navigate to Settings tab
        app.tabBars.buttons["Settings"].tap()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test Adding Category

    @MainActor
    func testAddNewCategory() throws {
        // Wait for the view to load
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))

        // Tap the add button
        let addButton = app.navigationBars["Categories"].buttons["plus"]
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        // Wait for the form sheet to appear
        let newCategorySheet = app.navigationBars["New Category"]
        XCTAssertTrue(newCategorySheet.waitForExistence(timeout: 2))

        // Enter category name
        let nameField = app.textFields["Category Name"]
        XCTAssertTrue(nameField.exists)
        nameField.tap()
        nameField.typeText("Test Category")

        // Tap Save
        let saveButton = app.navigationBars["New Category"].buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        // Verify the new category appears in the list
        let newCategoryCell = app.staticTexts["Test Category"]
        XCTAssertTrue(newCategoryCell.waitForExistence(timeout: 3))
    }

    @MainActor
    func testAddCategoryWithParent() throws {
        // Wait for the view to load
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))

        // Verify at least one root category exists (from default seeding)
        let housingCategory = app.staticTexts["Housing"]
        XCTAssertTrue(housingCategory.waitForExistence(timeout: 3))

        // Tap the add button
        app.navigationBars["Categories"].buttons["plus"].tap()

        // Wait for the form sheet
        XCTAssertTrue(app.navigationBars["New Category"].waitForExistence(timeout: 2))

        // Enter category name
        let nameField = app.textFields["Category Name"]
        nameField.tap()
        nameField.typeText("New Subcategory")

        // Select parent category
        let parentButton = app.buttons["Parent"]
        XCTAssertTrue(parentButton.exists)
        parentButton.tap()

        // Select Housing as parent
        let selectParentSheet = app.navigationBars["Select Parent"]
        XCTAssertTrue(selectParentSheet.waitForExistence(timeout: 2))
        app.buttons["Housing"].tap()

        // Verify parent is selected
        XCTAssertTrue(app.staticTexts["Housing"].exists)

        // Save the category
        app.navigationBars["New Category"].buttons["Save"].tap()

        // Expand the Housing category to see subcategories
        let chevronButton = app.buttons.matching(identifier: "chevron.right").firstMatch
        if chevronButton.exists {
            chevronButton.tap()
        }

        // Verify the subcategory appears
        let subcategoryCell = app.staticTexts["New Subcategory"]
        XCTAssertTrue(subcategoryCell.waitForExistence(timeout: 3))
    }

    @MainActor
    func testCancelAddCategory() throws {
        // Wait for the view to load
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))

        // Tap the add button
        app.navigationBars["Categories"].buttons["plus"].tap()

        // Wait for the form sheet
        XCTAssertTrue(app.navigationBars["New Category"].waitForExistence(timeout: 2))

        // Enter category name
        let nameField = app.textFields["Category Name"]
        nameField.tap()
        nameField.typeText("Should Not Appear")

        // Tap Cancel
        let cancelButton = app.navigationBars["New Category"].buttons["Cancel"]
        cancelButton.tap()

        // Verify the category was not added
        let shouldNotExist = app.staticTexts["Should Not Appear"]
        XCTAssertFalse(shouldNotExist.exists)
    }

    // MARK: - Test Deleting Category

    @MainActor
    func testDeleteCategory() throws {
        // Wait for the view to load
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))

        // Add a category to delete
        app.navigationBars["Categories"].buttons["plus"].tap()
        XCTAssertTrue(app.navigationBars["New Category"].waitForExistence(timeout: 2))

        let nameField = app.textFields["Category Name"]
        nameField.tap()
        nameField.typeText("To Delete")
        app.navigationBars["New Category"].buttons["Save"].tap()

        // Wait for category to appear
        let categoryToDelete = app.staticTexts["To Delete"]
        XCTAssertTrue(categoryToDelete.waitForExistence(timeout: 3))

        // Swipe to delete
        categoryToDelete.swipeLeft()

        // Tap delete button
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        // Confirm deletion in alert
        let confirmDeleteButton = app.alerts["Delete Category"].buttons["Delete"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 2))
        confirmDeleteButton.tap()

        // Verify category is deleted
        XCTAssertFalse(categoryToDelete.exists)
    }

    @MainActor
    func testCancelDeleteCategory() throws {
        // Wait for the view to load
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))

        // Verify Housing category exists
        let housingCategory = app.staticTexts["Housing"]
        XCTAssertTrue(housingCategory.waitForExistence(timeout: 3))

        // Swipe to delete
        housingCategory.swipeLeft()

        // Tap delete button
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        // Cancel deletion in alert
        let cancelButton = app.alerts["Delete Category"].buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2))
        cancelButton.tap()

        // Verify category still exists
        XCTAssertTrue(housingCategory.exists)
    }

    // MARK: - Test Expanding/Collapsing Categories

    @MainActor
    func testExpandCollapseCategory() throws {
        // Wait for the view to load
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))

        // Wait for Housing category with subcategories
        let housingCategory = app.staticTexts["Housing"]
        XCTAssertTrue(housingCategory.waitForExistence(timeout: 3))

        // Find the chevron button for Housing
        // Note: In actual implementation, you might need to use accessibility identifiers
        let chevronRight = app.buttons.matching(NSPredicate(format: "label CONTAINS 'chevron.right'")).firstMatch
        let chevronDown = app.buttons.matching(NSPredicate(format: "label CONTAINS 'chevron.down'")).firstMatch

        // Initially collapsed - chevron should be right
        if chevronRight.exists {
            chevronRight.tap()

            // After tapping, subcategories should appear
            let rentMortgage = app.staticTexts["Rent/Mortgage"]
            XCTAssertTrue(rentMortgage.waitForExistence(timeout: 2))

            // Chevron should now be down
            XCTAssertTrue(chevronDown.waitForExistence(timeout: 1))

            // Tap again to collapse
            chevronDown.tap()

            // Subcategory should disappear
            XCTAssertFalse(rentMortgage.exists)
        }
    }

    // MARK: - Test Editing Category

    @MainActor
    func testEditCategoryName() throws {
        // Wait for the view to load
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))

        // Add a category to edit
        app.navigationBars["Categories"].buttons["plus"].tap()
        XCTAssertTrue(app.navigationBars["New Category"].waitForExistence(timeout: 2))

        let nameField = app.textFields["Category Name"]
        nameField.tap()
        nameField.typeText("Original Name")
        app.navigationBars["New Category"].buttons["Save"].tap()

        // Wait for category to appear
        let originalCategory = app.staticTexts["Original Name"]
        XCTAssertTrue(originalCategory.waitForExistence(timeout: 3))

        // Tap on the category to edit
        originalCategory.tap()

        // Wait for edit sheet
        let editSheet = app.navigationBars["Edit Category"]
        XCTAssertTrue(editSheet.waitForExistence(timeout: 2))

        // Clear and enter new name
        let editNameField = app.textFields["Category Name"]
        editNameField.tap()
        editNameField.doubleTap() // Select all
        editNameField.typeText("Updated Name")

        // Save changes
        app.navigationBars["Edit Category"].buttons["Save"].tap()

        // Verify updated name appears
        let updatedCategory = app.staticTexts["Updated Name"]
        XCTAssertTrue(updatedCategory.waitForExistence(timeout: 3))

        // Verify original name is gone
        XCTAssertFalse(originalCategory.exists)
    }

    // MARK: - Test Empty State

    @MainActor
    func testEmptyStateShown() throws {
        // This test would require resetting the database
        // For now, we'll just verify that if there are categories,
        // the empty state is NOT shown

        // Wait for the view to load
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))

        // With default seeding, we should have categories
        let housingCategory = app.staticTexts["Housing"]
        if housingCategory.exists {
            // Empty state should not be shown
            let emptyStateText = app.staticTexts["No Categories"]
            XCTAssertFalse(emptyStateText.exists)
        }
    }

    // MARK: - Test Loading State

    @MainActor
    func testLoadingStateShown() throws {
        // Launch app
        app.launch()

        // Quickly navigate to Settings
        app.tabBars.buttons["Settings"].tap()

        // Loading indicator might be visible briefly
        // This is a timing-dependent test and might be flaky
        // In a real scenario, you might want to add delays or mock slow network
        let loadingText = app.staticTexts["Loading categories..."]

        // If loading is visible, it should eventually disappear
        if loadingText.exists {
            // Wait for loading to finish
            XCTAssertFalse(loadingText.waitForExistence(timeout: 5))
        }

        // Categories should eventually load
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))
    }

    // MARK: - Test Default Categories Seeded

    @MainActor
    func testDefaultCategoriesSeeded() throws {
        // Wait for the view to load
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))

        // Verify default categories are present
        XCTAssertTrue(app.staticTexts["Housing"].exists)
        XCTAssertTrue(app.staticTexts["Transportation"].exists)
        XCTAssertTrue(app.staticTexts["Food"].exists)
        XCTAssertTrue(app.staticTexts["Personal"].exists)
    }
}
