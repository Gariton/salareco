import Foundation

extension Double {
    var currencyText: String {
        formatted(
            .currency(code: "JPY")
                .locale(PayrollLocalization.locale)
                .precision(.fractionLength(0))
        )
    }

    var compactCurrencyText: String {
        if #available(iOS 18.0, *) {
            return formatted(
                .currency(code: "JPY")
                    .locale(PayrollLocalization.locale)
                    .precision(.fractionLength(0))
                    .notation(.compactName)
            )
        }

        return currencyText
    }

    var hourText: String {
        let value = formatted(
            .number
                .locale(PayrollLocalization.locale)
                .precision(.fractionLength(0...2))
        )
        return PayrollLocalization.format("%@時間", value)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Date {
    var mediumJapaneseDateText: String {
        formatted(.dateTime.year().month(.abbreviated).day().locale(PayrollLocalization.locale))
    }

    var monthDayJapaneseDateText: String {
        formatted(.dateTime.month(.abbreviated).day().locale(PayrollLocalization.locale))
    }

    var mediumJapaneseDateTimeText: String {
        formatted(
            .dateTime
                .year()
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
                .locale(PayrollLocalization.locale)
        )
    }
}

extension Int {
    var monthDisplayText: String {
        PayrollLocalization.monthLabel(self, abbreviated: true)
    }

    var plainText: String {
        String(self)
    }

    var yearDisplayText: String {
        PayrollLocalization.yearLabel(self)
    }
}
