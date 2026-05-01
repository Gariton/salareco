import Foundation

enum PayrollCSVExporter {
    static func exportURL(
        for records: [PayrollRecord],
        sources: [IncomeSource],
        title: String
    ) throws -> URL {
        let csvText = makeCSVText(for: records, sources: sources)
        let fileName = sanitizedFileName(from: title) + "-" + timestampText() + ".csv"
        let url = FileManager.default.temporaryDirectory.appending(path: fileName)

        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(csvText.utf8))
        try data.write(to: url, options: .atomic)

        return url
    }

    private static func makeCSVText(
        for records: [PayrollRecord],
        sources: [IncomeSource]
    ) -> String {
        let headers = [
            PayrollLocalization.text("支給元"),
            PayrollLocalization.text("種別"),
            PayrollLocalization.text("対象年"),
            PayrollLocalization.text("対象月"),
            PayrollLocalization.text("支給日"),
            PayrollLocalization.text("支給合計"),
            PayrollLocalization.text("控除合計"),
            PayrollLocalization.text("手取り"),
            PayrollLocalization.text("勤務時間合計"),
            PayrollLocalization.text("支給項目"),
            PayrollLocalization.text("控除項目"),
            PayrollLocalization.text("勤務時間項目"),
            PayrollLocalization.text("メモ"),
        ]

        let rows = records.map { record in
            [
                record.source(in: sources)?.name ?? PayrollLocalization.text("支給元未設定"),
                record.kind.title,
                String(record.periodYear),
                String(record.periodMonth),
                dateText(record.paymentDate),
                amountText(record.totalPayments),
                amountText(record.totalDeductions),
                amountText(record.netAmount),
                hourText(record.totalWorkHours),
                lineItemText(record.paymentItems),
                lineItemText(record.deductionItems),
                workHourText(record.sortedWorkHourEntries),
                record.note,
            ]
        }

        return ([headers] + rows)
            .map { $0.map(escaped).joined(separator: ",") }
            .joined(separator: "\n")
    }

    private static func escaped(_ value: String) -> String {
        let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedValue)\""
    }

    private static func lineItemText(_ items: [PayrollLineItem]) -> String {
        items.map { item in
            item.name + ": " + amountText(item.amount)
        }
        .joined(separator: " / ")
    }

    private static func workHourText(_ entries: [PayrollWorkHourEntry]) -> String {
        entries.map { entry in
            entry.name + ": " + hourText(entry.hours)
        }
        .joined(separator: " / ")
    }

    private static func amountText(_ amount: Double) -> String {
        String(format: "%.0f", amount)
    }

    private static func hourText(_ hours: Double) -> String {
        String(format: "%.2f", hours)
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = PayrollLocalization.locale
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private static func timestampText() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }

    private static func sanitizedFileName(from title: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = title.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : "-"
        }
        let name = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return name.isEmpty ? "payroll-records" : name
    }
}
