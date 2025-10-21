# Implementation Prompts for Code-Generation LLM

## Prompt 1: Project Setup and Core Data Foundation

```text
Create a new SwiftUI application called "ABudget" targeting iOS 17+, iPadOS 17+, and macOS 14+. 

Set up the project with the following requirements:
1. Use SwiftUI lifecycle (not UIKit)
2. Create a tab-based navigation with four tabs: Budget, Transactions, Reports, and Settings (use SF Symbols: "calendar", "list.bullet.rectangle", "chart.pie", "gearshape")
3. Set up Core Data with a simple persistence controller
4. Create proper folder structure: App, Core/Data, Core/Domain, Features/Budget, Features/Transactions, Features/Reports, Features/Settings
5. Each tab should show a placeholder view with the tab name centered

For Core Data setup:
- Create CoreDataStack.swift with NSPersistentContainer (not CloudKit yet)
- Add a simple test entity called "TestEntity" with id (UUID) and name (String) attributes
- Include preview/in-memory container for SwiftUI previews
- Write a unit test that saves and fetches a TestEntity to verify Core Data works

Include proper error handling and use modern Swift concurrency (async/await) where appropriate.

Write tests for:
- Core Data stack initialization
- Saving a test entity
- Fetching test entities
- Preview container works in memory

Make sure the app launches successfully on all platforms with the tab bar visible.
```

## Prompt 2: Category Entity and Repository Pattern

```text
Building on the previous ABudget project setup, implement the Category system data layer:

1. Replace TestEntity with proper Category entity in Core Data model:
   - id: UUID
   - name: String
   - isDefault: Boolean
   - sortOrder: Int16
   - createdAt: Date
   - updatedAt: Date
   - Add self-referencing relationship for parent/children categories

2. Create CategoryRepository protocol and implementation:
   - Protocol methods: fetch all, fetch by ID, create, update, delete, fetch root categories
   - Use async/await pattern
   - Implement with Core Data using the existing CoreDataStack
   - Include proper error handling with custom AppError enum

3. Create business model (DTO) for Category:
   - CategoryDTO struct with all fields
   - Conversion methods between Core Data entity and DTO
   - Helper computed properties (hasSubcategories, etc.)

4. Implement comprehensive unit tests using in-memory Core Data:
   - Test all CRUD operations
   - Test fetching only root categories (parent == nil)
   - Test parent-child relationships
   - Test sorting by sortOrder
   - Mock repository for future ViewModel testing

5. Add default categories seeder:
   - Create DefaultCategorySeeder class
   - Seed categories: Housing, Transportation, Food, Personal
   - Each with 2-3 subcategories as defined in spec
   - Only seed if database is empty
   - Write tests for seeding logic

Ensure all tests pass and maintain separation between Core Data entities and business DTOs.
```

## Prompt 3: Category Management UI

```text
Building on the ABudget project with Category data layer, create the Category Management UI:

1. Create CategoryListViewModel:
   - @Published properties for categories array, loading state, error
   - Use the CategoryRepository from previous step
   - Methods: loadCategories, addCategory, updateCategory, deleteCategory
   - Implement expand/collapse state for subcategories
   - Handle loading states and errors appropriately

2. Create CategoryListView for the Settings tab:
   - Replace placeholder Settings view
   - Display hierarchical list of categories
   - Indented subcategories under parent categories
   - Chevron icon for expandable categories
   - Show/hide subcategories on tap

3. Add Category CRUD UI:
   - "+" button in navigation bar to add category
   - Sheet presentation for add/edit form
   - CategoryFormView with name field and optional parent picker
   - Swipe to delete with confirmation
   - Edit by tapping on category row

4. Implement proper state management:
   - Loading indicator while fetching
   - Empty state when no categories
   - Error alerts with retry option
   - Optimistic UI updates with rollback on error

5. Write UI tests:
   - Test adding a new category appears in list
   - Test deleting category with confirmation
   - Test expanding/collapsing parent categories
   - Test editing category name

Wire everything together so Settings tab shows working category management. Seed default categories on first launch. Ensure smooth animations for expand/collapse.
```

## Prompt 4: Transaction and Budget Period Entities

```text
Extend ABudget's Core Data model with Transaction and BudgetPeriod entities:

1. Create BudgetPeriod entity:
   - id: UUID
   - methodology: String (zeroBased/envelope/percentage) 
   - startDate: Date
   - endDate: Date
   - createdAt: Date
   - updatedAt: Date
   - Add IncomeSource entity with relationship to BudgetPeriod
   - IncomeSource: id, sourceName, amount, budgetPeriod relationship

2. Create Transaction entity:
   - id: UUID
   - date: Date
   - subTotal: Decimal (use NSDecimalNumber)
   - tax: Decimal? (optional)
   - merchant: String
   - bucket: String (needs/wants/savings)
   - transactionDescription: String?
   - createdAt: Date
   - updatedAt: Date
   - Relationships: category (optional), subCategory (optional), budgetPeriod (optional)

3. Create repositories:
   - BudgetPeriodRepository with CRUD operations
   - TransactionRepository with CRUD + filtering methods
   - Include methods to fetch transactions by date range, category, budget period

4. Create DTOs and enums:
   - BudgetPeriodDTO, TransactionDTO, IncomeSourceDTO
   - BudgetMethodology enum (zeroBased, envelope, percentage)
   - BucketType enum (needs, wants, savings)
   - Include computed properties (total for transaction, dateRange for budget period)

5. Write comprehensive tests:
   - Test all entity relationships work correctly
   - Test transaction assignment to budget period by date
   - Test fetching transactions with various filters
   - Test cascade delete rules
   - Verify decimal number handling for money amounts

Update CoreDataStack if needed. Ensure proper migration for existing installations. All relationships should be properly configured with delete rules.
```

## Prompt 5: Complete Data Model

```text
Complete ABudget's data model with remaining entities and relationships:

1. Create CategoryAllocation entity:
   - id: UUID
   - plannedAmount: Decimal
   - carryOverAmount: Decimal
   - createdAt/updatedAt: Date
   - Relationships: budgetPeriod (many-to-one), category (many-to-one)

2. Create UserSettings entity:
   - id: UUID
   - needsPercentage: Decimal
   - wantsPercentage: Decimal  
   - savingsPercentage: Decimal
   - lastViewedBudgetPeriodId: UUID?
   - updatedAt: Date
   - Singleton pattern (only one settings object)

3. Update relationships:
   - BudgetPeriod: add categoryAllocations (one-to-many)
   - BudgetPeriod: add transactions (one-to-many)
   - Transaction: verify it connects to budgetPeriod
   - Set proper delete rules (cascade, nullify, etc.)

4. Create remaining repositories:
   - CategoryAllocationRepository
   - UserSettingsRepository (with getOrCreate for singleton)

5. Create validation rules:
   - ValidationRules struct with static methods
   - validateTransaction: amount > 0, merchant required, category required
   - validateBudgetPeriod: end > start, has income
   - validatePercentages: sum equals 100, all non-negative
   - Custom ValidationError enum with descriptive messages

6. Write integration tests:
   - Create complete budget period with all relationships
   - Test deleting budget period cascades properly
   - Test transaction without category (orphaned transaction)
   - Test validation rules throw correct errors
   - Test UserSettings singleton behavior

Ensure Core Data model is complete and matches specification exactly. All money values use Decimal for precision.
```

## Prompt 6: Business Logic Layer

```text
Implement ABudget's business logic and calculations layer:

1. Create BudgetCalculator class:
   - calculateSpentAmount(for category, in period) -> Decimal
   - calculateRemainingAmount(planned, spent) -> Decimal
   - calculateCarryOver(from previousPeriod, for category) -> Decimal
   - calculateBudgetPeriodTotals(period) -> (income, planned, spent, remaining)

2. Create PercentageCalculator class:
   - calculateBucketSpending(bucket, period) -> Decimal
   - calculateActualPercentage(bucket, period) -> Decimal
   - compareToTarget(actual, target) -> PercentageComparison enum
   - validatePercentageAllocation(needs, wants, savings) -> Bool

3. Create TransactionAssigner class:
   - assignTransactionToBudgetPeriod(transaction, periods) -> BudgetPeriod?
   - handleUnassignedTransaction(transaction) -> handle orphaned state
   - reassignTransactionsOnPeriodChange(period)

4. Create BudgetPrefiller class:
   - prefillNewBudgetPeriod(from: previousPeriod) -> draft data
   - copyIncomes(from period) -> [IncomeSourceDraft]
   - copyAllocations(from period, with carryOver) -> [AllocationDraft]

5. Comprehensive test suite:
   - Test calculations with various scenarios (under/over budget)
   - Test percentage calculations with edge cases (zero income)
   - Test transaction assignment with overlapping periods
   - Test carry-over with positive and negative amounts
   - Test prefilling maintains data integrity
   - Mock data helpers for testing

Create a BusinessLogic folder to organize these classes. Each calculator should be stateless and testable. Achieve 95%+ test coverage on business logic.
```

## Prompt 7: Budget Period Creation Flow

```text
Implement the Budget Period creation UI flow in ABudget:

1. Create BudgetPeriodViewModel:
   - Manage creation flow state (methodology, dates, incomes, allocations)
   - loadExistingPeriods() for period list
   - createBudgetPeriod(draft) with validation
   - prefillFromPrevious() using BudgetPrefiller
   - Handle multi-step form state

2. Create BudgetListView (main Budget tab):
   - Replace placeholder with period selector dropdown
   - Show selected period summary (income, planned, spent)
   - "New Budget" button in toolbar
   - Empty state for first-time users

3. Create multi-step budget creation flow:
   - Step 1: BudgetMethodologyView - select Zero-Based/Envelope/Percentage
   - Step 2: BudgetDateRangeView - date pickers for start/end
   - Step 3: IncomeSourcesView - add/edit/remove income sources
   - Step 4: CategoryAllocationsView - set planned amounts per category
   - Navigation with Next/Back/Cancel buttons
   - Save at the end

4. Create supporting views:
   - IncomeSourceRow with inline editing
   - AllocationRow with currency input
   - CurrencyTextField for formatted decimal input
   - DateRangePicker component

5. Wire everything together:
   - Sheet presentation from BudgetListView
   - Persist to Core Data via repository
   - Update main view on successful creation
   - Show validation errors appropriately
   - Prefill from previous period if exists

Write UI tests for complete flow. Test validation at each step. Ensure amounts use proper decimal/currency formatting.
```

## Prompt 8: Transaction Management UI

```text
Build complete transaction management in ABudget:

1. Create TransactionViewModel:
   - @Published transactions array with filtering
   - Filter by: category, date range, budget period, bucket
   - Sort options: date, amount, merchant
   - CRUD operations via TransactionRepository
   - Auto-assign to budget period based on date

2. Create TransactionListView (Transactions tab):
   - Replace placeholder with transaction list
   - TransactionRow showing: merchant, amount, date, category, bucket
   - Color coding for bucket types
   - Swipe actions for delete
   - Pull to refresh
   - Search bar for merchant search

3. Create TransactionFormView:
   - Sheet presentation for add/edit
   - Fields: amount, tax, merchant, date, category, subcategory, bucket, description
   - Category picker with subcategory support
   - Bucket segmented control
   - Real-time total calculation (subtotal + tax)
   - Validation before save

4. Implement filtering UI:
   - Filter bar below search
   - Chips for active filters
   - Filter sheet with all options
   - Date range presets (this month, last month, custom)
   - Clear all filters button

5. Integration and testing:
   - Connect to budget period (auto-assign by date)
   - Update budget calculations when transactions change
   - Test transaction appears in correct budget period
   - Test filters work correctly
   - Test validation prevents invalid data

Include loading states, empty states, and error handling. Ensure smooth scrolling with large transaction lists.
```

## Prompt 9: Budget Overview and Allocations

```text
Complete the Budget tab with full allocation management in ABudget:

1. Enhance BudgetViewModel:
   - Load allocations for selected period
   - Calculate spent amounts per category
   - Track expanded/collapsed state for categories
   - Update allocation amounts
   - Calculate totals and remaining budget

2. Create BudgetOverviewView:
   - Summary cards: Total Income, Total Planned, Total Spent
   - Remaining budget indicator (green/red)
   - Period selector dropdown at top
   - Percentage methodology feedback if applicable

3. Create CategoryAllocationsList:
   - Hierarchical list of categories with allocations
   - CategoryAllocationRow showing:
     - Category name with expand chevron
     - Spent/Planned amounts
     - Progress bar
     - Remaining amount (color coded)
   - Indented subcategories when expanded
   - Tap to edit allocation amount

4. Create AllocationEditSheet:
   - Edit planned amount for category
   - Show current spent amount (read-only)
   - Show carry-over from previous period if any
   - Calculate and show impact on budget
   - Save/Cancel buttons

5. Add percentage methodology features:
   - If methodology is percentage, show bucket breakdown
   - BucketProgressView with three progress bars
   - Compare actual vs target percentages
   - Color coding for over/under target

Wire to existing data layer. Update calculations when transactions are added/edited. Test all calculations match business logic. Include proper loading and error states.
```

## Prompt 10: Basic Reports

```text
Implement reporting features in ABudget:

1. Create ReportsViewModel:
   - Generate spending data by category
   - Generate spending data by bucket  
   - Calculate income vs expenses trends
   - Filter by date range and budget period
   - Toggle between category/bucket view

2. Create ReportsView with tabs:
   - Two tabs: "Spending" and "Trends"
   - Use SwiftUI's native TabView

3. Create SpendingPieChartView:
   - Segmented control: Categories vs Buckets
   - Use Swift Charts for pie chart
   - Interactive legend below chart
   - Tap segment to see details
   - Empty state if no data

4. Create TrendLineChartView:
   - Income vs Expenses over time
   - Period selector: 3/6/12 months or custom
   - Use Swift Charts for line chart
   - Show data points with amounts
   - Summary statistics below

5. Add filtering controls:
   - Date range picker
   - Budget period filter
   - FilterControlsView reusable component
   - Apply filters to both charts

Test with various data scenarios. Ensure charts render properly with no data, single data point, and many data points. Charts should be responsive to device size.
```

## Prompt 11: Settings and Percentage Buckets

```text
Complete Settings tab features in ABudget:

1. Enhance UserSettingsViewModel:
   - Load/save percentage buckets
   - Validate percentages sum to 100
   - Track iCloud sync status
   - Export transactions to CSV

2. Create main SettingsView:
   - Section: Budgeting
     - Link to Percentage Buckets
     - Link to Categories (already exists)
   - Section: Data
     - Export Transactions button
     - iCloud Sync status indicator
   - Section: About
     - Version number

3. Create PercentageBucketsView:
   - Three sliders: Needs, Wants, Savings
   - Each slider 0-100 in steps of 5
   - Live total calculation
   - Error state if not 100%
   - Save button (disabled if invalid)
   - Visual feedback with colors

4. Implement CSV export:
   - Generate CSV from all transactions
   - Include all fields as in spec
   - Use ShareSheet to export
   - Show progress indicator for large exports
   - Handle export errors gracefully

5. Add iCloud sync status:
   - Check if iCloud is available
   - Show sync status (syncing/synced/error)
   - Display last sync time
   - Explain when using local storage only

Write tests for percentage validation, CSV generation, and settings persistence. Ensure UserSettings singleton pattern works correctly.
```

## Prompt 12: CloudKit Integration

```text
Add iCloud sync capability to ABudget using CloudKit:

1. Update Core Data stack:
   - Migrate from NSPersistentContainer to NSPersistentCloudKitContainer
   - Configure for automatic sync
   - Set up remote change notifications
   - Handle CloudKit availability
   - Fallback to local storage if unavailable

2. Update entitlements and capabilities:
   - Add iCloud capability
   - Configure CloudKit container
   - Add necessary entitlements
   - Set up development and production environments

3. Implement sync conflict resolution:
   - SyncConflictResolver class
   - Last-writer-wins strategy using updatedAt
   - Merge policy configuration
   - Handle remote change notifications
   - Refresh UI on remote changes

4. Add sync status monitoring:
   - SyncStatusMonitor observable object  
   - Track sync state (idle/syncing/error)
   - Monitor network connectivity
   - Expose status to UI
   - Handle sync errors gracefully

5. Update UI for sync:
   - Show sync indicator in Settings
   - Add pull-to-refresh with sync
   - Show conflict resolution alerts if needed
   - Test multi-device scenarios

Test with multiple devices/simulators. Verify data syncs correctly. Test offline mode and recovery. Handle all CloudKit error cases.
```

## Prompt 13: Performance Optimization and Polish

```text
Optimize ABudget for production:

1. Performance optimizations:
   - Implement lazy loading for transaction lists
   - Add pagination for large datasets  
   - Optimize Core Data fetch requests with proper indexes
   - Cache calculated values where appropriate
   - Profile and fix any memory leaks

2. UI/UX polish:
   - Add haptic feedback for actions
   - Smooth animations for all transitions
   - Implement shake-to-undo for deletions
   - Add keyboard shortcuts for Mac
   - Ensure all tap targets are 44x44 points minimum

3. Accessibility:
   - Full VoiceOver support with proper labels
   - Dynamic Type support throughout
   - Ensure proper color contrast ratios
   - Add accessibility hints and traits
   - Test with accessibility inspector

4. Error handling improvements:
   - User-friendly error messages
   - Retry mechanisms for network operations
   - Graceful degradation for missing features
   - Proper loading states everywhere
   - Offline mode indicators

5. Additional polish:
   - App icon and launch screen
   - Onboarding flow for first launch
   - Settings for app preferences
   - Proper iPad and Mac layouts
   - Widget for budget summary (bonus)

Run performance tests. Ensure 60fps scrolling with 1000+ transactions. App launch time under 2 seconds. No memory leaks.
```

## Prompt 14: Comprehensive Testing and Documentation

```text
Finalize ABudget with comprehensive testing and documentation:

1. Complete test coverage:
   - Achieve 90%+ coverage on business logic
   - 80%+ on ViewModels
   - Integration tests for critical paths
   - UI tests for main user flows
   - Performance test suite

2. End-to-end test scenarios:
   - First time user: onboarding through first budget
   - Create budget -> Add transactions -> View reports
   - Multi-device sync scenario
   - Data migration scenarios
   - Error recovery flows

3. Edge case testing:
   - Empty states everywhere
   - Maximum data limits
   - Decimal precision for money
   - Date boundary conditions  
   - Concurrent modifications

4. Documentation:
   - README with setup instructions
   - API documentation for public methods
   - Architecture decision records
   - Testing guide
   - Release notes template

5. Pre-release checklist:
   - SwiftLint compliance
   - No warning in Xcode
   - All TODOs addressed
   - Memory leak testing passed
   - Accessibility audit complete
   - Privacy manifest if needed

Create comprehensive test plan document. Run full regression suite. Ensure every feature from spec is implemented and tested.
```