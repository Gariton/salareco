import Foundation

struct EditableLineItem: Identifiable, Hashable {
    var id: UUID
    var name: String
    var amount: Double

    init(id: UUID = UUID(), name: String = "", amount: Double = 0) {
        self.id = id
        self.name = name
        self.amount = amount
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isMeaningful: Bool {
        !trimmedName.isEmpty && amount >= 0
    }
}

struct EditableWorkHourDefinition: Identifiable, Hashable {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isMeaningful: Bool {
        !trimmedName.isEmpty
    }
}

struct EditableWorkHourItem: Identifiable, Hashable {
    var id: UUID
    var definitionID: UUID?
    var name: String
    var hours: Double

    init(
        id: UUID = UUID(),
        definitionID: UUID? = nil,
        name: String = "",
        hours: Double = 0
    ) {
        self.id = id
        self.definitionID = definitionID
        self.name = name
        self.hours = hours
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isMeaningful: Bool {
        !trimmedName.isEmpty && hours > 0
    }
}

struct RecordDraft {
    var kind: PayrollRecordKind
    var paymentDate: Date
    var sourceID: UUID?
    var selectedTemplateID: UUID?
    var note: String
    var paymentItems: [EditableLineItem]
    var deductionItems: [EditableLineItem]
    var workHourItems: [EditableWorkHourItem]

    private var originalSourceID: UUID?

    init(
        record: PayrollRecord? = nil,
        initialKind: PayrollRecordKind = .salary,
        template: PayrollTemplate? = nil,
        initialSourceID: UUID? = nil,
        copySourceRecord: PayrollRecord? = nil
    ) {
        if let record {
            kind = record.kind
            paymentDate = record.paymentDate
            sourceID = record.sourceID
            selectedTemplateID = record.templateID
            note = record.note
            paymentItems = record.paymentItems.map { EditableLineItem(name: $0.name, amount: $0.amount) }
            deductionItems = record.deductionItems.map { EditableLineItem(name: $0.name, amount: $0.amount) }
            workHourItems = record.sortedWorkHourEntries.map {
                EditableWorkHourItem(
                    id: $0.id,
                    definitionID: $0.definitionID,
                    name: $0.name,
                    hours: $0.hours
                )
            }
            originalSourceID = record.sourceID
        } else {
            kind = initialKind
            paymentDate = .now
            sourceID = template?.sourceID ?? initialSourceID
            selectedTemplateID = template?.id
            note = template?.note ?? ""
            paymentItems = [EditableLineItem()]
            deductionItems = [EditableLineItem()]
            workHourItems = []
            originalSourceID = nil
        }

        if let template, record == nil {
            apply(template: template)
        } else if let copySourceRecord, record == nil {
            apply(copying: copySourceRecord)
        }
    }

    var normalizedPaymentItems: [EditableLineItem] {
        paymentItems.filter(\.isMeaningful)
    }

    var normalizedDeductionItems: [EditableLineItem] {
        deductionItems.filter(\.isMeaningful)
    }

    var normalizedWorkHourItems: [EditableWorkHourItem] {
        workHourItems.filter(\.isMeaningful)
    }

    var totalPayments: Double {
        normalizedPaymentItems.reduce(0) { $0 + $1.amount }
    }

    var totalDeductions: Double {
        normalizedDeductionItems.reduce(0) { $0 + $1.amount }
    }

    var netAmount: Double {
        totalPayments - totalDeductions
    }

    var isValid: Bool {
        sourceID != nil && !normalizedPaymentItems.isEmpty
    }

    mutating func apply(template: PayrollTemplate) {
        kind = template.kind
        sourceID = template.sourceID ?? sourceID
        selectedTemplateID = template.id
        note = template.note
        paymentItems = template.paymentItems.map { EditableLineItem(name: $0.name, amount: $0.amount) }
        deductionItems = template.deductionItems.map { EditableLineItem(name: $0.name, amount: $0.amount) }
    }

    mutating func apply(copying record: PayrollRecord) {
        kind = record.kind
        paymentDate = record.paymentDate
        sourceID = record.sourceID
        selectedTemplateID = nil
        note = record.note
        paymentItems = record.paymentItems.map { EditableLineItem(name: $0.name, amount: $0.amount) }
        deductionItems = record.deductionItems.map { EditableLineItem(name: $0.name, amount: $0.amount) }
        workHourItems = record.sortedWorkHourEntries.map {
            EditableWorkHourItem(
                id: $0.id,
                definitionID: $0.definitionID,
                name: $0.name,
                hours: $0.hours
            )
        }
        originalSourceID = record.sourceID
    }

    mutating func synchronizeWorkHourItems(
        with definitions: [WorkHourDefinition],
        currentSourceID: UUID?
    ) {
        let definitionIDs = Set(definitions.map(\.id))
        let shouldPreserveOrphans = currentSourceID == originalSourceID

        let synchronizedItems = definitions.map { definition in
            let existingItem = workHourItems.first(where: { $0.definitionID == definition.id })
            return EditableWorkHourItem(
                id: existingItem?.id ?? UUID(),
                definitionID: definition.id,
                name: definition.name,
                hours: existingItem?.hours ?? 0
            )
        }

        let orphanedItems: [EditableWorkHourItem]
        if shouldPreserveOrphans {
            orphanedItems = workHourItems.filter { item in
                guard let definitionID = item.definitionID else {
                    return true
                }

                return !definitionIDs.contains(definitionID)
            }
        } else {
            orphanedItems = []
        }

        workHourItems = synchronizedItems + orphanedItems
    }
}

struct TemplateDraft {
    var name: String
    var kind: PayrollRecordKind
    var sourceID: UUID?
    var note: String
    var paymentItems: [EditableLineItem]
    var deductionItems: [EditableLineItem]

    init(template: PayrollTemplate? = nil, initialSourceID: UUID? = nil) {
        if let template {
            name = template.name
            kind = template.kind
            sourceID = template.sourceID
            note = template.note
            paymentItems = template.paymentItems.map { EditableLineItem(name: $0.name, amount: $0.amount) }
            deductionItems = template.deductionItems.map { EditableLineItem(name: $0.name, amount: $0.amount) }
        } else {
            name = ""
            kind = .salary
            sourceID = initialSourceID
            note = ""
            paymentItems = [EditableLineItem()]
            deductionItems = [EditableLineItem()]
        }
    }

    var normalizedPaymentItems: [EditableLineItem] {
        paymentItems.filter(\.isMeaningful)
    }

    var normalizedDeductionItems: [EditableLineItem] {
        deductionItems.filter(\.isMeaningful)
    }

    var totalPayments: Double {
        normalizedPaymentItems.reduce(0) { $0 + $1.amount }
    }

    var totalDeductions: Double {
        normalizedDeductionItems.reduce(0) { $0 + $1.amount }
    }

    var netAmount: Double {
        totalPayments - totalDeductions
    }

    var isValid: Bool {
        sourceID != nil && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !normalizedPaymentItems.isEmpty
    }
}

struct SharePrivacyOptions {
    var hideSourceName = false
    var hideAmounts = false
    var hideBreakdown = false
    var hideNotes = true

    static let hideSourceNameKey = "share.hideSourceName"
    static let hideAmountsKey = "share.hideAmounts"
    static let hideBreakdownKey = "share.hideBreakdown"
    static let hideNotesKey = "share.hideNotes"
}
