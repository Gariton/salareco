import Foundation
import Vision

struct PayrollSlipImportResult {
    var kind: PayrollRecordKind
    var paymentDate: Date
    var sourceID: UUID?
    var note: String
    var paymentItems: [EditableLineItem]
    var deductionItems: [EditableLineItem]
}

enum PayrollSlipImportError: LocalizedError {
    case imageLoadFailed
    case noTextRecognized
    case noItemsRecognized

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed:
            PayrollLocalization.text("画像データを読み込めませんでした。")
        case .noTextRecognized:
            PayrollLocalization.text("写真から文字を認識できませんでした。明細全体が見える画像を選んでください。")
        case .noItemsRecognized:
            PayrollLocalization.text("文字は読めましたが、支給項目や控除項目を抽出できませんでした。")
        }
    }
}

enum PayrollSlipImportService {
    static func importRecordDraft(
        from imageData: Data,
        fallbackKind: PayrollRecordKind,
        sourceID: UUID?
    ) async throws -> PayrollSlipImportResult {
        let recognizedText = try recognizeText(from: imageData)
        return try parseRecognizedText(recognizedText, fallbackKind: fallbackKind, sourceID: sourceID)
    }

    private static func recognizeText(from imageData: Data) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(data: imageData, options: [:])
        try handler.perform([request])

        let observations = (request.results ?? [])
            .sorted {
                if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.02 {
                    return $0.boundingBox.midY > $1.boundingBox.midY
                }

                return $0.boundingBox.minX < $1.boundingBox.minX
            }

        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw PayrollSlipImportError.noTextRecognized
        }

        return text
    }

    private static func parseRecognizedText(
        _ text: String,
        fallbackKind: PayrollRecordKind,
        sourceID: UUID?
    ) throws -> PayrollSlipImportResult {
        let lines = text
            .components(separatedBy: .newlines)
            .map(normalize)
            .filter { !$0.isEmpty }

        let detectedKind = detectRecordKind(in: text, fallbackKind: fallbackKind)
        let paymentDate = detectPaymentDate(in: text) ?? .now

        let categorizedItems = extractLineItems(from: lines)

        guard !categorizedItems.payments.isEmpty else {
            throw PayrollSlipImportError.noItemsRecognized
        }

        let notePrefix = PayrollLocalization.text("明細写真から抽出")
        let note = lines.contains(where: { $0.contains("賞与") })
            ? PayrollLocalization.format("%1$@ / %2$@", notePrefix, PayrollLocalization.text("賞与明細"))
            : notePrefix

        return PayrollSlipImportResult(
            kind: detectedKind,
            paymentDate: paymentDate,
            sourceID: sourceID,
            note: note,
            paymentItems: categorizedItems.payments,
            deductionItems: categorizedItems.deductions
        )
    }

    private static func detectRecordKind(in text: String, fallbackKind: PayrollRecordKind) -> PayrollRecordKind {
        let normalized = normalize(text)
        if normalized.contains("賞与") || normalized.localizedCaseInsensitiveContains("bonus") {
            return .bonus
        }

        return fallbackKind
    }

    private static func detectPaymentDate(in text: String) -> Date? {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.date.rawValue
        ) else {
            return nil
        }

        return detector.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ).compactMap(\.date).first
    }

    private static func extractLineItems(from lines: [String]) -> (payments: [EditableLineItem], deductions: [EditableLineItem]) {
        var currentSection: PayrollLineItemCategory?
        var paymentItems: [EditableLineItem] = []
        var deductionItems: [EditableLineItem] = []
        var seenKeys = Set<String>()

        for line in lines {
            if containsAny(in: line, keywords: ["支給明細", "支給項目", "支給内訳"]) {
                currentSection = .payment
                continue
            }

            if containsAny(in: line, keywords: ["控除明細", "控除項目", "控除内訳"]) {
                currentSection = .deduction
                continue
            }

            if containsAny(in: line, keywords: [
                "総支給",
                "支給合計",
                "控除合計",
                "差引支給額",
                "差引",
                "手取り",
                "合計"
            ]) {
                continue
            }

            guard let amount = extractAmount(from: line) else {
                continue
            }

            let label = cleanLabel(from: line)
            guard !label.isEmpty else {
                continue
            }

            let category = inferCategory(for: label, currentSection: currentSection)
            guard let category else {
                continue
            }

            let dedupeKey = "\(category.rawValue)|\(label)"
            guard seenKeys.insert(dedupeKey).inserted else {
                continue
            }

            let item = EditableLineItem(name: label, amount: amount)
            switch category {
            case .payment:
                paymentItems.append(item)
            case .deduction:
                deductionItems.append(item)
            }
        }

        return (paymentItems, deductionItems)
    }

    private static func inferCategory(
        for label: String,
        currentSection: PayrollLineItemCategory?
    ) -> PayrollLineItemCategory? {
        if containsAny(in: label, keywords: [
            "健康保険",
            "介護保険",
            "厚生年金",
            "雇用保険",
            "所得税",
            "住民税",
            "源泉",
            "社会保険",
            "控除",
            "組合費"
        ]) {
            return .deduction
        }

        if containsAny(in: label, keywords: [
            "基本給",
            "給与",
            "賞与",
            "手当",
            "通勤",
            "住宅",
            "残業",
            "役職",
            "非課税",
            "課税",
            "報酬"
        ]) {
            return .payment
        }

        return currentSection
    }

    private static func extractAmount(from line: String) -> Double? {
        let pattern = #"(?<!\d)(\d{1,3}(?:,\d{3})+|\d{3,})(?:円)?(?!\d)"#
        guard let match = firstMatch(for: pattern, in: line), match.count >= 2 else {
            return nil
        }

        return Double(match[1].replacingOccurrences(of: ",", with: ""))
    }

    private static func cleanLabel(from line: String) -> String {
        let amountPattern = #"(?<!\d)(\d{1,3}(?:,\d{3})+|\d{3,})(?:円)?(?!\d)"#
        var label = replacingFirstMatch(for: amountPattern, in: line, with: "")
        label = replacingFirstMatch(for: #"(20\d{2}|19\d{2})\D{0,3}(1[0-2]|0?[1-9])\D{0,3}(?:[0-3]?\d)?\D*"#, in: label, with: "")
        label = label.replacingOccurrences(of: "¥", with: "")
        label = label.replacingOccurrences(of: "円", with: "")
        label = label.replacingOccurrences(of: ":", with: "")
        label = label.replacingOccurrences(of: "：", with: "")
        return label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{3000}", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #" +"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(in text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func firstMatch(for pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        return (0..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else {
                return nil
            }

            return String(text[range])
        }
    }

    private static func replacingFirstMatch(
        for pattern: String,
        in text: String,
        with replacement: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}
