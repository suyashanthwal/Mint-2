
import Foundation

struct CalendarDay {
    let day:       Int?
    let isToday:   Bool
    let isPadding: Bool
    let eventIconName: String?
}

struct CalendarDataSource {

    let year:  Int
    let month: Int

    private let calendar = Calendar.current

    func days(eventIcons: [Int: String] = [:]) -> [CalendarDay] {
        guard let firstOfMonth = firstDayOfMonth() else { return [] }

        let startOffset = calendar.component(.weekday, from: firstOfMonth) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)!.count

        var cells: [CalendarDay] = []

        for _ in 0 ..< startOffset {
            cells.append(CalendarDay(day: nil, isToday: false, isPadding: true, eventIconName: nil))
        }

        let todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        for d in 1 ... daysInMonth {
            let isToday = todayComponents.year  == year
                       && todayComponents.month == month
                       && todayComponents.day   == d
            cells.append(CalendarDay(
                day:       d,
                isToday:   isToday,
                isPadding: false,
                eventIconName: eventIcons[d]
            ))
        }

        let remainder = cells.count % 7
        if remainder != 0 {
            for _ in 0 ..< (7 - remainder) {
                cells.append(CalendarDay(day: nil, isToday: false, isPadding: true, eventIconName: nil))
            }
        }

        return cells
    }

    func billDaySet(from bills: [Bill]) -> Set<Int> {
        Set(bills.compactMap { bill in
            let c = calendar.dateComponents([.year, .month, .day], from: bill.billDate)
            guard c.year == year, c.month == month else { return nil }
            return c.day
        })
    }

    var displayTitle: String {
        guard let d = firstDayOfMonth() else { return "" }
        return AppFormatters.monthYear.string(from: d)
    }

    private func firstDayOfMonth() -> Date? {
        var c   = DateComponents()
        c.year  = year
        c.month = month
        c.day   = 1
        return calendar.date(from: c)
    }
}
