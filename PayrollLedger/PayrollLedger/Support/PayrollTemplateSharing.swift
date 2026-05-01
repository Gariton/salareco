import Foundation
import SwiftData

struct PayrollTemplateSharePayload: Codable {
    struct SharedLineItem: Codable {
        var name: String
        var amount: Double
        var sortOrder: Int
    }

    var version: Int = 1
    var exportedAt: Date = .now
    var templateName: String
    var kindRawValue: String
    var sourceName: String
    var sourceAccentHex: String
    var note: String
    var paymentItems: [SharedLineItem]
    var deductionItems: [SharedLineItem]

    init(template: PayrollTemplate, source: IncomeSource?) {
        templateName = template.name
        kindRawValue = template.kind.rawValue
        sourceName = source?.name ?? PayrollLocalization.text("共有された支給元")
        sourceAccentHex = source?.accentHex ?? "#0F766E"
        note = template.note
        paymentItems = template.paymentItems.map {
            SharedLineItem(name: $0.name, amount: $0.amount, sortOrder: $0.sortOrder)
        }
        deductionItems = template.deductionItems.map {
            SharedLineItem(name: $0.name, amount: $0.amount, sortOrder: $0.sortOrder)
        }
    }
}

enum PayrollTemplateShareCodec {
    static let urlScheme = "payrollledger"

    enum Error: LocalizedError {
        case invalidSharedData
        case unsupportedLink
        case noPaymentItems

        var errorDescription: String? {
            switch self {
            case .invalidSharedData:
                PayrollLocalization.text("共有リンクを読み込めませんでした。届いたリンクをそのまま開くか、リンク欄へ貼り付けてください。")
            case .unsupportedLink:
                PayrollLocalization.text("このリンクはテンプレート共有用ではありません。")
            case .noPaymentItems:
                PayrollLocalization.text("支給項目が含まれていないため、このテンプレートは読み込めません。")
            }
        }
    }

    enum ImportError: LocalizedError {
        case missingSource

        var errorDescription: String? {
            switch self {
            case .missingSource:
                PayrollLocalization.text("選択した支給元が見つかりませんでした。もう一度選択してください。")
            }
        }
    }

    static func exportText(for template: PayrollTemplate, source: IncomeSource?) -> String {
        let payload = PayrollTemplateSharePayload(template: template, source: source)
        return exportText(for: payload)
    }

    static func exportURL(for template: PayrollTemplate, source: IncomeSource?) -> URL {
        let payload = PayrollTemplateSharePayload(template: template, source: source)
        let payloadToken = encodedPayloadToken(for: payload)
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "template-import"
        components.queryItems = [
            URLQueryItem(name: "payload", value: payloadToken)
        ]

        return components.url
            ?? URL(string: "\(urlScheme)://template-import")!
    }

    static func importTemplate(
        from url: URL,
        existingSources: [IncomeSource],
        existingTemplates: [PayrollTemplate],
        in modelContext: ModelContext
    ) throws -> PayrollTemplate {
        let payload = try payload(from: url)
        return try importTemplate(
            from: payload,
            existingSources: existingSources,
            existingTemplates: existingTemplates,
            in: modelContext
        )
    }

    static func importTemplate(
        from sharedValue: String,
        existingSources: [IncomeSource],
        existingTemplates: [PayrollTemplate],
        in modelContext: ModelContext
    ) throws -> PayrollTemplate {
        let payload = try payload(from: sharedValue)
        return try importTemplate(
            from: payload,
            existingSources: existingSources,
            existingTemplates: existingTemplates,
            in: modelContext
        )
    }

    static func importTemplate(
        from payload: PayrollTemplateSharePayload,
        source: IncomeSource,
        existingTemplates: [PayrollTemplate],
        in modelContext: ModelContext
    ) throws -> PayrollTemplate {
        try importTemplate(
            from: payload,
            selectedSource: source,
            existingTemplates: existingTemplates,
            in: modelContext
        )
    }

    static func incomeSource(from payload: PayrollTemplateSharePayload) -> IncomeSource {
        IncomeSource(
            name: sourceName(for: payload),
            accentHex: sourceAccentHex(for: payload)
        )
    }

    static func sourceName(for payload: PayrollTemplateSharePayload) -> String {
        normalizedSourceName(for: payload)
    }

    static func sourceAccentHex(for payload: PayrollTemplateSharePayload) -> String {
        payload.sourceAccentHex.trimmed.isEmpty ? "#0F766E" : payload.sourceAccentHex
    }

    static func importWouldCreateNewSource(
        from url: URL,
        existingSources: [IncomeSource]
    ) throws -> Bool {
        try importWouldCreateNewSource(
            from: payload(from: url),
            existingSources: existingSources
        )
    }

    static func importWouldCreateNewSource(
        from sharedValue: String,
        existingSources: [IncomeSource]
    ) throws -> Bool {
        try importWouldCreateNewSource(
            from: payload(from: sharedValue),
            existingSources: existingSources
        )
    }

    private static func exportText(for payload: PayrollTemplateSharePayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(payload)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    private static func importTemplate(
        from payload: PayrollTemplateSharePayload,
        existingSources: [IncomeSource],
        existingTemplates: [PayrollTemplate],
        in modelContext: ModelContext
    ) throws -> PayrollTemplate {
        guard !payload.paymentItems.isEmpty else {
            throw Error.noPaymentItems
        }

        let normalizedSourceName = normalizedSourceName(for: payload)
        let selectedSource: IncomeSource
        if let existingSource = existingSources.first(where: {
            $0.name.trimmed.localizedCaseInsensitiveCompare(normalizedSourceName) == .orderedSame
        }) {
            selectedSource = existingSource
        } else {
            let newSource = IncomeSource(
                name: normalizedSourceName,
                accentHex: payload.sourceAccentHex.isEmpty ? "#0F766E" : payload.sourceAccentHex
            )
            modelContext.insert(newSource)
            selectedSource = newSource
        }

        return try importTemplate(
            from: payload,
            selectedSource: selectedSource,
            existingTemplates: existingTemplates,
            in: modelContext
        )
    }

    private static func importTemplate(
        from payload: PayrollTemplateSharePayload,
        selectedSource: IncomeSource,
        existingTemplates: [PayrollTemplate],
        in modelContext: ModelContext
    ) throws -> PayrollTemplate {
        guard !payload.paymentItems.isEmpty else {
            throw Error.noPaymentItems
        }

        let templateName = uniqueTemplateName(
            base: payload.templateName.trimmed.isEmpty ? PayrollLocalization.text("共有テンプレート") : payload.templateName.trimmed,
            existingTemplates: existingTemplates
        )
        let template = PayrollTemplate(
            name: templateName,
            kind: PayrollRecordKind(rawValue: payload.kindRawValue) ?? .salary,
            note: payload.note.trimmed,
            source: selectedSource
        )
        modelContext.insert(template)

        let paymentItems = payload.paymentItems.enumerated().map { offset, item in
            PayrollLineItem(
                name: item.name.trimmed,
                amount: item.amount,
                categoryRawValue: PayrollLineItemCategory.payment.rawValue,
                sortOrder: item.sortOrder == 0 ? offset : item.sortOrder
            )
        }
        let deductionItems = payload.deductionItems.enumerated().map { offset, item in
            PayrollLineItem(
                name: item.name.trimmed,
                amount: item.amount,
                categoryRawValue: PayrollLineItemCategory.deduction.rawValue,
                sortOrder: item.sortOrder == 0 ? offset : item.sortOrder
            )
        }

        template.replaceLineItems(with: paymentItems + deductionItems, in: modelContext)
        try modelContext.save()
        return template
    }

    private static func importWouldCreateNewSource(
        from payload: PayrollTemplateSharePayload,
        existingSources: [IncomeSource]
    ) throws -> Bool {
        let sourceName = normalizedSourceName(for: payload)
        return !existingSources.contains {
            $0.name.trimmed.localizedCaseInsensitiveCompare(sourceName) == .orderedSame
        }
    }

    private static func normalizedSourceName(for payload: PayrollTemplateSharePayload) -> String {
        payload.sourceName.trimmed.isEmpty ? PayrollLocalization.text("共有された支給元") : payload.sourceName.trimmed
    }

    static func payload(from sharedValue: String) throws -> PayrollTemplateSharePayload {
        let trimmedValue = sharedValue.trimmed
        guard !trimmedValue.isEmpty else {
            throw Error.invalidSharedData
        }

        if let url = URL(string: trimmedValue), url.scheme != nil {
            return try payload(from: url)
        }

        guard let data = trimmedValue.data(using: .utf8),
              let payload = try? payloadDecoder.decode(PayrollTemplateSharePayload.self, from: data) else {
            throw Error.invalidSharedData
        }

        return payload
    }

    static func payload(from url: URL) throws -> PayrollTemplateSharePayload {
        guard url.scheme?.lowercased() == urlScheme else {
            throw Error.unsupportedLink
        }

        guard url.host?.lowercased() == "template-import" else {
            throw Error.unsupportedLink
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let payloadToken = components.queryItems?.first(where: { $0.name == "payload" })?.value else {
            throw Error.invalidSharedData
        }

        guard let payloadData = decodePayloadToken(payloadToken),
              let payload = try? payloadDecoder.decode(PayrollTemplateSharePayload.self, from: payloadData) else {
            throw Error.invalidSharedData
        }

        return payload
    }

    private static var payloadDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func encodedPayloadToken(for payload: PayrollTemplateSharePayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(payload)) ?? Data()
        return data.base64URLEncodedString()
    }

    private static func decodePayloadToken(_ token: String) -> Data? {
        Data(base64URLEncoded: token)
    }

    private static func uniqueTemplateName(
        base: String,
        existingTemplates: [PayrollTemplate]
    ) -> String {
        let existingNames = Set(existingTemplates.map { $0.name.trimmed.lowercased() })
        guard existingNames.contains(base.lowercased()) else {
            return base
        }

        let suffixBase = base + PayrollLocalization.text(" (共有)")
        guard existingNames.contains(suffixBase.lowercased()) else {
            return suffixBase
        }

        var index = 2
        while existingNames.contains("\(suffixBase) \(index)".lowercased()) {
            index += 1
        }
        return "\(suffixBase) \(index)"
    }
}

struct PayrollRecordSharePayload: Codable {
    enum AmountVisibility: String, Codable {
        case hidden
        case totals
        case breakdown
    }

    struct SharedLineItem: Codable, Identifiable {
        var name: String
        var amount: Double
        var sortOrder: Int

        var id: String {
            "\(sortOrder)-\(name)"
        }
    }

    struct SharedWorkHourEntry: Codable, Identifiable {
        var name: String
        var hours: Double
        var sortOrder: Int

        var id: String {
            "\(sortOrder)-\(name)"
        }
    }

    var version: Int = 1
    var exportedAt: Date = .now
    var kindRawValue: String
    var periodYear: Int
    var periodMonth: Int
    var paymentDate: Date
    var sourceName: String?
    var sourceAccentHex: String
    var note: String?
    var isSourceNameHidden: Bool
    var isNoteHidden: Bool
    var amountVisibility: AmountVisibility
    var totalPayments: Double?
    var totalDeductions: Double?
    var netAmount: Double?
    var paymentItemCount: Int
    var deductionItemCount: Int
    var workHourItemCount: Int
    var paymentItems: [SharedLineItem]
    var deductionItems: [SharedLineItem]
    var workHourEntries: [SharedWorkHourEntry]

    init(record: PayrollRecord, source: IncomeSource?, privacyOptions: SharePrivacyOptions) {
        kindRawValue = record.kind.rawValue
        periodYear = record.periodYear
        periodMonth = record.periodMonth
        paymentDate = record.paymentDate

        let sourceName = source?.name.trimmed
        if privacyOptions.hideSourceName {
            self.sourceName = nil
            sourceAccentHex = "#0F766E"
            isSourceNameHidden = !(sourceName ?? "").isEmpty
        } else {
            self.sourceName = (sourceName ?? "").isEmpty ? PayrollLocalization.text("未設定") : sourceName
            sourceAccentHex = source?.accentHex ?? "#0F766E"
            isSourceNameHidden = false
        }

        let trimmedNote = record.note.trimmed
        if privacyOptions.hideNotes || trimmedNote.isEmpty {
            note = nil
        } else {
            note = trimmedNote
        }
        isNoteHidden = privacyOptions.hideNotes && !trimmedNote.isEmpty

        if privacyOptions.hideAmounts {
            amountVisibility = .hidden
            totalPayments = nil
            totalDeductions = nil
            netAmount = nil
            paymentItems = []
            deductionItems = []
            workHourEntries = []
        } else if privacyOptions.hideBreakdown {
            amountVisibility = .totals
            totalPayments = record.totalPayments
            totalDeductions = record.totalDeductions
            netAmount = record.netAmount
            paymentItems = []
            deductionItems = []
            workHourEntries = []
        } else {
            amountVisibility = .breakdown
            totalPayments = record.totalPayments
            totalDeductions = record.totalDeductions
            netAmount = record.netAmount
            paymentItems = record.paymentItems.map {
                SharedLineItem(name: $0.name.trimmed, amount: $0.amount, sortOrder: $0.sortOrder)
            }
            deductionItems = record.deductionItems.map {
                SharedLineItem(name: $0.name.trimmed, amount: $0.amount, sortOrder: $0.sortOrder)
            }
            workHourEntries = record.sortedWorkHourEntries.map {
                SharedWorkHourEntry(name: $0.name.trimmed, hours: $0.hours, sortOrder: $0.sortOrder)
            }
        }

        paymentItemCount = record.paymentItems.count
        deductionItemCount = record.deductionItems.count
        workHourItemCount = record.sortedWorkHourEntries.count
    }
}

extension PayrollRecordSharePayload {
    var kind: PayrollRecordKind {
        PayrollRecordKind(rawValue: kindRawValue) ?? .salary
    }

    var titleText: String {
        PayrollLocalization.recordTitle(
            year: periodYear,
            month: periodMonth,
            kindTitle: kind.title
        )
    }

    var accentHex: String {
        sourceAccentHex.trimmed.isEmpty ? "#0F766E" : sourceAccentHex
    }

    var displaySourceName: String? {
        guard let sourceName, !sourceName.trimmed.isEmpty else {
            return nil
        }

        return sourceName
    }

    var totalWorkHours: Double {
        workHourEntries.reduce(0) { $0 + $1.hours }
    }

    var privacyBadges: [String] {
        var badges: [String] = []

        if isSourceNameHidden {
            badges.append(PayrollLocalization.text("支給元名を非公開"))
        }

        switch amountVisibility {
        case .hidden:
            badges.append(PayrollLocalization.text("金額を非公開"))
        case .totals:
            badges.append(PayrollLocalization.text("内訳を非公開"))
        case .breakdown:
            break
        }

        if isNoteHidden {
            badges.append(PayrollLocalization.text("メモを非公開"))
        }

        return badges
    }
}

enum PayrollRecordShareCodec {
    static let urlScheme = PayrollTemplateShareCodec.urlScheme

    enum Error: LocalizedError {
        case invalidSharedData
        case unsupportedLink

        var errorDescription: String? {
            switch self {
            case .invalidSharedData:
                PayrollLocalization.text("共有された給与データを読み込めませんでした。届いたリンクをそのまま開いてください。")
            case .unsupportedLink:
                PayrollLocalization.text("このリンクは給与データ共有用ではありません。")
            }
        }
    }

    static func sharePayload(
        for record: PayrollRecord,
        source: IncomeSource?,
        privacyOptions: SharePrivacyOptions
    ) -> PayrollRecordSharePayload {
        PayrollRecordSharePayload(record: record, source: source, privacyOptions: privacyOptions)
    }

    static func exportURL(
        for record: PayrollRecord,
        source: IncomeSource?,
        privacyOptions: SharePrivacyOptions
    ) -> URL {
        let payload = sharePayload(
            for: record,
            source: source,
            privacyOptions: privacyOptions
        )
        let payloadToken = encodedPayloadToken(for: payload)
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "record-share"
        components.queryItems = [
            URLQueryItem(name: "payload", value: payloadToken)
        ]

        return components.url
            ?? URL(string: "\(urlScheme)://record-share")!
    }

    static func payload(from url: URL) throws -> PayrollRecordSharePayload {
        guard url.scheme?.lowercased() == urlScheme else {
            throw Error.unsupportedLink
        }

        guard url.host?.lowercased() == "record-share" else {
            throw Error.unsupportedLink
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let payloadToken = components.queryItems?.first(where: { $0.name == "payload" })?.value else {
            throw Error.invalidSharedData
        }

        guard let payloadData = decodePayloadToken(payloadToken),
              let payload = try? payloadDecoder.decode(PayrollRecordSharePayload.self, from: payloadData) else {
            throw Error.invalidSharedData
        }

        return payload
    }

    private static var payloadDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func encodedPayloadToken(for payload: PayrollRecordSharePayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(payload)) ?? Data()
        return data.base64URLEncodedString()
    }

    private static func decodePayloadToken(_ token: String) -> Data? {
        Data(base64URLEncoded: token)
    }
}

private extension Data {
    init?(base64URLEncoded string: String) {
        var value = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = value.count % 4
        if remainder != 0 {
            value += String(repeating: "=", count: 4 - remainder)
        }

        self.init(base64Encoded: value)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
