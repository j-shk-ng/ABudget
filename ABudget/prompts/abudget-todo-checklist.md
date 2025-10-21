# ABudget Implementation Checklist

## 🏗️ Project Setup
- [ ] Create Xcode project (iOS 17+, iPadOS 17+, macOS 14+)
- [ ] Configure SwiftUI app lifecycle
- [ ] Set up folder structure
  - [ ] App/
  - [ ] Core/Data/
  - [ ] Core/Domain/
  - [ ] Core/Utils/
  - [ ] Features/Budget/
  - [ ] Features/Transactions/
  - [ ] Features/Reports/
  - [ ] Features/Settings/
  - [ ] Tests/
- [ ] Configure git repository
- [ ] Add .gitignore for Swift/Xcode
- [ ] Set up SwiftLint configuration
- [ ] Configure build schemes for Debug/Release
- [ ] Add app icons and launch screen

## 📱 Navigation Structure
- [ ] Implement TabView with four tabs
  - [ ] Budget tab with calendar icon
  - [ ] Transactions tab with list.bullet.rectangle icon
  - [ ] Reports tab with chart.pie icon
  - [ ] Settings tab with gearshape icon
- [ ] Create placeholder views for each tab
- [ ] Test navigation on all platforms (iPhone, iPad, Mac)

## 💾 Core Data Stack
- [ ] Create CoreDataStack.swift
  - [ ] NSPersistentContainer setup
  - [ ] In-memory container for previews
  - [ ] In-memory container for testing
  - [ ] Error handling for store loading
- [ ] Create ABudget.xcdatamodeld
- [ ] Write Core Data stack unit tests
  - [ ] Test initialization
  - [ ] Test save operation
  - [ ] Test fetch operation
  - [ ] Test preview container
- [ ] Add Core Data migration support

## 📊 Data Model Entities

### Category Entity
- [ ] Create Category entity
  - [ ] id: UUID attribute
  - [ ] name: String attribute
  - [ ] isDefault: Boolean attribute
  - [ ] sortOrder: Int16 attribute
  - [ ] createdAt: Date attribute
  - [ ] updatedAt: Date attribute
- [ ] Add self-referencing relationship (parent/children)
- [ ] Configure delete rules

### BudgetPeriod Entity
- [ ] Create BudgetPeriod entity
  - [ ] id: UUID attribute
  - [ ] methodology: String attribute
  - [ ] startDate: Date attribute
  - [ ] endDate: Date attribute
  - [ ] createdAt: Date attribute
  - [ ] updatedAt: Date attribute
- [ ] Create IncomeSource entity
  - [ ] id: UUID attribute
  - [ ] sourceName: String attribute
  - [ ] amount: Decimal attribute
  - [ ] Relationship to BudgetPeriod

### Transaction Entity
- [ ] Create Transaction entity
  - [ ] id: UUID attribute
  - [ ] date: Date attribute
  - [ ] subTotal: Decimal attribute
  - [ ] tax: Decimal (optional) attribute
  - [ ] merchant: String attribute
  - [ ] bucket: String attribute
  - [ ] transactionDescription: String (optional) attribute
  - [ ] createdAt: Date attribute
  - [ ] updatedAt: Date attribute
- [ ] Add relationships
  - [ ] category (optional)
  - [ ] subCategory (optional)
  - [ ] budgetPeriod (optional)

### CategoryAllocation Entity
- [ ] Create CategoryAllocation entity
  - [ ] id: UUID attribute
  - [ ] plannedAmount: Decimal attribute
  - [ ] carryOverAmount: Decimal attribute
  - [ ] createdAt: Date attribute
  - [ ] updatedAt: Date attribute
- [ ] Add relationships
  - [ ] budgetPeriod (many-to-one)
  - [ ] category (many-to-one)

### UserSettings Entity
- [ ] Create UserSettings entity
  - [ ] id: UUID attribute
  - [ ] needsPercentage: Decimal attribute
  - [ ] wantsPercentage: Decimal attribute
  - [ ] savingsPercentage: Decimal attribute
  - [ ] lastViewedBudgetPeriodId: UUID (optional) attribute
  - [ ] updatedAt: Date attribute
- [ ] Implement singleton pattern

## 🔄 Repository Layer

### Category Repository
- [ ] Create CategoryRepositoryProtocol
- [ ] Implement CategoryRepository
  - [ ] fetchAll() method
  - [ ] fetchById() method
  - [ ] fetchRootCategories() method
  - [ ] create() method
  - [ ] update() method
  - [ ] delete() method
- [ ] Write unit tests for all methods
- [ ] Create MockCategoryRepository for testing

### BudgetPeriod Repository
- [ ] Create BudgetPeriodRepositoryProtocol
- [ ] Implement BudgetPeriodRepository
  - [ ] fetchAll() method
  - [ ] fetchById() method
  - [ ] fetchActive() method
  - [ ] create() method
  - [ ] update() method
  - [ ] delete() method
- [ ] Write unit tests for all methods
- [ ] Create MockBudgetPeriodRepository

### Transaction Repository
- [ ] Create TransactionRepositoryProtocol
- [ ] Implement TransactionRepository
  - [ ] fetchAll() method
  - [ ] fetchByDateRange() method
  - [ ] fetchByCategory() method
  - [ ] fetchByBudgetPeriod() method
  - [ ] create() method
  - [ ] update() method
  - [ ] delete() method
- [ ] Write unit tests for all methods
- [ ] Create MockTransactionRepository

### Other Repositories
- [ ] Implement CategoryAllocationRepository
- [ ] Implement UserSettingsRepository (with singleton)
- [ ] Write tests for all repositories

## 🏢 Business Logic Layer

### DTOs and Models
- [ ] Create CategoryDTO
- [ ] Create BudgetPeriodDTO
- [ ] Create TransactionDTO
- [ ] Create IncomeSourceDTO
- [ ] Create CategoryAllocationDTO
- [ ] Create UserSettingsDTO
- [ ] Add conversion methods between entities and DTOs

### Enums
- [ ] Create BudgetMethodology enum (zeroBased, envelope, percentage)
- [ ] Create BucketType enum (needs, wants, savings)
- [ ] Create LoadingState enum
- [ ] Create PercentageComparison enum

### Calculators
- [ ] Implement BudgetCalculator
  - [ ] calculateSpentAmount() method
  - [ ] calculateRemainingAmount() method
  - [ ] calculateCarryOver() method
  - [ ] calculateBudgetPeriodTotals() method
  - [ ] Write comprehensive unit tests
- [ ] Implement PercentageCalculator
  - [ ] calculateBucketSpending() method
  - [ ] calculateActualPercentage() method
  - [ ] compareToTarget() method
  - [ ] validatePercentageAllocation() method
  - [ ] Write comprehensive unit tests
- [ ] Implement TransactionAssigner
  - [ ] assignTransactionToBudgetPeriod() method
  - [ ] handleUnassignedTransaction() method
  - [ ] reassignTransactionsOnPeriodChange() method
  - [ ] Write unit tests
- [ ] Implement BudgetPrefiller
  - [ ] prefillNewBudgetPeriod() method
  - [ ] copyIncomes() method
  - [ ] copyAllocations() method
  - [ ] Write unit tests

### Validation
- [ ] Create ValidationRules struct
  - [ ] validateTransaction() method
  - [ ] validateBudgetPeriod() method
  - [ ] validatePercentages() method
- [ ] Create ValidationError enum
- [ ] Write validation tests

### Error Handling
- [ ] Create AppError enum
  - [ ] Data errors (corruption, fetch, save, delete)
  - [ ] Validation errors
  - [ ] Sync errors
  - [ ] Export errors
- [ ] Implement error descriptions
- [ ] Implement recovery suggestions

## 🖥️ ViewModels

### Category ViewModels
- [ ] Create CategoryListViewModel
  - [ ] Loading state management
  - [ ] CRUD operations
  - [ ] Expand/collapse state
  - [ ] Error handling
- [ ] Create CategoryFormViewModel
- [ ] Write ViewModel tests

### Budget ViewModels
- [ ] Create BudgetViewModel
  - [ ] Period selection
  - [ ] Allocation management
  - [ ] Calculate totals
  - [ ] Expand/collapse categories
- [ ] Create BudgetPeriodViewModel
  - [ ] Creation flow state
  - [ ] Validation
  - [ ] Prefill logic
- [ ] Write ViewModel tests

### Transaction ViewModels
- [ ] Create TransactionViewModel
  - [ ] Filtering logic
  - [ ] Sorting logic
  - [ ] CRUD operations
- [ ] Create TransactionFormViewModel
  - [ ] Form validation
  - [ ] Auto-assignment logic
- [ ] Write ViewModel tests

### Other ViewModels
- [ ] Create ReportsViewModel
- [ ] Create UserSettingsViewModel
- [ ] Create PercentageBucketsViewModel

## 🎨 UI Implementation

### Settings Tab
- [ ] Create SettingsView
  - [ ] Budgeting section
  - [ ] Data section
  - [ ] About section
- [ ] Create CategoryListView
  - [ ] Hierarchical display
  - [ ] Expand/collapse animation
  - [ ] Add/Edit/Delete functionality
- [ ] Create CategoryFormView
  - [ ] Name field
  - [ ] Parent picker
  - [ ] Validation
- [ ] Create PercentageBucketsView
  - [ ] Three sliders (Needs/Wants/Savings)
  - [ ] Total validation
  - [ ] Save functionality

### Budget Tab
- [ ] Create BudgetListView
  - [ ] Period selector dropdown
  - [ ] Summary cards
  - [ ] Empty state
- [ ] Create BudgetOverviewView
  - [ ] Income/Planned/Spent cards
  - [ ] Remaining budget indicator
- [ ] Create CategoryAllocationsList
  - [ ] CategoryAllocationRow component
  - [ ] Progress bars
  - [ ] Expand/collapse
- [ ] Create budget creation flow
  - [ ] BudgetMethodologyView
  - [ ] BudgetDateRangeView
  - [ ] IncomeSourcesView
  - [ ] CategoryAllocationsView
- [ ] Create AllocationEditSheet

### Transactions Tab
- [ ] Create TransactionListView
  - [ ] Transaction rows
  - [ ] Search bar
  - [ ] Filter controls
  - [ ] Sort options
- [ ] Create TransactionRow component
  - [ ] Merchant, amount, date display
  - [ ] Category/bucket badges
  - [ ] Swipe actions
- [ ] Create TransactionFormView
  - [ ] Amount/tax fields
  - [ ] Merchant field
  - [ ] Category picker
  - [ ] Bucket selector
  - [ ] Date picker
  - [ ] Description field
- [ ] Create filtering UI
  - [ ] Filter chips
  - [ ] Filter sheet
  - [ ] Date range presets

### Reports Tab
- [ ] Create ReportsView with tabs
- [ ] Create SpendingPieChartView
  - [ ] Categories/Buckets toggle
  - [ ] Interactive legend
  - [ ] Empty state
- [ ] Create TrendLineChartView
  - [ ] Income vs Expenses
  - [ ] Period selector
  - [ ] Summary statistics
- [ ] Create FilterControlsView (reusable)

### Reusable Components
- [ ] Create CurrencyTextField
- [ ] Create DateRangePicker
- [ ] Create LoadingView
- [ ] Create ErrorView
- [ ] Create EmptyStateView

## 🎨 Design System
- [ ] Define color scheme
  - [ ] Semantic colors
  - [ ] Status colors
  - [ ] Bucket colors
- [ ] Define typography
- [ ] Define spacing constants
- [ ] Define corner radius constants
- [ ] Support Dark Mode
- [ ] Support Dynamic Type

## ✨ Features

### Default Data
- [ ] Create DefaultCategorySeeder
  - [ ] Housing category with subcategories
  - [ ] Transportation category with subcategories
  - [ ] Food category with subcategories
  - [ ] Personal category with subcategories
- [ ] Seed on first launch only

### CSV Export
- [ ] Implement CSV generator
- [ ] Include all transaction fields
- [ ] Format dates and amounts properly
- [ ] ShareSheet integration
- [ ] Progress indicator for large exports

### iCloud Sync
- [ ] Migrate to NSPersistentCloudKitContainer
- [ ] Configure CloudKit entitlements
- [ ] Handle CloudKit availability
- [ ] Implement conflict resolution
- [ ] Add sync status monitoring
- [ ] Update UI for sync status
- [ ] Test multi-device scenarios

## 🧪 Testing

### Unit Tests
- [ ] Core Data stack tests
- [ ] Repository tests (all CRUD operations)
- [ ] Business logic tests (95%+ coverage)
  - [ ] Calculator tests
  - [ ] Validation tests
  - [ ] Assignment tests
  - [ ] Prefiller tests
- [ ] ViewModel tests (80%+ coverage)
- [ ] DTO conversion tests
- [ ] Error handling tests

### Integration Tests
- [ ] Repository + Core Data tests
- [ ] ViewModel + Repository tests
- [ ] Complete budget period creation
- [ ] Transaction assignment tests
- [ ] Category deletion cascade tests

### UI Tests
- [ ] First launch experience
- [ ] Create budget flow
- [ ] Add transaction flow
- [ ] Category management
- [ ] Report generation
- [ ] Settings changes

### Performance Tests
- [ ] App launch time (< 2 seconds)
- [ ] Scrolling 1000+ transactions (60fps)
- [ ] Budget screen load (< 500ms)
- [ ] Report generation (< 1 second)

### Edge Case Tests
- [ ] Empty states
- [ ] Maximum data limits
- [ ] Decimal precision
- [ ] Date boundaries
- [ ] Concurrent modifications
- [ ] Offline mode
- [ ] iCloud unavailable

## 🎯 Performance Optimization
- [ ] Implement lazy loading for lists
- [ ] Add pagination for large datasets
- [ ] Optimize Core Data fetch requests
- [ ] Add proper indexes
- [ ] Cache calculated values
- [ ] Profile with Instruments
- [ ] Fix memory leaks
- [ ] Optimize image assets

## ♿ Accessibility
- [ ] VoiceOver support
  - [ ] Proper labels for all UI elements
  - [ ] Hints for complex interactions
  - [ ] Traits for buttons/controls
- [ ] Dynamic Type support
- [ ] Color contrast compliance (WCAG AA)
- [ ] Minimum tap targets (44x44)
- [ ] Keyboard navigation (Mac)
- [ ] Reduce motion support

## 📱 Platform Specific
- [ ] iPhone layout optimization
- [ ] iPad layout optimization
  - [ ] Split view support
  - [ ] Proper navigation
- [ ] Mac layout optimization
  - [ ] Keyboard shortcuts
  - [ ] Menu bar items
- [ ] Widget extension (bonus)
  - [ ] Budget summary widget
  - [ ] Quick transaction entry

## 🔧 Polish
- [ ] Haptic feedback for actions
- [ ] Smooth animations throughout
- [ ] Shake-to-undo for deletions
- [ ] Pull-to-refresh where appropriate
- [ ] Loading states everywhere needed
- [ ] Error states with retry options
- [ ] Empty states with helpful messages
- [ ] Onboarding flow for first users

## 📝 Documentation
- [ ] README.md with setup instructions
- [ ] Architecture documentation
- [ ] API documentation (DocC)
- [ ] Testing guide
- [ ] Contributing guidelines
- [ ] Code of conduct
- [ ] License file
- [ ] Privacy policy (if needed)
- [ ] Release notes template

## 🚀 Pre-Release
- [ ] SwiftLint compliance (zero warnings)
- [ ] Xcode zero warnings
- [ ] All TODOs addressed
- [ ] Memory leak testing passed
- [ ] Accessibility audit complete
- [ ] Privacy manifest (if required)
- [ ] App Store screenshots
- [ ] App Store description
- [ ] TestFlight beta testing
- [ ] Final QA pass

## 📊 Success Metrics
- [ ] All features from spec implemented
- [ ] 95%+ test coverage on business logic
- [ ] 80%+ overall test coverage
- [ ] Zero critical bugs
- [ ] App size under 50MB
- [ ] Crash-free rate > 99.9%
- [ ] All platforms tested
- [ ] Accessibility compliant

## 🔄 Post-Launch (Future)
- [ ] Monitor crash reports
- [ ] Gather user feedback
- [ ] Plan v2 features
  - [ ] CSV/Excel import
  - [ ] Bank syncing (Plaid)
  - [ ] Weekly/bi-weekly periods
  - [ ] Notifications
  - [ ] Multi-currency
  - [ ] Receipt photos
  - [ ] Shared budgets
  - [ ] Apple Watch app
  - [ ] Advanced reporting