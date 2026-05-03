import Foundation
import UIKit

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
    case apiKeyMissing
    case apiRequestFailed(String)
    case invalidAIResponse
    case noItemsRecognized

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed:
            PayrollLocalization.text("画像データを読み込めませんでした。")
        case .apiKeyMissing:
            PayrollLocalization.text("OpenAI APIキーが設定されていません。")
        case .apiRequestFailed(let message):
            PayrollLocalization.format("AI読み取りに失敗しました。%@", message)
        case .invalidAIResponse:
            PayrollLocalization.text("AI読み取り結果を解析できませんでした。")
        case .noItemsRecognized:
            PayrollLocalization.text("明細写真から支給項目や控除項目を抽出できませんでした。")
        }
    }
}

enum PayrollSlipImportService {
    private static let responseEndpoint = URL(string: "https://api.openai.com/v1/responses")!
    private static let imageMaxDimension: CGFloat = 2048
    private static let jpegCompressionQuality: CGFloat = 0.88

    static func importRecordDraft(
        from imageData: Data,
        fallbackKind: PayrollRecordKind,
        sourceID: UUID?
    ) async throws -> PayrollSlipImportResult {
        guard let apiKey = OpenAIConfiguration.apiKey else {
            throw PayrollSlipImportError.apiKeyMissing
        }

        let jpegData = try prepareJPEGData(from: imageData)
        let extraction = try await extractPayrollSlip(
            from: jpegData,
            apiKey: apiKey,
            fallbackKind: fallbackKind
        )

        return try makeImportResult(
            from: extraction,
            fallbackKind: fallbackKind,
            sourceID: sourceID
        )
    }

    private static func extractPayrollSlip(
        from imageData: Data,
        apiKey: String,
        fallbackKind: PayrollRecordKind
    ) async throws -> AIImportPayload {
        var request = URLRequest(url: responseEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try makeRequestBody(imageData: imageData, fallbackKind: fallbackKind)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PayrollSlipImportError.invalidAIResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PayrollSlipImportError.apiRequestFailed(errorMessage(from: data))
        }

        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        if let error = apiResponse.error {
            throw PayrollSlipImportError.apiRequestFailed(error.message ?? PayrollLocalization.text("OpenAI APIがエラーを返しました。"))
        }

        guard let outputText = apiResponse.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !outputText.isEmpty,
              let payloadData = jsonObjectData(from: outputText) else {
            throw PayrollSlipImportError.invalidAIResponse
        }

        do {
            return try JSONDecoder().decode(AIImportPayload.self, from: payloadData)
        } catch {
            throw PayrollSlipImportError.invalidAIResponse
        }
    }

    private static func makeImportResult(
        from payload: AIImportPayload,
        fallbackKind: PayrollRecordKind,
        sourceID: UUID?
    ) throws -> PayrollSlipImportResult {
        let paymentItems = sanitizedLineItems(payload.paymentItems)
        let deductionItems = sanitizedLineItems(payload.deductionItems)

        guard !paymentItems.isEmpty else {
            throw PayrollSlipImportError.noItemsRecognized
        }

        let notePrefix = PayrollLocalization.text("AI読み取りで抽出")
        let supplementalNote = payload.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let note: String
        if let supplementalNote = supplementalNote, !supplementalNote.isEmpty {
            note = PayrollLocalization.format("%1$@ / %2$@", notePrefix, supplementalNote)
        } else {
            note = notePrefix
        }

        return PayrollSlipImportResult(
            kind: payload.kindValue ?? fallbackKind,
            paymentDate: parsePaymentDate(payload.paymentDate) ?? .now,
            sourceID: sourceID,
            note: note,
            paymentItems: paymentItems,
            deductionItems: deductionItems
        )
    }

    private static func makeRequestBody(
        imageData: Data,
        fallbackKind: PayrollRecordKind
    ) throws -> Data {
        let imageURL = "data:image/jpeg;base64,\(imageData.base64EncodedString())"
        let requestObject: [String: Any] = [
            "model": OpenAIConfiguration.model,
            "store": false,
            "max_output_tokens": 1600,
            "input": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": importPrompt(fallbackKind: fallbackKind)
                        ],
                        [
                            "type": "input_image",
                            "image_url": imageURL,
                            "detail": "high"
                        ]
                    ]
                ]
            ],
            "text": [
                "format": responseFormatSchema
            ]
        ]

        return try JSONSerialization.data(withJSONObject: requestObject)
    }

    private static func importPrompt(fallbackKind: PayrollRecordKind) -> String {
        """
        日本の給与明細または賞与明細の写真を読み取り、支給項目と控除項目を抽出してください。
        返答は必ず指定されたJSONスキーマに従ってください。

        抽出ルール:
        - kind は給与明細なら salary、賞与明細なら bonus。不明な場合は \(fallbackKind.rawValue)。
        - payment_date は支給日を YYYY-MM-DD 形式で返してください。不明な場合は null。
        - payment_items は支給欄の個別項目です。基本給、手当、通勤費、残業手当、賞与などを含めます。
        - deduction_items は控除欄の個別項目です。健康保険、厚生年金、雇用保険、所得税、住民税などを含めます。
        - amount は円単位の数値だけにしてください。カンマ、円記号、マイナス記号は含めません。
        - 合計、総支給額、控除合計、差引支給額、手取り、振込額、課税対象額、累計、勤務日数、勤務時間は個別項目に含めません。
        - 読み取れない項目や金額に自信がない項目は配列に入れないでください。
        - note は「賞与明細」「給与明細」など、利用者の確認に役立つ短い日本語だけを返してください。不明な場合は null。
        """
    }

    private static var responseFormatSchema: [String: Any] {
        [
            "type": "json_schema",
            "name": "payroll_slip_import",
            "strict": true,
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "properties": [
                    "kind": [
                        "type": "string",
                        "enum": ["salary", "bonus"]
                    ],
                    "payment_date": [
                        "type": ["string", "null"],
                        "description": "支給日。YYYY-MM-DD。不明な場合は null。"
                    ],
                    "note": [
                        "type": ["string", "null"],
                        "description": "短い補足。不明な場合は null。"
                    ],
                    "payment_items": [
                        "type": "array",
                        "items": lineItemSchema
                    ],
                    "deduction_items": [
                        "type": "array",
                        "items": lineItemSchema
                    ]
                ],
                "required": [
                    "kind",
                    "payment_date",
                    "note",
                    "payment_items",
                    "deduction_items"
                ]
            ]
        ]
    }

    private static var lineItemSchema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "name": [
                    "type": "string",
                    "description": "明細上の項目名。"
                ],
                "amount": [
                    "type": "number",
                    "description": "円単位の金額。"
                ]
            ],
            "required": ["name", "amount"]
        ]
    }

    private static func prepareJPEGData(from imageData: Data) throws -> Data {
        guard let image = UIImage(data: imageData) else {
            throw PayrollSlipImportError.imageLoadFailed
        }

        let longestSide = max(image.size.width, image.size.height)
        let scaleRatio = min(1, imageMaxDimension / max(longestSide, 1))
        let targetSize = CGSize(
            width: max(1, image.size.width * scaleRatio),
            height: max(1, image.size.height * scaleRatio)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalizedImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let jpegData = normalizedImage.jpegData(compressionQuality: jpegCompressionQuality) else {
            throw PayrollSlipImportError.imageLoadFailed
        }

        return jpegData
    }

    private static func sanitizedLineItems(_ items: [AIImportLineItem]) -> [EditableLineItem] {
        var seenKeys = Set<String>()

        return items.compactMap { item in
            let name = normalize(item.name)
            let amount = item.amount.rounded()
            guard !name.isEmpty, amount > 0 else {
                return nil
            }

            let dedupeKey = "\(name)|\(Int(amount))"
            guard seenKeys.insert(dedupeKey).inserted else {
                return nil
            }

            return EditableLineItem(name: name, amount: amount)
        }
    }

    private static func parsePaymentDate(_ text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{3000}", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #" +"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func jsonObjectData(from text: String) -> Data? {
        if let data = text.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return nil
        }

        let jsonText = String(text[start...end])
        return jsonText.data(using: .utf8)
    }

    private static func errorMessage(from data: Data) -> String {
        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data),
           let message = errorResponse.error.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }

        if let text = String(data: data, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        return PayrollLocalization.text("OpenAI APIがエラーを返しました。")
    }
}

private enum OpenAIConfiguration {
    static var apiKey: String? {
        guard let value = value(for: "apiKey") else {
            return nil
        }

        return value
    }

    static var model: String {
        value(for: "model") ?? "gpt-5.4-nano"
    }

    private static func value(for key: String) -> String? {
        guard
            let configuration = Bundle.main.object(forInfoDictionaryKey: "OpenAIConfiguration") as? [String: String],
            let value = configuration[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty,
            !value.hasPrefix("$(")
        else {
            return nil
        }

        return value
    }
}

private struct AIImportPayload: Decodable {
    let kind: String
    let paymentDate: String?
    let note: String?
    let paymentItems: [AIImportLineItem]
    let deductionItems: [AIImportLineItem]

    var kindValue: PayrollRecordKind? {
        PayrollRecordKind(rawValue: kind)
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case paymentDate = "payment_date"
        case note
        case paymentItems = "payment_items"
        case deductionItems = "deduction_items"
    }
}

private struct AIImportLineItem: Decodable {
    let name: String
    let amount: Double
}

private struct OpenAIResponse: Decodable {
    let output: [OutputItem]?
    let topLevelOutputText: String?
    let error: OpenAIError?

    enum CodingKeys: String, CodingKey {
        case output
        case topLevelOutputText = "output_text"
        case error
    }

    var outputText: String? {
        if let topLevelOutputText, !topLevelOutputText.isEmpty {
            return topLevelOutputText
        }

        let text = output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text?.isEmpty == false ? text : nil
    }

    struct OutputItem: Decodable {
        let content: [OutputContent]?
    }

    struct OutputContent: Decodable {
        let text: String?
    }
}

private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError
}

private struct OpenAIError: Decodable {
    let message: String?
}
