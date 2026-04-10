//
//  Subs&BillsCardCollectionViewCell.swift
//  Mint
//
//  Created by Suyash Anthwal on 06/04/26.
//

import UIKit

struct SubsBillsCalendarData {
    let year: Int
    let month: Int
    let title: String
    let eventDays: Set<Int>
    let nextBillText: String
}

final class Subs_BillsCardCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var calendarContainerView: UIView!
    @IBOutlet weak var monthLabel: UILabel!
    @IBOutlet weak var NextBillLabel: UILabel!
    @IBOutlet weak var calendarView: UICollectionView!
    
    private let calendarCellId = "CalendarDayCell"
    private var calendarCells: [CalendarDay] = []

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        setupCalendarCollectionView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        calendarView.collectionViewLayout.invalidateLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        calendarCells = []
        monthLabel.text = nil
        NextBillLabel.text = nil
        calendarView.reloadData()
    }

    func configure(with model: SubsBillsCalendarData) {
        monthLabel.text = model.title
        NextBillLabel.text = model.nextBillText
        let dataSource = CalendarDataSource(year: model.year, month: model.month)
        calendarCells = dataSource.days(billDates: model.eventDays)
        calendarView.reloadData()
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        calendarContainerView.backgroundColor = AppColors.card
        calendarContainerView.layer.cornerRadius = 18
        calendarContainerView.clipsToBounds = true
        calendarContainerView.applyShadow()

        monthLabel.textColor = AppColors.textPrimary
        NextBillLabel.textColor = AppColors.textSecondary
    }

    private func setupCalendarCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 4
        layout.minimumInteritemSpacing = 0

        calendarView.collectionViewLayout = layout
        calendarView.backgroundColor = .clear
        calendarView.isScrollEnabled = false
        calendarView.showsVerticalScrollIndicator = false
        calendarView.showsHorizontalScrollIndicator = false
        calendarView.delegate = self
        calendarView.dataSource = self
        calendarView.register(
            UINib(nibName: "SubsCalenderCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: calendarCellId
        )
    }
}

extension Subs_BillsCardCollectionViewCell: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        calendarCells.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: calendarCellId,
            for: indexPath
        ) as? SubsCalenderCollectionViewCell else {
            return UICollectionViewCell()
        }

        let item = calendarCells[indexPath.item]
        cell.configure(
            day: item.day,
            isToday: item.isToday,
            isSelected: false,
            isPadding: item.isPadding,
            hasBill: item.hasBill,
            highlightColor: AppColors.brandLight,
            highlightTextColor: AppColors.brandLightText
        )
        return cell
    }
}

extension Subs_BillsCardCollectionViewCell: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 7
        let spacing: CGFloat = 0
        let totalSpacing = spacing * (columns - 1)
        let width = floor((collectionView.bounds.width - totalSpacing) / columns)
        return CGSize(width: width, height: width)
    }
}
