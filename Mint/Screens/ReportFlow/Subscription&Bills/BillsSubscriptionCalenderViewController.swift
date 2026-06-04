import UIKit

private enum CVTag {
    static let calendar = 1
    static let upcomingBills = 2
    static let activeSubs = 3
}

private enum BillStatusFilter: Int {
    case upcoming = 0
    case overdue = 1
    case paid = 2

    var title: String {
        switch self {
        case .upcoming:
            return "Upcoming"
        case .overdue:
            return "Overdue"
        case .paid:
            return "Paid"
        }
    }
}

private enum SubsAndBillsCalendarItem {
    case bill(Bill)
    case subscription(RecurringPayment, Date)

    var amount: Double {
        switch self {
        case .bill(let bill):
            return bill.amount
        case .subscription(let subscription, _):
            return subscription.amount
        }
    }

    var date: Date {
        switch self {
        case .bill(let bill):
            return bill.billDate
        case .subscription(_, let date):
            return date
        }
    }
}

class BillsSubscriptionCalenderViewController: UIViewController {

    @IBOutlet weak var AllBillsCollectionViewHeight: NSLayoutConstraint!
    
    @IBOutlet weak var CalenderView: UIView!
    @IBOutlet weak var previousMonthButton: UIButton!
    @IBOutlet weak var MonthLabel: UILabel!
    @IBOutlet weak var nextMonthButton: UIButton!
    @IBOutlet weak var CalenderCollectionView: UICollectionView!

    @IBOutlet weak var AllBillsCollectionView: UICollectionView!
    @IBOutlet weak var ThisMonthLabel: UILabel!
    @IBOutlet weak var TotalAmountLabel: UILabel!
    @IBOutlet weak var SegmentedControl: UISegmentedControl!
    
    private let db = DatabaseManager.shared

    private var todayComponents: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: Date())
    }

    private var currentYear: Int = Calendar.current.component(.year, from: Date())
    private var currentMonth: Int = Calendar.current.component(.month, from: Date())
    private var calendarCells: [CalendarDay] = []
    private var selectedBillStatus: BillStatusFilter = .upcoming

    private var allBills: [Bill] = []
    private var allSubscriptions: [RecurringPayment] = []
    private var allTransactions: [Transaction] = []
    private var filteredItems: [SubsAndBillsCalendarItem] = []

    private var displayedSubscriptions: [RecurringPayment] {
        allSubscriptions.filter {
            !subscriptionEventDays(for: $0, year: currentYear, month: currentMonth).isEmpty
        }
    }

    private let calendarCellId = "CalendarDayCell"
    private let billCellId = "SubsAndBillsCell"
    private let subsCellId = "SubsAndBillsCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCalendarCollectionView()
        setupBillsCollectionViews()
        observeDataChanges()
        reloadFromDatabase()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
        applyReportNavigationTheme()
        reloadFromDatabase()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        AllBillsCollectionViewHeight.constant = AllBillsCollectionView.contentSize.height

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func observeDataChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBudgetDataChange),
            name: .budgetDataDidChange,
            object: nil
        )
    }

    @objc private func handleBudgetDataChange() {
        reloadFromDatabase()
    }

    private func setupUI() {
        applyReportBackgroundTheme(to: view)
        view.backgroundColor = AppColors.background
        view.tintColor = AppColors.brand

        previousMonthButton.tintColor = AppColors.brand
        nextMonthButton.tintColor = AppColors.brand
        CalenderView.backgroundColor = AppColors.card
        CalenderView.applyShadow()

        MonthLabel.textColor = AppColors.textPrimary
        ThisMonthLabel.textColor = AppColors.textPrimary
        TotalAmountLabel.textColor = AppColors.textPrimary
        SegmentedControl.selectedSegmentIndex = selectedBillStatus.rawValue
        SegmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
 
    }

    private func applyReportBackgroundTheme(to parent: UIView) {
        switch parent {
        case is UIStackView:
            parent.backgroundColor = .clear
        case is UILabel, is UIButton:
            parent.backgroundColor = .clear
            return
        case is UICollectionView:
            parent.backgroundColor = .clear
        case is UIScrollView:
            parent.backgroundColor = AppColors.background
        default:
            parent.backgroundColor = AppColors.background
        }

        parent.subviews.forEach { applyReportBackgroundTheme(to: $0) }
    }

    private func applyReportNavigationTheme() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: AppColors.textPrimary,
            .font: MintFont.space(size: 28, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: AppColors.textPrimary,
            .font: MintFont.space(size: 34, weight: .bold)
        ]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColors.textPrimary
    }

    private func setupCalendarCollectionView() {
        CalenderCollectionView.tag = CVTag.calendar
        CalenderCollectionView.register(
            UINib(nibName: "SubsCalenderCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: calendarCellId
        )
        CalenderCollectionView.collectionViewLayout = makeCalendarLayout()
        CalenderCollectionView.backgroundColor = .clear
        CalenderCollectionView.isScrollEnabled = false
        CalenderCollectionView.allowsSelection = false
        CalenderCollectionView.delegate = self
        CalenderCollectionView.dataSource = self
    }

    private func setupBillsCollectionViews() {
        AllBillsCollectionView.tag = CVTag.upcomingBills


        let nib = UINib(nibName: "SubsAndBillsCollectionViewCell", bundle: nil)
        AllBillsCollectionView.register(nib, forCellWithReuseIdentifier: billCellId)


        AllBillsCollectionView.collectionViewLayout = makeBillsLayout()


        AllBillsCollectionView.backgroundColor = .clear


        AllBillsCollectionView.delegate = self
        AllBillsCollectionView.dataSource = self
}

    private func makeCalendarLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let totalWidth = environment.container.effectiveContentSize.width
            let cellSide = floor(totalWidth / 7.0)

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(cellSide),
                heightDimension: .absolute(cellSide)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(cellSide)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: 7
            )
            group.interItemSpacing = .fixed(0)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 4
            return section
        }
    }

    private func makeBillsLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(72)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func reloadFromDatabase() {
        allBills = db.fetchBills()
        allSubscriptions = db.fetchRecurringPayments().filter { $0.isActive && !$0.isIncome }
        allTransactions = db.fetchTransactions()

        reloadCalendar()
        refreshMonthContent()

        DispatchQueue.main.async {
            self.relayoutDynamicViews()
        }
    }

    private func refreshMonthContent() {
        filteredItems = itemsForSelectedMonthAndStatus()

        let total = filteredItems.reduce(0) { $0 + $1.amount }
        ThisMonthLabel.text = "\(selectedBillStatus.title) Bills & Subscriptions"
        TotalAmountLabel.text = AppFormatters.currency(total)
        AllBillsCollectionView.reloadData()
        relayoutDynamicViews()
    }

    private func reloadCalendar() {
        let dataSource = CalendarDataSource(year: currentYear, month: currentMonth)
        let eventIcons = calendarEventIcons(items: allItemsForSelectedMonth())

        calendarCells = dataSource.days(eventIcons: eventIcons)
        MonthLabel.text = dataSource.displayTitle
        updateNavButtons()
        CalenderCollectionView.reloadData()

        DispatchQueue.main.async {
            self.CalenderCollectionView.collectionViewLayout.invalidateLayout()
            self.CalenderCollectionView.layoutIfNeeded()
        }
    }

    private func updateNavButtons() {
        nextMonthButton.isEnabled = true
        nextMonthButton.alpha = 1.0
        previousMonthButton.isEnabled = true
        previousMonthButton.alpha = 1.0
    }

    private func calendarEventIcons(items: [SubsAndBillsCalendarItem]) -> [Int: String] {
        var iconsByDay: [Int: String] = [:]

        for item in items {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: item.date)
            guard components.year == currentYear,
                  components.month == currentMonth,
                  let day = components.day
            else { continue }

            switch item {
            case .bill(let bill):
                iconsByDay[day] = normalizedCalendarIconName(bill.icon, fallback: "doc.text.fill")
            case .subscription(let subscription, _):
                iconsByDay[day] = normalizedCalendarIconName(subscription.icon, fallback: "creditcard.fill")
            }
        }

        return iconsByDay
    }

    private func normalizedCalendarIconName(_ iconName: String?, fallback: String) -> String {
        guard let iconName, !iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return iconName
    }

    @IBAction
    @objc func segmentChanged(_ sender: UISegmentedControl) {
        selectedBillStatus = BillStatusFilter(rawValue: sender.selectedSegmentIndex) ?? .upcoming
        refreshMonthContent()
    }

    @IBAction
    @objc func previousMonthTapped(_ sender: UIButton) {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }

        reloadCalendar()
        refreshMonthContent()
    }

    @IBAction
    @objc func nextMonthTapped(_ sender: UIButton) {
        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }

        reloadCalendar()
        refreshMonthContent()
    }

    private func itemsForSelectedMonthAndStatus() -> [SubsAndBillsCalendarItem] {
        allItemsForSelectedMonth()
            .filter { status(for: $0) == selectedBillStatus }
            .sorted { $0.date < $1.date }
    }

    private func allItemsForSelectedMonth() -> [SubsAndBillsCalendarItem] {
        billItemsForSelectedMonth() + subscriptionItemsForSelectedMonth()
    }

    private func billItemsForSelectedMonth() -> [SubsAndBillsCalendarItem] {
        let calendar = Calendar.current
        return allBills.compactMap { bill in
            guard calendar.component(.year, from: bill.billDate) == currentYear,
                  calendar.component(.month, from: bill.billDate) == currentMonth
            else { return nil }
            return .bill(bill)
        }
    }

    private func subscriptionItemsForSelectedMonth() -> [SubsAndBillsCalendarItem] {
        var items: [SubsAndBillsCalendarItem] = []

        for subscription in displayedSubscriptions {
            let dates = subscriptionEventDates(for: subscription, year: currentYear, month: currentMonth)
            items.append(contentsOf: dates.map { .subscription(subscription, $0) })
        }

        let paidSubscriptionItems = allTransactions.compactMap { transaction -> SubsAndBillsCalendarItem? in
            guard transaction.expenseType == "subscription",
                  let subscriptionId = parseSubscriptionId(fromPaymentNote: transaction.note),
                  Calendar.current.component(.year, from: transaction.timestamp) == currentYear,
                  Calendar.current.component(.month, from: transaction.timestamp) == currentMonth,
                  let subscription = allSubscriptions.first(where: { $0.id == subscriptionId })
            else { return nil }

            return .subscription(subscription, transaction.timestamp)
        }

        items.append(contentsOf: paidSubscriptionItems)
        return items
    }

    private func status(for item: SubsAndBillsCalendarItem) -> BillStatusFilter {
        switch item {
        case .bill(let bill):
            return billStatus(for: bill)
        case .subscription(let subscription, let date):
            return subscriptionPaymentExists(for: subscription.id, on: date) ? .paid : dueStatus(for: date)
        }
    }

    private func billStatus(for bill: Bill) -> BillStatusFilter {
        bill.isPaid ? .paid : dueStatus(for: bill.billDate)
    }

    private func dueStatus(for date: Date) -> BillStatusFilter {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return date < startOfToday ? .overdue : .upcoming
    }

    private func subscriptionPaymentExists(for subscriptionId: UUID, on date: Date) -> Bool {
        allTransactions.contains { transaction in
            transaction.expenseType == "subscription"
                && parseSubscriptionId(fromPaymentNote: transaction.note) == subscriptionId
                && Calendar.current.isDate(transaction.timestamp, inSameDayAs: date)
        }
    }

    private func parseSubscriptionId(fromPaymentNote note: String?) -> UUID? {
        guard let note, note.hasPrefix("subscription-payment:") else { return nil }
        return UUID(uuidString: String(note.dropFirst("subscription-payment:".count)))
    }

    private func relayoutDynamicViews() {
        DispatchQueue.main.async {
            self.AllBillsCollectionView.collectionViewLayout.invalidateLayout()
            self.AllBillsCollectionViewHeight.constant = self.calculatedListHeight(itemCount: self.filteredItems.count)
            self.view.layoutIfNeeded()
        }
    }

    private func calculatedListHeight(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        let rowHeight: CGFloat = 72
        let spacing: CGFloat = 8
        return CGFloat(itemCount) * rowHeight + CGFloat(max(itemCount - 1, 0)) * spacing
    }

    private func subscriptionEventDates(for subscription: RecurringPayment, year: Int, month: Int) -> [Date] {
        subscriptionEventDays(for: subscription, year: year, month: month).compactMap {
            Calendar.current.date(from: DateComponents(year: year, month: month, day: $0))
        }
    }

    private func subscriptionEventDays(for subscription: RecurringPayment, year: Int, month: Int) -> Set<Int> {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
        let anchorDate = calendar.startOfDay(for: subscription.nextDate)
        guard monthEnd >= anchorDate else { return [] }

        switch subscription.duration {
        case .daily:
            let startDay = calendar.isDate(anchorDate, equalTo: monthStart, toGranularity: .month)
                ? calendar.component(.day, from: anchorDate)
                : dayRange.lowerBound
            return Set(startDay..<dayRange.upperBound)

        case .weekly:
            let weekday = calendar.component(.weekday, from: anchorDate)
            return Set(dayRange.compactMap { day -> Int? in
                guard let candidate = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                      candidate >= anchorDate,
                      calendar.component(.weekday, from: candidate) == weekday
                else { return nil }
                return day
            })

        case .monthly, .quarterly, .halfYearly, .yearly:
            let anchorMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchorDate)) ?? anchorDate
            let anchorComponents = calendar.dateComponents([.year, .month, .day], from: anchorDate)
            guard let anchorYear = anchorComponents.year,
                  let anchorMonth = anchorComponents.month,
                  let anchorDay = anchorComponents.day
            else { return [] }
            guard monthStart >= anchorMonthStart else { return [] }

            let monthDelta = (year - anchorYear) * 12 + (month - anchorMonth)
            let stride: Int

            switch subscription.duration {
            case .monthly:
                stride = 1
            case .quarterly:
                stride = 3
            case .halfYearly:
                stride = 6
            case .yearly:
                stride = 12
            case .daily, .weekly:
                stride = 1
            }

            guard monthDelta >= 0, monthDelta % stride == 0 else { return [] }
            return [min(anchorDay, dayRange.count)]
        }
    }
}

extension BillsSubscriptionCalenderViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView.tag {
        case CVTag.calendar:
            return calendarCells.count
        case CVTag.upcomingBills:
            return filteredItems.count
        case CVTag.activeSubs:
            return displayedSubscriptions.count
        default:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch collectionView.tag {
        case CVTag.calendar:
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: calendarCellId,
                for: indexPath
            ) as? SubsCalenderCollectionViewCell else {
                return UICollectionViewCell()
            }

            let item = calendarCells[indexPath.item]
            let isCurrentMonth = currentYear == todayComponents.year && currentMonth == todayComponents.month
            let isToday = isCurrentMonth && item.isToday
            cell.configure(
                day: item.day,
                isToday: isToday,
                isSelected: false,
                isPadding: item.isPadding,
                eventIconName: item.eventIconName
            )
            return cell

        case CVTag.upcomingBills:
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: billCellId,
                for: indexPath
            ) as? SubsAndBillsCollectionViewCell else {
                return UICollectionViewCell()
            }
            switch filteredItems[indexPath.row] {
            case .bill(let bill):
                cell.configureBill(with: bill)
            case .subscription(let subscription, _):
                cell.configureSubscription(with: subscription)
            }
            return cell

        case CVTag.activeSubs:
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: subsCellId,
                for: indexPath
            ) as? SubsAndBillsCollectionViewCell else {
                return UICollectionViewCell()
            }
            cell.configureSubscription(with: displayedSubscriptions[indexPath.row])
            return cell

        default:
            return UICollectionViewCell()
        }
    }
}

extension BillsSubscriptionCalenderViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard collectionView.tag != CVTag.calendar else { return }
    }
}
