
//
//  ReceiptReviewViewController.swift
//

import UIKit

class ReceiptReviewViewController: UIViewController {

    private enum ReceiptSaveConstants {
        static let fallbackCategoryName = "Others"
        static let fallbackCategoryColor = "#7D8597"
        static let fallbackCategoryIcon = "cube.box.fill"
    }

    private enum ItemEditorValidationError: LocalizedError {
        case message(String)

        var errorDescription: String? {
            switch self {
            case .message(let message):
                return message
            }
        }
    }

    private struct ItemEditorState {
        var name: String
        var quantityText: String
        var unitPriceText: String
        var totalPriceText: String

        init(item: ReceiptLineItem?) {
            self.name = item?.name ?? ""
            self.quantityText = Self.formattedValue(item?.quantity)
            self.unitPriceText = Self.formattedValue(item?.unitPrice)
            self.totalPriceText = Self.formattedValue(item?.totalPrice)
        }

        init(name: String,
             quantityText: String,
             unitPriceText: String,
             totalPriceText: String) {
            self.name = name
            self.quantityText = quantityText
            self.unitPriceText = unitPriceText
            self.totalPriceText = totalPriceText
        }

        private static func formattedValue(_ value: Double?) -> String {
            guard let value else { return "" }
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(format: "%.2f", value)
        }
    }


    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
  
    

    var scanData: ReceiptScanData = ReceiptScanData()
    var receiptImage: UIImage?
    var userCategories: [Category] = []   // pass User.categories here

    // lineItems is a mutable copy so user edits don't touch scanData directly
    private var lineItems: [ReceiptLineItem] = []

    // Tracks which category the user picked per line item index
    // key = lineItem index, value = Category
    private var assignedCategories: [Int: Category] = [:]

    //Arrange order of the xib cells in the collection view using enum sections for better readability
    private enum Section: Int, CaseIterable {
        case header = 0 // ReceiptHeaderCell
        case summary = 2 // ReceiptBillBreakdownCell
        case items  = 1 // ReceiptSectionHeaderView + ReceiptItemCell + ReceiptAddItemCell
        case captureImage  = 3   // ReceiptCaptureImageCell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        view.backgroundColor = AppColors.background
        configureNavigationBar()
        loadUserCategoriesIfNeeded()
        lineItems = scanData.lineItems
        seedAssignedCategoriesIfNeeded()
        setupSaveButton()
        setupCollectionView()
    }

    // MARK: - Setup

    private func setupSaveButton() {
        saveButton.backgroundColor    = AppColors.brand
        saveButton.setTitleColor(AppColors.brandText, for: .normal)
    }

    private func configureNavigationBar() {
        navigationItem.title = "Receipt Review"
    }

    private func setupCollectionView() {

        // Register all XIB cells
        collectionView.register(
            UINib(nibName: "ReceiptHeaderCell", bundle: nil),
            forCellWithReuseIdentifier: "ReceiptHeaderCell")
        
        collectionView.register(
            UINib(nibName: "ReceiptCaptureImageCell", bundle: nil),
            forCellWithReuseIdentifier: "ReceiptCaptureImageCell")
        
        collectionView.register(
            UINib(nibName: "ReceiptItemCell", bundle: nil),
            forCellWithReuseIdentifier: "ReceiptItemCell")

        collectionView.register(
            UINib(nibName: "ReceiptBillBreakdownCell", bundle: nil),
            forCellWithReuseIdentifier: ReceiptBillBreakdownCell.reuseID
        )


        collectionView.register(
            UINib(nibName: "ReceiptAddItemCell", bundle: nil),
            forCellWithReuseIdentifier: ReceiptAddItemCell.reuseID
        )

        // Register section header
        collectionView.register(
            UINib(nibName: "ReceiptSectionHeaderView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "ReceiptSectionHeaderViewCell")

        collectionView.dataSource      = self
        collectionView.delegate        = self
        collectionView.backgroundColor = AppColors.background
        collectionView.collectionViewLayout = makeLayout()
    }


    private func makeLayout() -> UICollectionViewLayout {

        UICollectionViewCompositionalLayout { sectionIndex, _ in
            guard let section = Section(rawValue: sectionIndex) else { return nil }

            switch section {

            case .header:
                // Self-sizing height, full width
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1),
                                      heightDimension: .estimated(160))
                )
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(widthDimension: .fractionalWidth(1),
                                      heightDimension: .estimated(160)),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 16, leading: 0,
                                              bottom: 8, trailing: 0)
                return section

            case .captureImage:
                // Fixed height for the photo
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1),
                                      heightDimension: .absolute(260))
                )
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(widthDimension: .fractionalWidth(1),
                                      heightDimension: .absolute(260)),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 0, leading: 16,
                                              bottom: 16, trailing: 16)
                return section

            case .summary:
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1),
                                      heightDimension: .estimated(220))
                )
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(widthDimension: .fractionalWidth(1),
                                      heightDimension: .estimated(220)),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 0, leading: 0,
                                              bottom: 8, trailing: 0)
                return section

            case .items:
                // Self-sizing item rows
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1),
                                      heightDimension: .estimated(112))
                )
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(widthDimension: .fractionalWidth(1),
                                      heightDimension: .estimated(112)),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 8, leading: 0,
                                              bottom: 8, trailing: 0)

                // Section header (Scanned Items + count pill)
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .absolute(50)
                )
                section.boundarySupplementaryItems = [
                    NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: headerSize,
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top
                    )
                ]
                return section
            }
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale    = Locale(identifier: "en_IN")
        return f.string(from: date)
    }

    private func formattedAmount(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "₹\(String(format: "%.2f", value))"
    }

    private func formattedQuantity(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    private func receiptTimestamp() -> Date? {
        guard let date = scanData.date else { return nil }
        guard let time = scanData.time?.trimmingCharacters(in: .whitespacesAndNewlines),
              !time.isEmpty else {
            return date
        }

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)

        let timeFormats = ["HH:mm:ss", "HH:mm"]
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = calendar.timeZone

        for format in timeFormats {
            timeFormatter.dateFormat = format
            if let parsedTime = timeFormatter.date(from: time) {
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: parsedTime)
                var combinedComponents = dateComponents
                combinedComponents.hour = timeComponents.hour
                combinedComponents.minute = timeComponents.minute
                combinedComponents.second = timeComponents.second

                if let combinedDate = calendar.date(from: combinedComponents) {
                    return combinedDate
                }
            }
        }

        return date
    }

    private func subtotal(for items: [ReceiptLineItem]) -> Double {
        items.reduce(0) { partialResult, item in
            if let quantity = item.quantity,
               quantity > 0,
               let unitPrice = item.unitPrice {
                return partialResult + (quantity * unitPrice)
            }

            return partialResult + (item.totalPrice ?? 0)
        }
    }

    private func displayedItemsTotal(for items: [ReceiptLineItem]) -> Double {
        items.reduce(0) { partialResult, item in
            if let totalPrice = item.totalPrice {
                return partialResult + totalPrice
            }

            if let quantity = item.quantity,
               quantity > 0,
               let unitPrice = item.unitPrice {
                return partialResult + (quantity * unitPrice)
            }

            return partialResult + (item.unitPrice ?? 0)
        }
    }

    private func originalSubtotal() -> Double {
        scanData.subtotal ?? subtotal(for: scanData.lineItems)
    }

    private func hasUserModifiedItems() -> Bool {
        guard lineItems.count == scanData.lineItems.count else { return true }

        return zip(lineItems, scanData.lineItems).contains { currentItem, originalItem in
            currentItem.name != originalItem.name
                || !approximatelyEqual(currentItem.quantity, originalItem.quantity)
                || !approximatelyEqual(currentItem.unitPrice, originalItem.unitPrice)
                || !approximatelyEqual(currentItem.totalPrice, originalItem.totalPrice)
        }
    }

    private func approximatelyEqual(_ lhs: Double?, _ rhs: Double?, tolerance: Double = 0.01) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return abs(left - right) < tolerance
        default:
            return false
        }
    }

    private func currentSubtotal() -> Double {
        if !hasUserModifiedItems(), let scannedSubtotal = scanData.subtotal {
            return scannedSubtotal
        }

        let activeItems = lineItems.isEmpty ? scanData.lineItems : lineItems
        return subtotal(for: activeItems)
    }

    private func parsedTaxLines() -> [ReceiptTaxLine] {
        let directTaxLines = scanData.taxLines.filter { $0.amount > 0 }
        if !directTaxLines.isEmpty {
            return directTaxLines
        }

        let fallbackTaxLines = [
            scanData.cgst.map { ReceiptTaxLine(name: "CGST", amount: $0) },
            scanData.sgst.map { ReceiptTaxLine(name: "SGST", amount: $0) },
            scanData.igst.map { ReceiptTaxLine(name: "IGST", amount: $0) }
        ].compactMap { $0 }

        if !fallbackTaxLines.isEmpty {
            return fallbackTaxLines
        }

        if let totalTax = scanData.totalTax, totalTax > 0 {
            return [ReceiptTaxLine(name: "Tax", amount: totalTax)]
        }

        return []
    }

    private func currentTaxTotal() -> Double {
        let taxLines = parsedTaxLines()
        if !taxLines.isEmpty {
            return taxLines.reduce(0) { $0 + $1.amount }
        }

        return max(scanData.totalTax ?? 0, 0)
    }

    private func receiptAdjustment() -> Double {
        let baselineSubtotal = originalSubtotal()
        let baselineTaxTotal = currentTaxTotal()
        let baselineGrandTotal = scanData.grandTotal ?? (baselineSubtotal + baselineTaxTotal)
        let adjustment = baselineGrandTotal - (baselineSubtotal + baselineTaxTotal)
        return abs(adjustment) >= 0.01 ? adjustment : 0
    }

    private func currentReceiptTotal() -> Double {
        currentSubtotal() + currentTaxTotal() + receiptAdjustment()
    }

    private func subtotalRowTitle() -> String {
        let activeItems = lineItems.isEmpty ? scanData.lineItems : lineItems
        let hasTaxBreakdown = !parsedTaxLines().isEmpty || (scanData.totalTax ?? 0) > 0
        let itemTotalsDiffer = abs(displayedItemsTotal(for: activeItems) - currentSubtotal()) >= 0.01

        if hasTaxBreakdown && itemTotalsDiffer {
            return "Subtotal (Before Tax)"
        }

        return "Subtotal"
    }

    private func breakdownRows() -> [ReceiptBreakdownRow] {
        var rows = [
            ReceiptBreakdownRow(title: subtotalRowTitle(),
                                value: formattedAmount(currentSubtotal()))
        ]

        let taxLines = parsedTaxLines()
        if !taxLines.isEmpty {
            rows.append(contentsOf: taxLines.map {
                ReceiptBreakdownRow(title: $0.name,
                                    value: formattedAmount($0.amount))
            })
        } else if let totalTax = scanData.totalTax, totalTax > 0 {
            rows.append(
                ReceiptBreakdownRow(title: "Tax",
                                    value: formattedAmount(totalTax))
            )
        }

        let adjustment = receiptAdjustment()
        if abs(adjustment) >= 0.01 {
            let title = adjustment >= 0 ? "Other Charges" : "Discount / Adjustment"
            rows.append(
                ReceiptBreakdownRow(title: title,
                                    value: formattedAmount(adjustment))
            )
        }

        rows.append(
            ReceiptBreakdownRow(title: "Grand Total",
                                value: formattedAmount(currentReceiptTotal()),
                                isEmphasized: true)
        )

        return rows
    }


    private func reloadReceiptContent() {
       
        collectionView.reloadSections(IndexSet([Section.header.rawValue,
                                               Section.summary.rawValue,
                                               Section.items.rawValue]))
    }

    /// Finds the first category whose name roughly matches the item name
    /// Falls back to the first category or nil
    private func defaultCategory(for item: ReceiptLineItem) -> Category? {
        let name = item.name.lowercased()
        return userCategories.first {
            name.contains($0.name.lowercased())
        } ?? userCategories.first
    }

    private func loadUserCategoriesIfNeeded() {
        guard userCategories.isEmpty else { return }

        let categories = DatabaseManager.shared.fetchCategories()
        let expenseCategories = categories.filter { $0.type == .expense }
        userCategories = expenseCategories.isEmpty ? categories : expenseCategories
    }

    private func seedAssignedCategoriesIfNeeded() {
        guard !userCategories.isEmpty else { return }

        for (index, item) in lineItems.enumerated() where assignedCategories[index] == nil {
            if let category = defaultCategory(for: item) {
                assignedCategories[index] = category
            }
        }
    }

    // MARK: - Actions

    @IBAction func backTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }

    @IBAction func saveTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Save Receipt",
            message: "Also add this receipt as one expense transaction?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Save with Transaction",
                                      style: .default) { [weak self] _ in
            self?.save(createTransactions: true)
        })
        alert.addAction(UIAlertAction(title: "Receipt Only",
                                      style: .default) { [weak self] _ in
            self?.save(createTransactions: false)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func save(createTransactions: Bool) {
        let db = DatabaseManager.shared
        let receiptDate = receiptTimestamp() ?? Date()
        let transactionTimestamp = Date()
        let merchantName = normalizedMerchantName()
        let receiptNote = buildReceiptNote()
        var transactionIds = Set<UUID>()

        if createTransactions {
            guard let categoryId = resolvedCombinedReceiptCategoryId() else { return }

            if let transactionId = db.insertExpenseTransaction(
                name: merchantName,
                amount: currentReceiptTotal(),
                timestamp: transactionTimestamp,
                categoryId: categoryId,
                status: true,
                expenseType: "receipt",
                source: .receipt,
                note: receiptNote
            ) {
                transactionIds.insert(transactionId)
            }

            guard !transactionIds.isEmpty else { return }
        }

        guard db.insertReceipt(
            merchantName: merchantName,
            totalAmount: currentReceiptTotal(),
            date: receiptDate,
            note: receiptNote,
            transactionIds: transactionIds
        ) != nil else { return }

        if createTransactions {
            db.resetMonthlyExpense()
            NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
        }

        navigateToHomeScreen()
    }

    private func normalizedMerchantName() -> String {
        let trimmedName = scanData.merchantName?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedName, !trimmedName.isEmpty {
            return trimmedName
        }

        return "Scanned Receipt"
    }

    private func buildReceiptNote() -> String {
        let itemCount = lineItems.count
        if itemCount > 0 {
            return "\(itemCount) item\(itemCount == 1 ? "" : "s") from scanned receipt"
        }
        return "Scanned receipt"
    }

    private func resolvedCombinedReceiptCategoryId() -> UUID? {
        let activeItems = lineItems.isEmpty ? scanData.lineItems : lineItems
        var totalsByCategoryId: [UUID: Double] = [:]

        for (index, item) in activeItems.enumerated() {
            let amount = item.totalPrice
                ?? ((item.quantity ?? 0) > 0 ? (item.quantity ?? 0) * (item.unitPrice ?? 0) : (item.unitPrice ?? 0))

            let category = assignedCategories[index] ?? defaultCategory(for: item)
            if let categoryId = category?.id {
                totalsByCategoryId[categoryId, default: 0] += amount
            }
        }

        if let dominantCategoryId = totalsByCategoryId.max(by: { $0.value < $1.value })?.key {
            return dominantCategoryId
        }

        if let firstExpenseCategory = userCategories.first(where: { $0.type == .expense }) {
            return firstExpenseCategory.id
        }

        return DatabaseManager.shared.ensureCategory(
            name: ReceiptSaveConstants.fallbackCategoryName,
            color: ReceiptSaveConstants.fallbackCategoryColor,
            icon: ReceiptSaveConstants.fallbackCategoryIcon,
            budget: 0,
            type: .expense
        )
    }

    private func navigateToHomeScreen() {
        let dismissController = highestPresentingController() ?? navigationController ?? self
        dismissController.dismiss(animated: true) {
            Self.selectHomeTab()
        }
    }

    private func highestPresentingController() -> UIViewController? {
        var controller: UIViewController? = navigationController ?? self
        while let presenter = controller?.presentingViewController {
            controller = presenter
        }
        return controller
    }

    private static func selectHomeTab() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            guard let rootController = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { continue }
            if let tabController = findCustomTabBarController(from: rootController) {
                tabController.selectedIndex = AppTab.home.rawValue
                return
            }
        }
    }

    private static func findCustomTabBarController(from controller: UIViewController?) -> CustomTabBarController? {
        guard let controller else { return nil }

        if let tabController = controller as? CustomTabBarController {
            return tabController
        }

        if let navigationController = controller as? UINavigationController {
            for child in navigationController.viewControllers {
                if let found = findCustomTabBarController(from: child) {
                    return found
                }
            }
        }

        if let tabBarController = controller as? UITabBarController {
            for child in tabBarController.viewControllers ?? [] {
                if let found = findCustomTabBarController(from: child) {
                    return found
                }
            }
        }

        for child in controller.children {
            if let found = findCustomTabBarController(from: child) {
                return found
            }
        }

        if let presented = controller.presentedViewController {
            return findCustomTabBarController(from: presented)
        }

        return nil
    }
}


extension ReceiptReviewViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .header:       return 1
        case .summary:      return 1
        case .captureImage: return 1
        case .items:        return lineItems.count + 1  // +1 for Add Item cell
        case .none:         return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        switch Section(rawValue: indexPath.section) {

       
        case .header:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "ReceiptHeaderCell",
                for: indexPath) as! ReceiptHeaderCell

            cell.configure(
                merchant:  scanData.merchantName,
                dateText:  formattedDate(receiptTimestamp()),
                totalText: formattedAmount(currentReceiptTotal())
            )
            return cell

        case .summary:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ReceiptBillBreakdownCell.reuseID,
                for: indexPath
            ) as! ReceiptBillBreakdownCell

            cell.configure(rows: breakdownRows())
            return cell

        // MARK: Capture Image
        // MARK: Capture Image
        case .captureImage:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "ReceiptCaptureImageCell",
                for: indexPath) as! ReceiptCaptureImageCell

            cell.configure(image: receiptImage)
            return cell

        // MARK: Items + Add
        case .items:
            // Last row = Add Item cell
            if indexPath.item == lineItems.count {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: ReceiptAddItemCell.reuseID,
                    for: indexPath) as! ReceiptAddItemCell

                cell.onTap = { [weak self] in
                    self?.presentItemEditor()
                }
                return cell
            }

            // Regular item row
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "ReceiptItemCell",
                for: indexPath) as! ReceiptItemCell

            let item     = lineItems[indexPath.item]
            let category = assignedCategories[indexPath.item]
                ?? defaultCategory(for: item)

            let unitPriceText: String? = {
                guard let qty = item.quantity, qty > 1,
                      let unit = item.unitPrice else { return nil }
                return "\(formattedQuantity(qty)) x ₹\(String(format: "%.2f", unit))"
            }()

            cell.configure(
                title:        item.name,
                price:        formattedAmount(item.totalPrice),
                unitPrice:    unitPriceText,
                categoryName: category?.name ?? "Other",
                categoryIcon: UIImage(systemName: category?.icon ?? "tag")
            )

            // Category pill tapped → show dropdown later
            cell.onCategoryTapped = {
                // TODO: present CategoryDropdownView here (next step)
                print("Category tapped for item \(indexPath.item)")
            }

            return cell

        case .none:
            return UICollectionViewCell()
        }
    }

    // MARK: Section Header

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {

        guard kind == UICollectionView.elementKindSectionHeader,
              Section(rawValue: indexPath.section) == .items else {
            return UICollectionReusableView()
        }

        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "ReceiptSectionHeaderViewCell",
            for: indexPath
        ) as! ReceiptSectionHeaderView

        header.configure(title: "Scanned Items", itemCount: lineItems.count)
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension ReceiptReviewViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard Section(rawValue: indexPath.section) == .items,
              indexPath.item < lineItems.count else {
            return nil
        }

        let itemIndex = indexPath.item
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }

            let editAction = UIAction(title: "Edit",
                                      image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.presentItemEditor(for: itemIndex)
            }

            let deleteAction = UIAction(title: "Delete",
                                        image: UIImage(systemName: "trash"),
                                        attributes: .destructive) { [weak self] _ in
                self?.confirmDeleteItem(at: itemIndex)
            }

            return UIMenu(title: "", children: [editAction, deleteAction])
        }
    }
}

// MARK: - Item Editing

extension ReceiptReviewViewController {

    private func presentItemEditor(for itemIndex: Int? = nil,
                                   state: ItemEditorState? = nil,
                                   validationMessage: String? = nil) {
        let existingItem = itemIndex.flatMap { lineItems.indices.contains($0) ? lineItems[$0] : nil }
        let editorState = state ?? ItemEditorState(item: existingItem)
        let isEditing = itemIndex != nil

        let alert = UIAlertController(
            title: isEditing ? "Edit Item" : "Add Item",
            message: validationMessage ?? "Enter the item details. Leave quantity blank for a single-item purchase.",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Item name"
            textField.text = editorState.name
            textField.autocapitalizationType = .words
            textField.clearButtonMode = .whileEditing
        }

        alert.addTextField { textField in
            textField.placeholder = "Quantity"
            textField.text = editorState.quantityText
            textField.keyboardType = .decimalPad
            textField.clearButtonMode = .whileEditing
        }

        alert.addTextField { textField in
            textField.placeholder = "Unit price"
            textField.text = editorState.unitPriceText
            textField.keyboardType = .decimalPad
            textField.clearButtonMode = .whileEditing
        }

        alert.addTextField { textField in
            textField.placeholder = "Total price"
            textField.text = editorState.totalPriceText
            textField.keyboardType = .decimalPad
            textField.clearButtonMode = .whileEditing
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: isEditing ? "Save" : "Add", style: .default) { [weak self, weak alert] _ in
            guard let self, let alert else { return }

            let textFields = alert.textFields ?? []
            let submittedState = ItemEditorState(
                name: textFields[safe: 0]?.text ?? "",
                quantityText: textFields[safe: 1]?.text ?? "",
                unitPriceText: textFields[safe: 2]?.text ?? "",
                totalPriceText: textFields[safe: 3]?.text ?? ""
            )

            self.handleItemEditorSubmission(submittedState, itemIndex: itemIndex)
        })

        present(alert, animated: true)
    }

    private func handleItemEditorSubmission(_ state: ItemEditorState, itemIndex: Int?) {
        switch makeLineItem(from: state) {
        case .success(let item):
            if let itemIndex {
                updateItem(item, at: itemIndex)
            } else {
                appendItem(item)
            }
        case .failure(let message):
            DispatchQueue.main.async { [weak self] in
                self?.presentItemEditor(for: itemIndex,
                                        state: state,
                                        validationMessage: message.localizedDescription)
            }
        }
    }

    private func makeLineItem(from state: ItemEditorState) -> Result<ReceiptLineItem, ItemEditorValidationError> {
        let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return .failure(.message("Add an item name so the transaction is easy to recognize later."))
        }

        let quantityResult = parsedDecimal(from: state.quantityText, fieldName: "quantity")
        let unitPriceResult = parsedDecimal(from: state.unitPriceText, fieldName: "unit price")
        let totalPriceResult = parsedDecimal(from: state.totalPriceText, fieldName: "total price")

        switch (quantityResult, unitPriceResult, totalPriceResult) {
        case (.failure(let message), _, _),
             (_, .failure(let message), _),
             (_, _, .failure(let message)):
            return .failure(message)
        case (.success(let quantityValue), .success(let unitPriceValue), .success(let totalPriceValue)):
            var quantity = quantityValue
            let unitPrice = unitPriceValue
            var totalPrice = totalPriceValue

            if let quantity, quantity <= 0 {
                return .failure(.message("Quantity should be greater than 0."))
            }

            if let unitPrice, unitPrice < 0 {
                return .failure(.message("Unit price cannot be negative."))
            }

            if let totalPrice, totalPrice < 0 {
                return .failure(.message("Total price cannot be negative."))
            }

            if totalPrice == nil {
                if let quantity, let unitPrice {
                    totalPrice = quantity * unitPrice
                } else if let unitPrice {
                    quantity = quantity ?? 1
                    totalPrice = unitPrice
                }
            }

            guard let resolvedTotal = totalPrice else {
                return .failure(.message("Enter a total price, or provide quantity with unit price so the app can calculate it."))
            }

            let resolvedUnitPrice: Double?
            if let unitPrice {
                resolvedUnitPrice = unitPrice
            } else if let quantity, quantity > 0 {
                resolvedUnitPrice = resolvedTotal / quantity
            } else {
                resolvedUnitPrice = nil
            }

            return .success(
                ReceiptLineItem(
                    name: trimmedName,
                    quantity: quantity,
                    unitPrice: resolvedUnitPrice,
                    totalPrice: resolvedTotal
                )
            )
        }
    }

    private func parsedDecimal(from text: String, fieldName: String) -> Result<Double?, ItemEditorValidationError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .success(nil) }

        let sanitized = trimmed
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value = Double(sanitized) else {
            return .failure(.message("Enter a valid \(fieldName)."))
        }

        return .success(value)
    }

    private func appendItem(_ item: ReceiptLineItem) {
        lineItems.append(item)

        if let category = defaultCategory(for: item) {
            assignedCategories[lineItems.count - 1] = category
        }

        reloadReceiptContent()
    }

    private func updateItem(_ item: ReceiptLineItem, at index: Int) {
        guard lineItems.indices.contains(index) else { return }
        lineItems[index] = item

        if assignedCategories[index] == nil,
           let category = defaultCategory(for: item) {
            assignedCategories[index] = category
        }

        reloadReceiptContent()
    }

    private func confirmDeleteItem(at index: Int) {
        guard lineItems.indices.contains(index) else { return }

        let alert = UIAlertController(
            title: "Delete Item?",
            message: "This will remove the item from the receipt review list.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteItem(at: index)
        })
        present(alert, animated: true)
    }

    private func deleteItem(at index: Int) {
        guard lineItems.indices.contains(index) else { return }

        lineItems.remove(at: index)
        assignedCategories = reindexedCategories(afterDeleting: index)
        reloadReceiptContent()
    }

    private func reindexedCategories(afterDeleting index: Int) -> [Int: Category] {
        assignedCategories.reduce(into: [:]) { result, entry in
            switch entry.key {
            case index:
                break
            case let key where key > index:
                result[key - 1] = entry.value
            default:
                result[entry.key] = entry.value
            }
        }
    }

}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
