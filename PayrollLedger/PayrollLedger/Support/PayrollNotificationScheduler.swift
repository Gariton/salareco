import Foundation
import UserNotifications

enum PayrollNotificationScheduler {
    private static let managedIdentifierPrefix = "payroll.source.reminder."
    private static let notificationHour = 9

    static func refreshNotifications(
        for sources: [IncomeSource],
        requestingAuthorization: Bool = false
    ) async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await pendingNotificationRequests(in: center)
        let managedIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(managedIdentifierPrefix) }

        if !managedIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: managedIdentifiers)
        }

        let requests = makeRequests(for: sources)
        guard !requests.isEmpty else {
            return
        }

        let isAuthorized = await authorizationAvailable(
            in: center,
            requestingAuthorization: requestingAuthorization
        )
        guard isAuthorized else {
            return
        }

        for request in requests {
            try? await add(request, to: center)
        }
    }

    private static func makeRequests(for sources: [IncomeSource]) -> [UNNotificationRequest] {
        sources.flatMap { source in
            let paymentDay = normalized(day: source.salaryPaymentDay)
            let announcementDay = normalized(day: source.salaryAnnouncementDay)

            switch (paymentDay, announcementDay) {
            case let (paymentDay?, announcementDay?) where paymentDay == announcementDay:
                return [request(for: source, kind: .combined, day: paymentDay)]
            case let (paymentDay?, announcementDay?):
                return [
                    request(for: source, kind: .announcement, day: announcementDay),
                    request(for: source, kind: .payment, day: paymentDay),
                ]
            case let (paymentDay?, nil):
                return [request(for: source, kind: .payment, day: paymentDay)]
            case let (nil, announcementDay?):
                return [request(for: source, kind: .announcement, day: announcementDay)]
            case (nil, nil):
                return []
            }
        }
    }

    private static func request(
        for source: IncomeSource,
        kind: ReminderKind,
        day: Int
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = kind.title(for: source.name)
        content.body = kind.body(for: source.name)
        content.sound = .default
        content.userInfo = [
            "sourceID": source.id.uuidString,
            "reminderKind": kind.rawValue,
        ]

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.day = day
        components.hour = notificationHour

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(
            identifier: managedIdentifierPrefix + source.id.uuidString + "." + kind.rawValue,
            content: content,
            trigger: trigger
        )
    }

    private static func normalized(day: Int?) -> Int? {
        guard let day else {
            return nil
        }

        return min(max(day, 1), 31)
    }

    private static func authorizationAvailable(
        in center: UNUserNotificationCenter,
        requestingAuthorization: Bool
    ) async -> Bool {
        let settings = await notificationSettings(in: center)
        if allowsScheduling(for: settings.authorizationStatus) {
            return true
        }

        guard requestingAuthorization, settings.authorizationStatus == .notDetermined else {
            return false
        }

        return await requestAuthorization(in: center)
    }

    private static func allowsScheduling(for status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            true
        default:
            false
        }
    }

    private static func notificationSettings(
        in center: UNUserNotificationCenter
    ) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private static func requestAuthorization(
        in center: UNUserNotificationCenter
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func pendingNotificationRequests(
        in center: UNUserNotificationCenter
    ) async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private static func add(
        _ request: UNNotificationRequest,
        to center: UNUserNotificationCenter
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

private enum ReminderKind: String {
    case payment
    case announcement
    case combined

    func title(for sourceName: String) -> String {
        switch self {
        case .payment:
            return PayrollLocalization.format("%@ の給与支給日です", sourceName)
        case .announcement:
            return PayrollLocalization.format("%@ の給与開示日です", sourceName)
        case .combined:
            return PayrollLocalization.format("%@ の給与確認日です", sourceName)
        }
    }

    func body(for sourceName: String) -> String {
        switch self {
        case .payment:
            return PayrollLocalization.format(
                "今日は %@ の給与支給日です。今月もおつかれさまでした。記録を残して振り返りましょう。",
                sourceName
            )
        case .announcement:
            return PayrollLocalization.format(
                "今日は %@ の給与開示日です。明細を確認して、今月の給与を登録しましょう。",
                sourceName
            )
        case .combined:
            return PayrollLocalization.format(
                "今日は %@ の給与開示日と支給日です。明細を確認して登録し、今月もおつかれさまでした。",
                sourceName
            )
        }
    }
}
