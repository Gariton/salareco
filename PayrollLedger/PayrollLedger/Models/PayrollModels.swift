import Foundation
import SwiftData

enum PayrollRecordKind: String, Codable, CaseIterable, Identifiable {
    case salary
    case bonus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .salary:
            PayrollLocalization.text("給与")
        case .bonus:
            PayrollLocalization.text("賞与")
        }
    }

    var systemImage: String {
        switch self {
        case .salary:
            "wallet.bifold"
        case .bonus:
            "sparkles.rectangle.stack"
        }
    }
}

enum PayrollLineItemCategory: String, Codable, CaseIterable, Identifiable {
    case payment
    case deduction

    var id: String { rawValue }
}

struct PayrollLineItemValue: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var categoryRawValue: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        category: PayrollLineItemCategory,
        sortOrder: Int
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.categoryRawValue = category.rawValue
        self.sortOrder = sortOrder
    }
}

enum PayrollSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            IncomeSource.self,
            PayrollRecord.self,
            PayrollTemplate.self,
        ]
    }

    @Model
    final class IncomeSource {
        var id: UUID
        var name: String
        var note: String
        var accentHex: String
        var createdAt: Date

        init(
            id: UUID = UUID(),
            name: String,
            note: String = "",
            accentHex: String,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.note = note
            self.accentHex = accentHex
            self.createdAt = createdAt
        }
    }

    @Model
    final class PayrollRecord {
        var id: UUID
        var kindRawValue: String
        var periodYear: Int
        var periodMonth: Int
        var paymentDate: Date
        var note: String
        var createdAt: Date
        var sourceID: UUID?
        var templateID: UUID?
        var items: [PayrollLineItemValue]

        init(
            id: UUID = UUID(),
            kind: PayrollRecordKind,
            periodYear: Int,
            periodMonth: Int,
            paymentDate: Date,
            note: String = "",
            createdAt: Date = .now,
            sourceID: UUID? = nil,
            templateID: UUID? = nil,
            items: [PayrollLineItemValue] = []
        ) {
            self.id = id
            self.kindRawValue = kind.rawValue
            self.periodYear = periodYear
            self.periodMonth = periodMonth
            self.paymentDate = paymentDate
            self.note = note
            self.createdAt = createdAt
            self.sourceID = sourceID
            self.templateID = templateID
            self.items = items
        }
    }

    @Model
    final class PayrollTemplate {
        var id: UUID
        var name: String
        var kindRawValue: String
        var note: String
        var createdAt: Date
        var sourceID: UUID?
        var items: [PayrollLineItemValue]

        init(
            id: UUID = UUID(),
            name: String,
            kind: PayrollRecordKind,
            note: String = "",
            createdAt: Date = .now,
            sourceID: UUID? = nil,
            items: [PayrollLineItemValue] = []
        ) {
            self.id = id
            self.name = name
            self.kindRawValue = kind.rawValue
            self.note = note
            self.createdAt = createdAt
            self.sourceID = sourceID
            self.items = items
        }
    }
}

enum PayrollSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            IncomeSource.self,
            PayrollRecord.self,
            PayrollTemplate.self,
            PayrollLineItem.self,
        ]
    }

    @Model
    final class IncomeSource {
        var id: UUID = UUID()
        var name: String = ""
        var note: String = ""
        var accentHex: String = "#0F766E"
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \PayrollRecord.source)
        var records: [PayrollRecord]? = []

        @Relationship(deleteRule: .cascade, inverse: \PayrollTemplate.source)
        var templates: [PayrollTemplate]? = []

        init(
            id: UUID = UUID(),
            name: String,
            note: String = "",
            accentHex: String,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.note = note
            self.accentHex = accentHex
            self.createdAt = createdAt
        }
    }

    @Model
    final class PayrollRecord {
        var id: UUID = UUID()
        var kindRawValue: String = PayrollRecordKind.salary.rawValue
        var periodYear: Int = Calendar.current.component(.year, from: Date.now)
        var periodMonth: Int = Calendar.current.component(.month, from: Date.now)
        var paymentDate: Date = Date.now
        var note: String = ""
        var createdAt: Date = Date.now
        var sourceID: UUID?
        var templateID: UUID?
        var items: [PayrollLineItemValue] = []

        var source: IncomeSource?

        var template: PayrollTemplate?

        @Relationship(deleteRule: .cascade, inverse: \PayrollLineItem.record)
        var lineItems: [PayrollLineItem]? = []

        init(
            id: UUID = UUID(),
            kind: PayrollRecordKind,
            periodYear: Int,
            periodMonth: Int,
            paymentDate: Date,
            note: String = "",
            createdAt: Date = .now,
            sourceID: UUID? = nil,
            templateID: UUID? = nil,
            items: [PayrollLineItemValue] = []
        ) {
            self.id = id
            self.kindRawValue = kind.rawValue
            self.periodYear = periodYear
            self.periodMonth = periodMonth
            self.paymentDate = paymentDate
            self.note = note
            self.createdAt = createdAt
            self.sourceID = sourceID
            self.templateID = templateID
            self.items = items
        }
    }

    @Model
    final class PayrollTemplate {
        var id: UUID = UUID()
        var name: String = ""
        var kindRawValue: String = PayrollRecordKind.salary.rawValue
        var note: String = ""
        var createdAt: Date = Date.now
        var sourceID: UUID?
        var items: [PayrollLineItemValue] = []

        var source: IncomeSource?

        @Relationship(inverse: \PayrollRecord.template)
        var records: [PayrollRecord]? = []

        @Relationship(deleteRule: .cascade, inverse: \PayrollLineItem.template)
        var lineItems: [PayrollLineItem]? = []

        init(
            id: UUID = UUID(),
            name: String,
            kind: PayrollRecordKind,
            note: String = "",
            createdAt: Date = .now,
            sourceID: UUID? = nil,
            items: [PayrollLineItemValue] = []
        ) {
            self.id = id
            self.name = name
            self.kindRawValue = kind.rawValue
            self.note = note
            self.createdAt = createdAt
            self.sourceID = sourceID
            self.items = items
        }
    }

    @Model
    final class PayrollLineItem {
        var id: UUID = UUID()
        var name: String = ""
        var amount: Double = 0
        var categoryRawValue: String = PayrollLineItemCategory.payment.rawValue
        var sortOrder: Int = 0

        var record: PayrollRecord?

        var template: PayrollTemplate?

        init(
            id: UUID = UUID(),
            name: String,
            amount: Double,
            categoryRawValue: String,
            sortOrder: Int
        ) {
            self.id = id
            self.name = name
            self.amount = amount
            self.categoryRawValue = categoryRawValue
            self.sortOrder = sortOrder
        }
    }
}

enum PayrollSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            IncomeSource.self,
            PayrollRecord.self,
            PayrollTemplate.self,
            PayrollLineItem.self,
        ]
    }

    @Model
    final class IncomeSource {
        var id: UUID = UUID()
        var name: String = ""
        var note: String = ""
        var accentHex: String = "#0F766E"
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \PayrollRecord.source)
        var records: [PayrollRecord]? = []

        @Relationship(deleteRule: .cascade, inverse: \PayrollTemplate.source)
        var templates: [PayrollTemplate]? = []

        init(
            id: UUID = UUID(),
            name: String,
            note: String = "",
            accentHex: String,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.note = note
            self.accentHex = accentHex
            self.createdAt = createdAt
        }
    }

    @Model
    final class PayrollRecord {
        var id: UUID = UUID()
        var kindRawValue: String = PayrollRecordKind.salary.rawValue
        var periodYear: Int = Calendar.current.component(.year, from: Date.now)
        var periodMonth: Int = Calendar.current.component(.month, from: Date.now)
        var paymentDate: Date = Date.now
        var note: String = ""
        var createdAt: Date = Date.now

        var source: IncomeSource?

        var template: PayrollTemplate?

        @Relationship(deleteRule: .cascade, inverse: \PayrollLineItem.record)
        var lineItems: [PayrollLineItem]? = []

        init(
            id: UUID = UUID(),
            kind: PayrollRecordKind,
            periodYear: Int,
            periodMonth: Int,
            paymentDate: Date,
            note: String = "",
            createdAt: Date = .now,
            source: IncomeSource? = nil,
            template: PayrollTemplate? = nil
        ) {
            self.id = id
            self.kindRawValue = kind.rawValue
            self.periodYear = periodYear
            self.periodMonth = periodMonth
            self.paymentDate = paymentDate
            self.note = note
            self.createdAt = createdAt
            self.source = source
            self.template = template
        }
    }

    @Model
    final class PayrollTemplate {
        var id: UUID = UUID()
        var name: String = ""
        var kindRawValue: String = PayrollRecordKind.salary.rawValue
        var note: String = ""
        var createdAt: Date = Date.now

        var source: IncomeSource?

        @Relationship(inverse: \PayrollRecord.template)
        var records: [PayrollRecord]? = []

        @Relationship(deleteRule: .cascade, inverse: \PayrollLineItem.template)
        var lineItems: [PayrollLineItem]? = []

        init(
            id: UUID = UUID(),
            name: String,
            kind: PayrollRecordKind,
            note: String = "",
            createdAt: Date = .now,
            source: IncomeSource? = nil
        ) {
            self.id = id
            self.name = name
            self.kindRawValue = kind.rawValue
            self.note = note
            self.createdAt = createdAt
            self.source = source
        }
    }

    @Model
    final class PayrollLineItem {
        var id: UUID = UUID()
        var name: String = ""
        var amount: Double = 0
        var categoryRawValue: String = PayrollLineItemCategory.payment.rawValue
        var sortOrder: Int = 0

        var record: PayrollRecord?

        var template: PayrollTemplate?

        init(
            id: UUID = UUID(),
            name: String,
            amount: Double,
            categoryRawValue: String,
            sortOrder: Int
        ) {
            self.id = id
            self.name = name
            self.amount = amount
            self.categoryRawValue = categoryRawValue
            self.sortOrder = sortOrder
        }
    }
}

enum PayrollSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            IncomeSource.self,
            PayrollRecord.self,
            PayrollTemplate.self,
            PayrollLineItem.self,
        ]
    }

    @Model
    final class IncomeSource {
        var id: UUID = UUID()
        var name: String = ""
        var note: String = ""
        var accentHex: String = "#0F766E"
        var salaryPaymentDay: Int?
        var salaryAnnouncementDay: Int?
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \PayrollRecord.source)
        var records: [PayrollRecord]? = []

        @Relationship(deleteRule: .cascade, inverse: \PayrollTemplate.source)
        var templates: [PayrollTemplate]? = []

        init(
            id: UUID = UUID(),
            name: String,
            note: String = "",
            accentHex: String,
            salaryPaymentDay: Int? = nil,
            salaryAnnouncementDay: Int? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.note = note
            self.accentHex = accentHex
            self.salaryPaymentDay = salaryPaymentDay
            self.salaryAnnouncementDay = salaryAnnouncementDay
            self.createdAt = createdAt
        }
    }

    @Model
    final class PayrollRecord {
        var id: UUID = UUID()
        var kindRawValue: String = PayrollRecordKind.salary.rawValue
        var periodYear: Int = Calendar.current.component(.year, from: Date.now)
        var periodMonth: Int = Calendar.current.component(.month, from: Date.now)
        var paymentDate: Date = Date.now
        var note: String = ""
        var createdAt: Date = Date.now

        var source: IncomeSource?

        var template: PayrollTemplate?

        @Relationship(deleteRule: .cascade, inverse: \PayrollLineItem.record)
        var lineItems: [PayrollLineItem]? = []

        init(
            id: UUID = UUID(),
            kind: PayrollRecordKind,
            periodYear: Int,
            periodMonth: Int,
            paymentDate: Date,
            note: String = "",
            createdAt: Date = .now,
            source: IncomeSource? = nil,
            template: PayrollTemplate? = nil
        ) {
            self.id = id
            self.kindRawValue = kind.rawValue
            self.periodYear = periodYear
            self.periodMonth = periodMonth
            self.paymentDate = paymentDate
            self.note = note
            self.createdAt = createdAt
            self.source = source
            self.template = template
        }
    }

    @Model
    final class PayrollTemplate {
        var id: UUID = UUID()
        var name: String = ""
        var kindRawValue: String = PayrollRecordKind.salary.rawValue
        var note: String = ""
        var createdAt: Date = Date.now

        var source: IncomeSource?

        @Relationship(inverse: \PayrollRecord.template)
        var records: [PayrollRecord]? = []

        @Relationship(deleteRule: .cascade, inverse: \PayrollLineItem.template)
        var lineItems: [PayrollLineItem]? = []

        init(
            id: UUID = UUID(),
            name: String,
            kind: PayrollRecordKind,
            note: String = "",
            createdAt: Date = .now,
            source: IncomeSource? = nil
        ) {
            self.id = id
            self.name = name
            self.kindRawValue = kind.rawValue
            self.note = note
            self.createdAt = createdAt
            self.source = source
        }
    }

    @Model
    final class PayrollLineItem {
        var id: UUID = UUID()
        var name: String = ""
        var amount: Double = 0
        var categoryRawValue: String = PayrollLineItemCategory.payment.rawValue
        var sortOrder: Int = 0

        var record: PayrollRecord?

        var template: PayrollTemplate?

        init(
            id: UUID = UUID(),
            name: String,
            amount: Double,
            categoryRawValue: String,
            sortOrder: Int
        ) {
            self.id = id
            self.name = name
            self.amount = amount
            self.categoryRawValue = categoryRawValue
            self.sortOrder = sortOrder
        }
    }
}

enum PayrollSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            IncomeSource.self,
            PayrollRecord.self,
            PayrollTemplate.self,
            PayrollLineItem.self,
            WorkHourDefinition.self,
            PayrollWorkHourEntry.self,
        ]
    }

    @Model
    final class IncomeSource {
        var id: UUID = UUID()
        var name: String = ""
        var note: String = ""
        var accentHex: String = "#0F766E"
        var salaryPaymentDay: Int?
        var salaryAnnouncementDay: Int?
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \PayrollRecord.source)
        var records: [PayrollRecord]? = []

        @Relationship(deleteRule: .cascade, inverse: \PayrollTemplate.source)
        var templates: [PayrollTemplate]? = []

        @Relationship(deleteRule: .cascade, inverse: \WorkHourDefinition.source)
        var workHourDefinitions: [WorkHourDefinition]? = []

        init(
            id: UUID = UUID(),
            name: String,
            note: String = "",
            accentHex: String,
            salaryPaymentDay: Int? = nil,
            salaryAnnouncementDay: Int? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.note = note
            self.accentHex = accentHex
            self.salaryPaymentDay = salaryPaymentDay
            self.salaryAnnouncementDay = salaryAnnouncementDay
            self.createdAt = createdAt
        }
    }

    @Model
    final class PayrollRecord {
        var id: UUID = UUID()
        var kindRawValue: String = PayrollRecordKind.salary.rawValue
        var periodYear: Int = Calendar.current.component(.year, from: Date.now)
        var periodMonth: Int = Calendar.current.component(.month, from: Date.now)
        var paymentDate: Date = Date.now
        var note: String = ""
        var createdAt: Date = Date.now

        var source: IncomeSource?

        var template: PayrollTemplate?

        @Relationship(deleteRule: .cascade, inverse: \PayrollLineItem.record)
        var lineItems: [PayrollLineItem]? = []

        @Relationship(deleteRule: .cascade, inverse: \PayrollWorkHourEntry.record)
        var workHourEntries: [PayrollWorkHourEntry]? = []

        init(
            id: UUID = UUID(),
            kind: PayrollRecordKind,
            periodYear: Int,
            periodMonth: Int,
            paymentDate: Date,
            note: String = "",
            createdAt: Date = .now,
            source: IncomeSource? = nil,
            template: PayrollTemplate? = nil
        ) {
            self.id = id
            self.kindRawValue = kind.rawValue
            self.periodYear = periodYear
            self.periodMonth = periodMonth
            self.paymentDate = paymentDate
            self.note = note
            self.createdAt = createdAt
            self.source = source
            self.template = template
        }
    }

    @Model
    final class PayrollTemplate {
        var id: UUID = UUID()
        var name: String = ""
        var kindRawValue: String = PayrollRecordKind.salary.rawValue
        var note: String = ""
        var createdAt: Date = Date.now

        var source: IncomeSource?

        @Relationship(inverse: \PayrollRecord.template)
        var records: [PayrollRecord]? = []

        @Relationship(deleteRule: .cascade, inverse: \PayrollLineItem.template)
        var lineItems: [PayrollLineItem]? = []

        init(
            id: UUID = UUID(),
            name: String,
            kind: PayrollRecordKind,
            note: String = "",
            createdAt: Date = .now,
            source: IncomeSource? = nil
        ) {
            self.id = id
            self.name = name
            self.kindRawValue = kind.rawValue
            self.note = note
            self.createdAt = createdAt
            self.source = source
        }
    }

    @Model
    final class PayrollLineItem {
        var id: UUID = UUID()
        var name: String = ""
        var amount: Double = 0
        var categoryRawValue: String = PayrollLineItemCategory.payment.rawValue
        var sortOrder: Int = 0

        var record: PayrollRecord?

        var template: PayrollTemplate?

        init(
            id: UUID = UUID(),
            name: String,
            amount: Double,
            categoryRawValue: String,
            sortOrder: Int
        ) {
            self.id = id
            self.name = name
            self.amount = amount
            self.categoryRawValue = categoryRawValue
            self.sortOrder = sortOrder
        }
    }

    @Model
    final class WorkHourDefinition {
        var id: UUID = UUID()
        var name: String = ""
        var sortOrder: Int = 0

        var source: IncomeSource?

        init(
            id: UUID = UUID(),
            name: String,
            sortOrder: Int
        ) {
            self.id = id
            self.name = name
            self.sortOrder = sortOrder
        }
    }

    @Model
    final class PayrollWorkHourEntry {
        var id: UUID = UUID()
        var definitionID: UUID?
        var name: String = ""
        var hours: Double = 0
        var sortOrder: Int = 0

        var record: PayrollRecord?

        init(
            id: UUID = UUID(),
            definitionID: UUID? = nil,
            name: String,
            hours: Double,
            sortOrder: Int
        ) {
            self.id = id
            self.definitionID = definitionID
            self.name = name
            self.hours = hours
            self.sortOrder = sortOrder
        }
    }
}

enum PayrollMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            PayrollSchemaV1.self,
            PayrollSchemaV2.self,
            PayrollSchemaV3.self,
            PayrollSchemaV4.self,
            PayrollSchemaV5.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            migrateLegacyRelationships,
            .lightweight(fromVersion: PayrollSchemaV2.self, toVersion: PayrollSchemaV3.self),
            .lightweight(fromVersion: PayrollSchemaV3.self, toVersion: PayrollSchemaV4.self),
            .lightweight(fromVersion: PayrollSchemaV4.self, toVersion: PayrollSchemaV5.self),
        ]
    }

    private static let migrateLegacyRelationships = MigrationStage.custom(
        fromVersion: PayrollSchemaV1.self,
        toVersion: PayrollSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            try migrateLegacyRelationshipsAndLineItems(in: context)
        }
    )

    private static func migrateLegacyRelationshipsAndLineItems(in context: ModelContext) throws {
        let sources = try context.fetch(FetchDescriptor<PayrollSchemaV2.IncomeSource>())
        let templates = try context.fetch(FetchDescriptor<PayrollSchemaV2.PayrollTemplate>())
        let records = try context.fetch(FetchDescriptor<PayrollSchemaV2.PayrollRecord>())

        let sourceByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        let templateByID = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })

        for template in templates {
            template.source = template.sourceID.flatMap { sourceByID[$0] }

            if (template.lineItems ?? []).isEmpty {
                template.lineItems = try makeV2LineItems(
                    from: template.items,
                    context: context,
                    record: nil,
                    template: template
                )
            }
        }

        for record in records {
            record.source = record.sourceID.flatMap { sourceByID[$0] }
            record.template = record.templateID.flatMap { templateByID[$0] }

            if (record.lineItems ?? []).isEmpty {
                record.lineItems = try makeV2LineItems(
                    from: record.items,
                    context: context,
                    record: record,
                    template: nil
                )
            }
        }

        try context.save()
    }

    private static func makeV2LineItems(
        from legacyItems: [PayrollLineItemValue],
        context: ModelContext,
        record: PayrollSchemaV2.PayrollRecord?,
        template: PayrollSchemaV2.PayrollTemplate?
    ) throws -> [PayrollSchemaV2.PayrollLineItem] {
        let orderedItems = legacyItems.sorted { lhs, rhs in
            if lhs.categoryRawValue == rhs.categoryRawValue {
                return lhs.sortOrder < rhs.sortOrder
            }

            return lhs.categoryRawValue < rhs.categoryRawValue
        }

        return orderedItems.map { legacyItem in
            let lineItem = PayrollSchemaV2.PayrollLineItem(
                id: legacyItem.id,
                name: legacyItem.name,
                amount: legacyItem.amount,
                categoryRawValue: legacyItem.categoryRawValue,
                sortOrder: legacyItem.sortOrder
            )
            lineItem.record = record
            lineItem.template = template
            context.insert(lineItem)
            return lineItem
        }
    }
}

typealias IncomeSource = PayrollSchemaV5.IncomeSource
typealias PayrollRecord = PayrollSchemaV5.PayrollRecord
typealias PayrollTemplate = PayrollSchemaV5.PayrollTemplate
typealias PayrollLineItem = PayrollSchemaV5.PayrollLineItem
typealias WorkHourDefinition = PayrollSchemaV5.WorkHourDefinition
typealias PayrollWorkHourEntry = PayrollSchemaV5.PayrollWorkHourEntry

extension IncomeSource: Identifiable {}
extension PayrollRecord: Identifiable {}
extension PayrollTemplate: Identifiable {}
extension PayrollLineItem: Identifiable {}
extension WorkHourDefinition: Identifiable {}
extension PayrollWorkHourEntry: Identifiable {}

extension IncomeSource {
    var sortedWorkHourDefinitions: [WorkHourDefinition] {
        (workHourDefinitions ?? []).sorted { lhs, rhs in
            lhs.sortOrder < rhs.sortOrder
        }
    }

    func replaceWorkHourDefinitions(
        with newDefinitions: [WorkHourDefinition],
        in modelContext: ModelContext
    ) {
        for existingDefinition in workHourDefinitions ?? [] {
            modelContext.delete(existingDefinition)
        }

        let orderedDefinitions = newDefinitions.sorted { lhs, rhs in
            lhs.sortOrder < rhs.sortOrder
        }

        workHourDefinitions = []

        for definition in orderedDefinitions {
            definition.source = self
            modelContext.insert(definition)
        }

        workHourDefinitions = orderedDefinitions
    }
}

extension PayrollRecord {
    var kind: PayrollRecordKind {
        get { PayrollRecordKind(rawValue: kindRawValue) ?? .salary }
        set { kindRawValue = newValue.rawValue }
    }

    var sourceID: UUID? {
        source?.id
    }

    var templateID: UUID? {
        template?.id
    }

    var titleText: String {
        PayrollLocalization.recordTitle(
            year: periodYear,
            month: periodMonth,
            kindTitle: kind.title
        )
    }

    var paymentItems: [PayrollLineItem] {
        sortedLineItems.filter { $0.category == .payment }
    }

    var deductionItems: [PayrollLineItem] {
        sortedLineItems.filter { $0.category == .deduction }
    }

    var totalPayments: Double {
        paymentItems.reduce(0) { $0 + $1.amount }
    }

    var totalDeductions: Double {
        deductionItems.reduce(0) { $0 + $1.amount }
    }

    var netAmount: Double {
        totalPayments - totalDeductions
    }

    var sortedWorkHourEntries: [PayrollWorkHourEntry] {
        (workHourEntries ?? []).sorted { lhs, rhs in
            lhs.sortOrder < rhs.sortOrder
        }
    }

    var totalWorkHours: Double {
        sortedWorkHourEntries.reduce(0) { $0 + $1.hours }
    }

    func source(in sources: [IncomeSource]) -> IncomeSource? {
        source ?? sources.first(where: { $0.id == sourceID })
    }

    func replaceLineItems(with newItems: [PayrollLineItem], in modelContext: ModelContext) {
        for existingItem in lineItems ?? [] {
            modelContext.delete(existingItem)
        }

        let orderedItems = newItems.sorted { lhs, rhs in
            if lhs.categoryRawValue == rhs.categoryRawValue {
                return lhs.sortOrder < rhs.sortOrder
            }

            return lhs.categoryRawValue < rhs.categoryRawValue
        }

        lineItems = []

        for item in orderedItems {
            item.record = self
            item.template = nil
            modelContext.insert(item)
        }

        lineItems = orderedItems
    }

    func replaceWorkHourEntries(
        with newEntries: [PayrollWorkHourEntry],
        in modelContext: ModelContext
    ) {
        for existingEntry in workHourEntries ?? [] {
            modelContext.delete(existingEntry)
        }

        let orderedEntries = newEntries.sorted { lhs, rhs in
            lhs.sortOrder < rhs.sortOrder
        }

        workHourEntries = []

        for entry in orderedEntries {
            entry.record = self
            modelContext.insert(entry)
        }

        workHourEntries = orderedEntries
    }

    private var sortedLineItems: [PayrollLineItem] {
        (lineItems ?? []).sorted { lhs, rhs in
            if lhs.categoryRawValue == rhs.categoryRawValue {
                return lhs.sortOrder < rhs.sortOrder
            }

            return lhs.categoryRawValue < rhs.categoryRawValue
        }
    }
}

extension PayrollTemplate {
    var kind: PayrollRecordKind {
        get { PayrollRecordKind(rawValue: kindRawValue) ?? .salary }
        set { kindRawValue = newValue.rawValue }
    }

    var sourceID: UUID? {
        source?.id
    }

    var paymentItems: [PayrollLineItem] {
        sortedLineItems.filter { $0.category == .payment }
    }

    var deductionItems: [PayrollLineItem] {
        sortedLineItems.filter { $0.category == .deduction }
    }

    var totalPayments: Double {
        paymentItems.reduce(0) { $0 + $1.amount }
    }

    var totalDeductions: Double {
        deductionItems.reduce(0) { $0 + $1.amount }
    }

    var netPreviewAmount: Double {
        totalPayments - totalDeductions
    }

    func source(in sources: [IncomeSource]) -> IncomeSource? {
        source ?? sources.first(where: { $0.id == sourceID })
    }

    func replaceLineItems(with newItems: [PayrollLineItem], in modelContext: ModelContext) {
        for existingItem in lineItems ?? [] {
            modelContext.delete(existingItem)
        }

        let orderedItems = newItems.sorted { lhs, rhs in
            if lhs.categoryRawValue == rhs.categoryRawValue {
                return lhs.sortOrder < rhs.sortOrder
            }

            return lhs.categoryRawValue < rhs.categoryRawValue
        }

        lineItems = []

        for item in orderedItems {
            item.record = nil
            item.template = self
            modelContext.insert(item)
        }

        lineItems = orderedItems
    }

    private var sortedLineItems: [PayrollLineItem] {
        (lineItems ?? []).sorted { lhs, rhs in
            if lhs.categoryRawValue == rhs.categoryRawValue {
                return lhs.sortOrder < rhs.sortOrder
            }

            return lhs.categoryRawValue < rhs.categoryRawValue
        }
    }
}

extension PayrollLineItem {
    var category: PayrollLineItemCategory {
        get { PayrollLineItemCategory(rawValue: categoryRawValue) ?? .payment }
        set { categoryRawValue = newValue.rawValue }
    }
}
