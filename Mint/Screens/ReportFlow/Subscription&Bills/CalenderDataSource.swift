//
//  CalendarDataSource.swift
//  BudgetApp
//
//  Pure data layer — zero UIKit, zero outlets.
//  Computes the 7-column grid of CalendarDay items for a given month/year,
//  and marks which days have a bill due.
//

import Foundation

// MARK: - CalendarDay  (one cell in the grid)

struct CalendarDay {
    let day:       Int? // nil  → empty padding cell (prev / next month overflow)
    let isToday:   Bool
    let isPadding: Bool   // true → belongs to an adjacent month
    let hasBill:   Bool   // true → show the green dot indicator
}

// MARK: - CalendarDataSource

struct CalendarDataSource {

    let year:  Int
    let month: Int        // 1-based  (1 = January … 12 = December)

    private let calendar = Calendar.current

    // MARK: - Grid

    /// Returns exactly enough cells to fill complete 7-column weeks.
    func days(billDates: Set<Int> = []) -> [CalendarDay] {
        guard let firstOfMonth = firstDayOfMonth() else { return [] }

        let startOffset = calendar.component(.weekday, from: firstOfMonth) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)!.count

        var cells: [CalendarDay] = []

        // Leading padding
        for _ in 0 ..< startOffset {
            cells.append(CalendarDay(day: nil, isToday: false, isPadding: true, hasBill: false))
        }

        // Actual days
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        for d in 1 ... daysInMonth {
            let isToday = todayComponents.year  == year
                       && todayComponents.month == month
                       && todayComponents.day   == d
            cells.append(CalendarDay(
                day:       d,
                isToday:   isToday,
                isPadding: false,
                hasBill:   billDates.contains(d)
            ))
        }

        // Trailing padding to complete the last row
        let remainder = cells.count % 7
        if remainder != 0 {
            for _ in 0 ..< (7 - remainder) {
                cells.append(CalendarDay(day: nil, isToday: false, isPadding: true, hasBill: false))
            }
        }

        return cells
    }

    // MARK: - Bill day set

    /// Extracts the day-of-month integers from a list of Bills that fall in this month/year.
    func billDaySet(from bills: [Bill]) -> Set<Int> {
        Set(bills.compactMap { bill in
            let c = calendar.dateComponents([.year, .month, .day], from: bill.billDate)
            guard c.year == year, c.month == month else { return nil }
            return c.day
        })
    }

    // MARK: - Month display string  (e.g. "March 2026")

    var displayTitle: String {
        guard let d = firstDayOfMonth() else { return "" }
        return AppFormatters.monthYear.string(from: d)
    }

    // MARK: - Private

    private func firstDayOfMonth() -> Date? {
        var c   = DateComponents()
        c.year  = year
        c.month = month
        c.day   = 1
        return calendar.date(from: c)
    }
}
