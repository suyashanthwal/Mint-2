//
//  RecentTransactionsViewController.swift
//  RecentTransactions
//
//  Created by Anushk Barmola on 08/02/26.
//

import UIKit

final class RecentTransactionsViewController: UIViewController {

    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var totalAmountLabel: UILabel!
    @IBOutlet private weak var monthLabel: UILabel!
    @IBOutlet private weak var yearLabel: UILabel!
    @IBOutlet private weak var dateButton: UIButton!
    @IBOutlet private weak var amountButton: UIButton!
    @IBOutlet private weak var paymentButton: UIButton!

    @IBOutlet weak var MonthCard: UIView!
    // MARK: - Sort / Filter State

    private enum DateSortOrder {
        case newestFirst, oldestFirst

        var buttonTitle: String {
            switch self {
            case .newestFirst: return "Newest"
            case .oldestFirst: return "Oldest"
            }
        }
    }

    private enum AmountSortOrder {
        case none, highToLow, lowToHigh

        var buttonTitle: String {
            switch self {
            case .none:      return "Amount"
            case .highToLow: return "High"
            case .lowToHigh: return "Low"
            }
        }
    }

    private enum PaymentFilter {
        case all, upi, ecommerce, manual, income

        var buttonTitle: String {
            switch self {
            case .all:       return "Type"
            case .upi:       return "UPI"
            case .ecommerce: return "Online"
            case .manual:    return "Manual"
            case .income:    return "Income"
            }
        }

        func includes(_ transaction: Transaction) -> Bool {
            switch self {
            case .all:       return true
            case .upi:       return transaction.type == .expense && transaction.source == .upi
            case .ecommerce: return transaction.type == .expense && transaction.source == .ecommerce
            case .manual:    return transaction.type == .expense && transaction.source == .manual
            case .income:    return transaction.type == .income
            }
        }
    }

    // MARK: - Properties

    private let calendar = Calendar.current
    private let db = DatabaseManager.shared

    private var dateSortOrder   : DateSortOrder   = .newestFirst
    private var amountSortOrder : AmountSortOrder = .none
    private var paymentFilter   : PaymentFilter   = .all
    private var allTransactions: [Transaction] = []
    private var allCategories: [Category] = []
    private var displayedTransactions: [Transaction] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupMenus()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransactionDataChange),
            name: .transactionDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransactionDataChange),
            name: .categoryDataDidChange,
            object: nil
        )
        reloadFromDatabase()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
        reloadFromDatabase()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    func setupUI() {
        view.backgroundColor = AppColors.background
        dateButton.backgroundColor = AppColors.brandLight
        amountButton.backgroundColor = AppColors.brandLight
        paymentButton.backgroundColor = AppColors.brandLight
        collectionView.backgroundColor = .systemGray4
        MonthCard.backgroundColor = AppColors.card
        
        
    }
    // MARK: - Collection-view setup

    private func setupCollectionView() {
        collectionView.delegate   = self
        collectionView.dataSource = self

        collectionView.register(
            UINib(nibName: "TransactionCellCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "TransactionCell"
        )

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection         = .vertical
        layout.minimumLineSpacing      = 1
        layout.minimumInteritemSpacing = 0
        collectionView.collectionViewLayout = layout
        collectionView.layer.masksToBounds          = true
        collectionView.showsVerticalScrollIndicator = true
        collectionView.alwaysBounceVertical         = true
        collectionView.contentInset                 = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    // MARK: - Filter / Sort menus

    private func setupMenus() {
        setupDateMenu()
        setupAmountMenu()
        setupPaymentMenu()
    }

    private func setupDateMenu() {
        let newest = UIAction(title: "Newest First") { [weak self] _ in
            self?.dateSortOrder = .newestFirst
            self?.dateButton.setTitle(DateSortOrder.newestFirst.buttonTitle, for: .normal)
            self?.reloadTransactions()
        }
        let oldest = UIAction(title: "Oldest First") { [weak self] _ in
            self?.dateSortOrder = .oldestFirst
            self?.dateButton.setTitle(DateSortOrder.oldestFirst.buttonTitle, for: .normal)
            self?.reloadTransactions()
        }
        dateButton.menu = UIMenu(children: [newest, oldest])
        dateButton.showsMenuAsPrimaryAction = true
        dateButton.setTitle(dateSortOrder.buttonTitle, for: .normal)
    }

    private func setupAmountMenu() {
        let high = UIAction(title: "High → Low") { [weak self] _ in
            self?.amountSortOrder = .highToLow
            self?.amountButton.setTitle(AmountSortOrder.highToLow.buttonTitle, for: .normal)
            self?.reloadTransactions()
        }
        let low = UIAction(title: "Low → High") { [weak self] _ in
            self?.amountSortOrder = .lowToHigh
            self?.amountButton.setTitle(AmountSortOrder.lowToHigh.buttonTitle, for: .normal)
            self?.reloadTransactions()
        }
        let reset = UIAction(title: "Default") { [weak self] _ in
            self?.amountSortOrder = .none
            self?.amountButton.setTitle(AmountSortOrder.none.buttonTitle, for: .normal)
            self?.reloadTransactions()
        }
        amountButton.menu = UIMenu(children: [high, low, reset])
        amountButton.showsMenuAsPrimaryAction = true
        amountButton.setTitle(amountSortOrder.buttonTitle, for: .normal)
    }

    private func setupPaymentMenu() {
        let all = UIAction(title: "All") { [weak self] _ in
            self?.paymentFilter = .all
            self?.paymentButton.setTitle(PaymentFilter.all.buttonTitle, for: .normal)
            self?.reloadTransactions()
        }
        let upi = UIAction(title: "UPI") { [weak self] _ in
            self?.paymentFilter = .upi
            self?.paymentButton.setTitle(PaymentFilter.upi.buttonTitle, for: .normal)
            self?.reloadTransactions()
        }
        let ecommerce = UIAction(title: "Online") { [weak self] _ in
            self?.paymentFilter = .ecommerce
            self?.paymentButton.setTitle(PaymentFilter.ecommerce.buttonTitle, for: .normal)
            self?.reloadTransactions()
        }
        let manual = UIAction(title: "Manual") { [weak self] _ in
            self?.paymentFilter = .manual
            self?.paymentButton.setTitle(PaymentFilter.manual.buttonTitle, for: .normal)
            self?.reloadTransactions()
        }
        let income = UIAction(title: "Income") { [weak self] _ in
            self?.paymentFilter = .income
            self?.paymentButton.setTitle(PaymentFilter.income.buttonTitle, for: .normal)
            self?.reloadTransactions()
        }
        paymentButton.menu = UIMenu(children: [all, upi, ecommerce, manual, income])
        paymentButton.showsMenuAsPrimaryAction = true
        paymentButton.setTitle(paymentFilter.buttonTitle, for: .normal)
    }

    // MARK: - Data helpers

    private func reloadFromDatabase() {
        allTransactions = db.fetchTransactions()
        allCategories = db.fetchCategories()
        reloadTransactions()
    }

    @objc private func handleTransactionDataChange() {
        reloadFromDatabase()
    }

    private func reloadTransactions() {
        displayedTransactions = allTransactions
            .filter { paymentFilter.includes($0) }
            .sorted(by: sortTransactions(_:_:))

        updateHeader()
        collectionView.reloadData()
    }

    private func sortTransactions(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        if amountSortOrder != .none, lhs.amount != rhs.amount {
            switch amountSortOrder {
            case .highToLow: return lhs.amount > rhs.amount
            case .lowToHigh: return lhs.amount < rhs.amount
            case .none:      break
            }
        }

        if lhs.timestamp != rhs.timestamp {
            switch dateSortOrder {
            case .newestFirst: return lhs.timestamp > rhs.timestamp
            case .oldestFirst: return lhs.timestamp < rhs.timestamp
            }
        }

        return lhs.createdAt > rhs.createdAt
    }

    private func updateHeader() {
        guard let ref = displayedTransactions.first else {
            monthLabel.text       = "No"
            yearLabel.text        = "Transactions"
            totalAmountLabel.text = AppFormatters.currency(0)
            return
        }

        monthLabel.text = AppFormatters.month(ref.timestamp)
        yearLabel.text  = AppFormatters.year(ref.timestamp)

        let monthlyTotal = displayedTransactions
            .filter { t in
                t.type == .expense &&
                calendar.isDate(t.timestamp, equalTo: ref.timestamp, toGranularity: .month) &&
                calendar.isDate(t.timestamp, equalTo: ref.timestamp, toGranularity: .year)
            }
            .reduce(0) { $0 + $1.amount }

        totalAmountLabel.text = AppFormatters.currency(monthlyTotal)
    }

    private func category(for transaction: Transaction) -> Category? {
        guard let id = transaction.categoryId else { return nil }
        return allCategories.first { $0.id == id }
    }
}

// MARK: - UICollectionViewDataSource

extension RecentTransactionsViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        displayedTransactions.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "TransactionCell",
            for: indexPath
        ) as? TransactionCell else {
            return UICollectionViewCell()
        }

        let transaction = displayedTransactions[indexPath.item]
        cell.configure(with: transaction, category: category(for: transaction))
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension RecentTransactionsViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: 70)
    }
}
