import UIKit

private enum CVTag {
    static let calendar = 1
    static let upcomingBills = 2
    static let activeSubs = 3
}

class BillsSubscriptionCalenderViewController: UIViewController {

    @IBOutlet weak var UpcomingcollectionViewHeight: NSLayoutConstraint!
    @IBOutlet weak var ActivecollectionViewHeight: NSLayoutConstraint!

    @IBOutlet weak var CalenderView: UIView!
    @IBOutlet weak var previousMonthButton: UIButton!
    @IBOutlet weak var MonthLabel: UILabel!
    @IBOutlet weak var nextMonthButton: UIButton!
    @IBOutlet weak var CalenderCollectionView: UICollectionView!

    @IBOutlet weak var UpcomingBillsCollectionView: UICollectionView!
    @IBOutlet weak var UpcomingBillsTotalAmountLabel: UILabel!
    @IBOutlet weak var ActiveSubscriptionCollectionView: UICollectionView!
    @IBOutlet weak var ActiveSubscriptionTotalAmountLabel: UILabel!

    private let db = DatabaseManager.shared

    private var todayComponents: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: Date())
    }

    private var currentYear: Int = Calendar.current.component(.year, from: Date())
    private var currentMonth: Int = Calendar.current.component(.month, from: Date())
    private var calendarCells: [CalendarDay] = []
    private var selectedDay: Int? = Calendar.current.component(.day, from: Date())

    private var allBills: [Bill] = []
    private var allSubscriptions: [RecurringPayment] = []
    private var filteredUpcomingBills: [Bill] = []

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
        reloadFromDatabase()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
        reloadFromDatabase()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        UpcomingcollectionViewHeight.constant = UpcomingBillsCollectionView.contentSize.height
        ActivecollectionViewHeight.constant = ActiveSubscriptionCollectionView.contentSize.height
    }

    private func setupUI() {
        view.backgroundColor = AppColors.background
        CalenderView.backgroundColor = AppColors.card
        CalenderView.applyShadow()

        MonthLabel.textColor = AppColors.textPrimary
        UpcomingBillsTotalAmountLabel.textColor = AppColors.textPrimary
        ActiveSubscriptionTotalAmountLabel.textColor = AppColors.textPrimary
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
        CalenderCollectionView.delegate = self
        CalenderCollectionView.dataSource = self
    }

    private func setupBillsCollectionViews() {
        UpcomingBillsCollectionView.tag = CVTag.upcomingBills
        ActiveSubscriptionCollectionView.tag = CVTag.activeSubs

        let nib = UINib(nibName: "SubsAndBillsCollectionViewCell", bundle: nil)
        UpcomingBillsCollectionView.register(nib, forCellWithReuseIdentifier: billCellId)
        ActiveSubscriptionCollectionView.register(nib, forCellWithReuseIdentifier: subsCellId)

        UpcomingBillsCollectionView.collectionViewLayout = makeBillsLayout()
        ActiveSubscriptionCollectionView.collectionViewLayout = makeBillsLayout()

        UpcomingBillsCollectionView.backgroundColor = .clear
        ActiveSubscriptionCollectionView.backgroundColor = .clear

        UpcomingBillsCollectionView.delegate = self
        UpcomingBillsCollectionView.dataSource = self
        ActiveSubscriptionCollectionView.delegate = self
        ActiveSubscriptionCollectionView.dataSource = self
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

        reloadCalendar()
        refreshSelectedDayContent()
        ActiveSubscriptionCollectionView.reloadData()
        updateSubscriptionTotal()

        DispatchQueue.main.async {
            self.relayoutDynamicViews()
        }
    }

    private func refreshSelectedDayContent() {
        if let day = selectedDay, let date = makeDate(day: day) {
            filterBills(for: date)
        } else {
            filteredUpcomingBills = []
            UpcomingBillsTotalAmountLabel.text = AppFormatters.currency(0)
            UpcomingBillsCollectionView.reloadData()
            relayoutDynamicViews()
        }
    }

    private func reloadCalendar() {
        let dataSource = CalendarDataSource(year: currentYear, month: currentMonth)
        let unpaidBills = allBills.filter { !$0.isPaid }
        let billDays = dataSource.billDaySet(from: unpaidBills)
        let subscriptionDays = displayedSubscriptions.reduce(into: Set<Int>()) { partialResult, subscription in
            partialResult.formUnion(
                subscriptionEventDays(for: subscription, year: currentYear, month: currentMonth)
            )
        }

        calendarCells = dataSource.days(billDates: billDays.union(subscriptionDays))
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

    @IBAction
    @objc func previousMonthTapped(_ sender: UIButton) {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }

        selectedDay = nil
        reloadCalendar()
        refreshSelectedDayContent()
    }

    @IBAction
    @objc func nextMonthTapped(_ sender: UIButton) {
        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }

        selectedDay = nil
        reloadCalendar()
        refreshSelectedDayContent()
    }

    private func filterBills(for date: Date) {
        let calendar = Calendar.current
        filteredUpcomingBills = allBills.filter {
            !$0.isPaid && calendar.isDate($0.billDate, inSameDayAs: date)
        }

        let total = filteredUpcomingBills.reduce(0) { $0 + $1.amount }
        UpcomingBillsTotalAmountLabel.text = AppFormatters.currency(total)
        UpcomingBillsCollectionView.reloadData()
        relayoutDynamicViews()
    }

    private func updateSubscriptionTotal() {
        let total = displayedSubscriptions.reduce(0) { $0 + $1.amount }
        ActiveSubscriptionTotalAmountLabel.text = AppFormatters.currency(total)
    }

    private func relayoutDynamicViews() {
        DispatchQueue.main.async {
            self.UpcomingBillsCollectionView.collectionViewLayout.invalidateLayout()
            self.ActiveSubscriptionCollectionView.collectionViewLayout.invalidateLayout()
            self.UpcomingBillsCollectionView.layoutIfNeeded()
            self.ActiveSubscriptionCollectionView.layoutIfNeeded()
            self.UpcomingcollectionViewHeight.constant = self.calculatedListHeight(itemCount: self.filteredUpcomingBills.count)
            self.ActivecollectionViewHeight.constant = self.calculatedListHeight(itemCount: self.displayedSubscriptions.count)
            self.view.layoutIfNeeded()
        }
    }

    private func calculatedListHeight(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        let rowHeight: CGFloat = 72
        let spacing: CGFloat = 8
        return CGFloat(itemCount) * rowHeight + CGFloat(max(itemCount - 1, 0)) * spacing
    }

    private func makeDate(day: Int) -> Date? {
        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth
        components.day = day
        return Calendar.current.date(from: components)
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
            return filteredUpcomingBills.count
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
            let isSelected = item.day == selectedDay && !item.isPadding
            cell.configure(
                day: item.day,
                isToday: isToday,
                isSelected: isSelected,
                isPadding: item.isPadding,
                hasBill: item.hasBill
            )
            return cell

        case CVTag.upcomingBills:
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: billCellId,
                for: indexPath
            ) as? SubsAndBillsCollectionViewCell else {
                return UICollectionViewCell()
            }
            cell.configureBill(with: filteredUpcomingBills[indexPath.row])
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
        guard collectionView.tag == CVTag.calendar else { return }

        let item = calendarCells[indexPath.item]
        guard let day = item.day, !item.isPadding else { return }

        selectedDay = day
        CalenderCollectionView.reloadData()

        if let date = makeDate(day: day) {
            filterBills(for: date)
        } else {
            filteredUpcomingBills = []
            UpcomingBillsCollectionView.reloadData()
            relayoutDynamicViews()
        }
    }
}
