import Foundation
import UserNotifications

final class BillSubscriptionReminderManager {

    static let shared = BillSubscriptionReminderManager()

    private init() {}

    private let notificationCenter = UNUserNotificationCenter.current()
    private let billPrefix = "bill-reminder-"
    private let subscriptionPrefix = "subscription-reminder-"
    private let reminderHour = 9

    func refreshAllReminders() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                self.cancelAllManagedReminders()
                return
            }

            let database = DatabaseManager.shared
            let bills = database.fetchBills()
            let recurringPayments = database.fetchRecurringPayments()

            self.cancelAllManagedReminders {
                bills.forEach { self.scheduleReminder(for: $0) }
                recurringPayments.forEach { self.scheduleReminder(for: $0) }
            }
        }
    }

    func scheduleReminder(for bill: Bill) {
        guard bill.isAlertEnabled, !bill.isPaid else {
            cancelReminder(forBillId: bill.id)
            return
        }

        guard let triggerDate = reminderDate(oneDayBefore: bill.billDate) else {
            cancelReminder(forBillId: bill.id)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Bill due tomorrow"
        content.body = "\(bill.name) of \(AppFormatters.currency(bill.amount)) is due tomorrow."
        content.sound = .default
        content.userInfo = [
            "type": "bill",
            "id": bill.id.uuidString
        ]

        scheduleNotification(
            identifier: billIdentifier(for: bill.id),
            content: content,
            triggerDate: triggerDate
        )
    }

    func scheduleReminder(for payment: RecurringPayment) {
        guard payment.isAlertEnabled, payment.isActive, !payment.isIncome else {
            cancelReminder(forSubscriptionId: payment.id)
            return
        }

        guard let triggerDate = reminderDate(oneDayBefore: payment.nextDate) else {
            cancelReminder(forSubscriptionId: payment.id)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Subscription due tomorrow"
        content.body = "\(payment.name) of \(AppFormatters.currency(payment.amount)) is due tomorrow."
        content.sound = .default
        content.userInfo = [
            "type": "subscription",
            "id": payment.id.uuidString
        ]

        scheduleNotification(
            identifier: subscriptionIdentifier(for: payment.id),
            content: content,
            triggerDate: triggerDate
        )
    }

    func cancelReminder(forBillId id: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [billIdentifier(for: id)])
    }

    func cancelReminder(forSubscriptionId id: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [subscriptionIdentifier(for: id)])
    }

    func cancelAllManagedReminders(completion: (() -> Void)? = nil) {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self else {
                completion?()
                return
            }

            let identifiers = requests
                .map(\.identifier)
                .filter {
                    $0.hasPrefix(self.billPrefix) ||
                    $0.hasPrefix(self.subscriptionPrefix)
                }

            if !identifiers.isEmpty {
                self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            }

            completion?()
        }
    }

    private func scheduleNotification(
        identifier: String,
        content: UNNotificationContent,
        triggerDate: Date
    ) {
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.add(request)
    }

    private func reminderDate(oneDayBefore dueDate: Date) -> Date? {
        let calendar = Calendar.current
        let dueDay = calendar.startOfDay(for: dueDate)

        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: dueDay),
              let reminderDate = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: previousDay)
        else {
            return nil
        }

        return reminderDate > Date() ? reminderDate : nil
    }

    private func billIdentifier(for id: UUID) -> String {
        billPrefix + id.uuidString
    }

    private func subscriptionIdentifier(for id: UUID) -> String {
        subscriptionPrefix + id.uuidString
    }
}
