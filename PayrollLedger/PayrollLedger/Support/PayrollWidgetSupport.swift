import Foundation

struct PayrollWidgetSnapshot: Codable {
    struct LatestRecord: Codable {
        var id: UUID
        var kindRawValue: String
        var sourceName: String
        var sourceAccentHex: String
        var paymentDate: Date
        var periodYear: Int
        var periodMonth: Int
        var netAmount: Double
        var totalPayments: Double
        var totalDeductions: Double
    }

    var generatedAt: Date
    var currentYear: Int
    var yearNetTotal: Double
    var yearPaymentTotal: Double
    var yearDeductionTotal: Double
    var recordCount: Int
    var sourceCount: Int
    var latestRecord: LatestRecord?
}

extension PayrollWidgetSnapshot {
    static let placeholder = PayrollWidgetSnapshot(
        generatedAt: .now,
        currentYear: Calendar.current.component(.year, from: .now),
        yearNetTotal: 2_840_000,
        yearPaymentTotal: 3_420_000,
        yearDeductionTotal: 580_000,
        recordCount: 11,
        sourceCount: 1,
        latestRecord: LatestRecord(
            id: UUID(),
            kindRawValue: "salary",
            sourceName: PayrollLocalization.text("給与口座"),
            sourceAccentHex: "#0F766E",
            paymentDate: .now,
            periodYear: Calendar.current.component(.year, from: .now),
            periodMonth: Calendar.current.component(.month, from: .now),
            netAmount: 258_400,
            totalPayments: 312_000,
            totalDeductions: 53_600
        )
    )
}

enum PayrollWidgetStore {
    static let snapshotKey = "payroll.widget.snapshot"
    static let isSensitiveInformationRevealedKey = "payroll.widget.isSensitiveInformationRevealed"
    static let fallbackAppGroupIdentifier = "group.com.example.PayrollLedger.shared"

    static func load(bundle: Bundle = .main) -> PayrollWidgetSnapshot? {
        guard let defaults = sharedDefaults(bundle: bundle),
              let data = defaults.data(forKey: snapshotKey) else {
            return nil
        }

        return try? JSONDecoder().decode(PayrollWidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: PayrollWidgetSnapshot, bundle: Bundle = .main) {
        guard let defaults = sharedDefaults(bundle: bundle),
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        defaults.set(data, forKey: snapshotKey)
    }

    static func isSensitiveInformationRevealed(bundle: Bundle = .main) -> Bool {
        sharedDefaults(bundle: bundle)?.bool(forKey: isSensitiveInformationRevealedKey) ?? false
    }

    @discardableResult
    static func toggleSensitiveInformationVisibility(bundle: Bundle = .main) -> Bool {
        let newValue = !isSensitiveInformationRevealed(bundle: bundle)
        setSensitiveInformationRevealed(newValue, bundle: bundle)
        return newValue
    }

    static func setSensitiveInformationRevealed(_ isRevealed: Bool, bundle: Bundle = .main) {
        sharedDefaults(bundle: bundle)?.set(isRevealed, forKey: isSensitiveInformationRevealedKey)
    }

    static func appGroupIdentifier(bundle: Bundle = .main) -> String {
        if let configuredIdentifier = bundle.object(
            forInfoDictionaryKey: "PayrollAppGroupIdentifier"
        ) as? String, !configuredIdentifier.isEmpty {
            return configuredIdentifier
        }

        return fallbackAppGroupIdentifier
    }

    private static func sharedDefaults(bundle: Bundle) -> UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier(bundle: bundle))
    }
}
