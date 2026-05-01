import PhotosUI
import SwiftData
import SwiftUI

private enum RecordEditorSheet: Identifiable {
    case copySource

    var id: String {
        switch self {
        case .copySource:
            "copy-source"
        }
    }
}

struct RecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PayrollMonetizationStore.self) private var monetization

    @Query(sort: \PayrollRecord.paymentDate, order: .reverse) private var records: [PayrollRecord]
    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \PayrollTemplate.createdAt, order: .reverse) private var templates: [PayrollTemplate]

    @State private var draft: RecordDraft
    @State private var activeSheet: RecordEditorSheet?
    @State private var selectedSlipPhotoItem: PhotosPickerItem?
    @State private var isImportingFromPhoto = false
    @State private var importErrorMessage: String?
    @State private var plusSheet: PayrollPlusPaywall?

    private let record: PayrollRecord?

    init(
        record: PayrollRecord? = nil,
        initialKind: PayrollRecordKind = .salary,
        initialTemplate: PayrollTemplate? = nil,
        initialSourceID: UUID? = nil,
        copySourceRecord: PayrollRecord? = nil
    ) {
        self.record = record
        _draft = State(
            initialValue: RecordDraft(
                record: record,
                initialKind: initialKind,
                template: initialTemplate,
                initialSourceID: initialSourceID,
                copySourceRecord: copySourceRecord
            )
        )
    }

    var body: some View {
        Form {
            draftSummarySection
            if !monetization.isPlusActive {
                Section {
                    FreePlanBannerAdView(placement: .recordEditor, horizontalPadding: false)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            if record == nil {
                copySection
            }
            importSection
            basicSection
            templateSection
            workHourSection
            itemSection(
                title: "支給項目",
                items: $draft.paymentItems,
                addAction: { draft.paymentItems.append(EditableLineItem()) }
            )
            itemSection(
                title: "控除項目",
                items: $draft.deductionItems,
                addAction: { draft.deductionItems.append(EditableLineItem()) }
            )
            summarySection
            notesSection
        }
        .scrollContentBackground(.hidden)
        .background(PayrollScreenBackground(accent: accentColor))
        .navigationTitle(PayrollLocalization.text(record == nil ? "給与記録を追加" : "給与記録を編集"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("保存", action: save)
                    .disabled(!draft.isValid)
            }
        }
        .task {
            if draft.sourceID == nil {
                draft.sourceID = sources.first?.id
            }

            synchronizeWorkHourItems(for: draft.sourceID)
        }
        .task(id: selectedSlipPhotoItem?.itemIdentifier) {
            await importSelectedPhotoIfNeeded()
        }
        .onChange(of: draft.selectedTemplateID) { _, newValue in
            guard let newValue else { return }
            guard let selectedTemplate = availableTemplates.first(where: { $0.id == newValue }) else { return }
            draft.apply(template: selectedTemplate)
        }
        .onChange(of: draft.sourceID) { _, _ in
            if let selectedTemplateID = draft.selectedTemplateID,
               !availableTemplates.contains(where: { $0.id == selectedTemplateID }) {
                draft.selectedTemplateID = nil
            }

            synchronizeWorkHourItems(for: draft.sourceID)
        }
        .alert("写真からの読み取りに失敗しました", isPresented: importErrorIsPresented) {
            Button("閉じる") {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .copySource:
                NavigationStack {
                    RecordCopyPickerView(
                        records: copySourceCandidates,
                        sources: sources,
                        selectedSourceID: draft.sourceID
                    ) { selectedRecord in
                        draft.apply(copying: selectedRecord)
                    }
                }
            }
        }
        .sheet(item: $plusSheet) { paywall in
            NavigationStack {
                PlusPlanView(context: paywall)
            }
        }
    }

    private var availableTemplates: [PayrollTemplate] {
        templates.filter { template in
            guard let sourceID = draft.sourceID else {
                return false
            }

            return template.sourceID == sourceID
        }
    }

    private var selectedSource: IncomeSource? {
        sources.first(where: { $0.id == draft.sourceID })
    }

    private var accentColor: Color {
        selectedSource.map { Color(hex: $0.accentHex) } ?? Color(hex: "#0F766E")
    }

    private var importErrorIsPresented: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )
    }

    private var copySourceCandidates: [PayrollRecord] {
        records.filter { existingRecord in
            guard let record else {
                return true
            }

            return existingRecord.id != record.id
        }
    }

    private var draftSummarySection: some View {
        Section {
            RecordDraftSummaryCard(
                sourceName: selectedSource?.name ?? PayrollLocalization.text("支給元未選択"),
                kindTitle: draft.kind.title,
                paymentDateText: draft.paymentDate.mediumJapaneseDateText,
                netAmount: draft.netAmount,
                paymentTotal: draft.totalPayments,
                deductionTotal: draft.totalDeductions,
                paymentItemCount: draft.normalizedPaymentItems.count,
                deductionItemCount: draft.normalizedDeductionItems.count,
                isValid: draft.isValid,
                tint: accentColor
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private var copySection: some View {
        Section("過去のデータからコピー") {
            Button {
                activeSheet = .copySource
            } label: {
                Label("過去の給与データを選択", systemImage: "doc.on.doc")
            }

            Text(
                draft.sourceID == nil
                    ? PayrollLocalization.text("過去の給与や賞与を下書きとして読み込み、必要なところだけ調整して新規登録できます。")
                    : PayrollLocalization.text("選択中の支給元に一致する過去データから、支給項目や控除項目をそのままコピーできます。")
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var importSection: some View {
        Section("給与明細の写真から入力") {
            if monetization.isPlusActive {
                PhotosPicker(selection: $selectedSlipPhotoItem, matching: .images) {
                    Label("写真を選んで自動入力", systemImage: "photo.badge.magnifyingglass")
                }

                if isImportingFromPhoto {
                    ProgressView("明細を解析しています")
                }

                Text("Vision OCR を使って明細写真から支給項目と控除項目を抽出します。保存前に内容を確認してください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                PlusLockedFeatureRow(
                    title: "Plusで写真から自動入力",
                    message: "無料プランでは手入力で給与記録を追加できます。Plusでは明細写真から支給項目と控除項目を読み取れます。",
                    systemImage: "photo.badge.magnifyingglass",
                    actionTitle: "Plusを見る"
                ) {
                    plusSheet = .photoImport
                }
            }
        }
    }

    private var basicSection: some View {
        Section("基本情報") {
            Picker("支給元", selection: $draft.sourceID) {
                Text("未選択").tag(Optional<UUID>.none)
                ForEach(sources) { source in
                    Text(source.name).tag(Optional(source.id))
                }
            }

            Picker("種別", selection: $draft.kind) {
                ForEach(PayrollRecordKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            DatePicker("支給日", selection: $draft.paymentDate, displayedComponents: [.date])
                .environment(\.locale, PayrollLocalization.locale)
        }
    }

    private var templateSection: some View {
        Section("テンプレート") {
            if availableTemplates.isEmpty {
                Text("選択中の支給元にテンプレートはありません。")
                    .foregroundStyle(.secondary)
            } else {
                Picker("適用テンプレート", selection: $draft.selectedTemplateID) {
                    Text("なし").tag(Optional<UUID>.none)
                    ForEach(availableTemplates) { template in
                        Text(template.name).tag(Optional(template.id))
                    }
                }
            }
        }
    }

    private var workHourSection: some View {
        Section("勤務時間") {
            if draft.workHourItems.isEmpty {
                Text("選択中の支給元に勤務時間項目はありません。設定タブの支給元編集から追加できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(draft.workHourItems, id: \.id) { item in
                    if let itemBinding = workHourItemBinding(for: item.id) {
                        EditableWorkHourEntryRow(
                            item: itemBinding,
                            note: isOrphanedWorkHourItem(item)
                                ? "この項目は設定から削除されています。必要なら設定で再追加してください。"
                                : nil
                        )
                    }
                }

                Text("設定した項目だけがここに表示されます。0時間の項目は保存時に省略されます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func itemSection(
        title: String,
        items: Binding<[EditableLineItem]>,
        addAction: @escaping () -> Void
    ) -> some View {
        Section(PayrollLocalization.text(title)) {
            ForEach(items.wrappedValue, id: \.id) { item in
                if let itemBinding = binding(for: item.id, in: items) {
                    EditableLineItemEditorRow(
                        item: itemBinding,
                        canMoveUp: canMoveItem(withID: item.id, direction: -1, in: items),
                        canMoveDown: canMoveItem(withID: item.id, direction: 1, in: items),
                        moveUp: {
                            moveItem(withID: item.id, direction: -1, in: items)
                        },
                        moveDown: {
                            moveItem(withID: item.id, direction: 1, in: items)
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            removeItem(withID: item.id, from: items)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }

            Button(action: addAction) {
                Label(PayrollLocalization.format("%@を追加", PayrollLocalization.text(title)), systemImage: "plus.circle")
            }

            if items.wrappedValue.count > 1 {
                Text("上下ボタンで並べ替え、スワイプで削除できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func workHourItemBinding(
        for id: UUID
    ) -> Binding<EditableWorkHourItem>? {
        guard draft.workHourItems.contains(where: { $0.id == id }) else {
            return nil
        }

        return Binding(
            get: {
                draft.workHourItems.first(where: { $0.id == id }) ?? EditableWorkHourItem(id: id)
            },
            set: { updatedValue in
                guard let index = draft.workHourItems.firstIndex(where: { $0.id == id }) else {
                    return
                }

                draft.workHourItems[index] = updatedValue
            }
        )
    }

    private func isOrphanedWorkHourItem(_ item: EditableWorkHourItem) -> Bool {
        guard let definitionID = item.definitionID else {
            return true
        }

        return !(selectedSource?.sortedWorkHourDefinitions.contains(where: { $0.id == definitionID }) ?? false)
    }

    private func synchronizeWorkHourItems(for sourceID: UUID?) {
        let definitions = sources.first(where: { $0.id == sourceID })?.sortedWorkHourDefinitions ?? []
        draft.synchronizeWorkHourItems(with: definitions, currentSourceID: sourceID)
    }

    private func binding(
        for id: UUID,
        in items: Binding<[EditableLineItem]>
    ) -> Binding<EditableLineItem>? {
        guard items.wrappedValue.contains(where: { $0.id == id }) else {
            return nil
        }

        return Binding(
            get: {
                items.wrappedValue.first(where: { $0.id == id }) ?? EditableLineItem(id: id)
            },
            set: { updatedValue in
                guard let currentIndex = items.wrappedValue.firstIndex(where: { $0.id == id }) else {
                    return
                }

                items.wrappedValue[currentIndex] = updatedValue
            }
        )
    }

    private func canMoveItem(
        withID id: UUID,
        direction: Int,
        in items: Binding<[EditableLineItem]>
    ) -> Bool {
        guard let index = items.wrappedValue.firstIndex(where: { $0.id == id }) else {
            return false
        }

        return items.wrappedValue.indices.contains(index + direction)
    }

    private func moveItem(
        withID id: UUID,
        direction: Int,
        in items: Binding<[EditableLineItem]>
    ) {
        guard let index = items.wrappedValue.firstIndex(where: { $0.id == id }) else {
            return
        }

        let destinationIndex = index + direction
        guard items.wrappedValue.indices.contains(destinationIndex) else {
            return
        }

        withAnimation {
            items.wrappedValue.swapAt(index, destinationIndex)
        }
    }

    private func removeItem(
        withID id: UUID,
        from items: Binding<[EditableLineItem]>
    ) {
        guard let index = items.wrappedValue.firstIndex(where: { $0.id == id }) else {
            return
        }

        items.wrappedValue.remove(at: index)
    }

    private var summarySection: some View {
        Section("サマリー") {
            LabeledContent("支給合計", value: draft.totalPayments.currencyText)
            LabeledContent("控除合計", value: draft.totalDeductions.currencyText)
            LabeledContent("手取り", value: draft.netAmount.currencyText)
        }
    }

    private var notesSection: some View {
        Section("メモ") {
            TextField("共有時に残したい補足や社内メモ", text: $draft.note, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private func save() {
        let lineItems = draft.normalizedPaymentItems.enumerated().map {
            PayrollLineItem(
                id: $0.element.id,
                name: $0.element.name.trimmed,
                amount: $0.element.amount,
                categoryRawValue: PayrollLineItemCategory.payment.rawValue,
                sortOrder: $0.offset
            )
        } + draft.normalizedDeductionItems.enumerated().map {
            PayrollLineItem(
                id: $0.element.id,
                name: $0.element.name.trimmed,
                amount: $0.element.amount,
                categoryRawValue: PayrollLineItemCategory.deduction.rawValue,
                sortOrder: $0.offset
            )
        }
        let workHourEntries = draft.normalizedWorkHourItems.enumerated().map {
            PayrollWorkHourEntry(
                id: $0.element.id,
                definitionID: $0.element.definitionID,
                name: $0.element.trimmedName,
                hours: $0.element.hours,
                sortOrder: $0.offset
            )
        }

        let components = Calendar.current.dateComponents([.year, .month], from: draft.paymentDate)
        let year = components.year ?? Calendar.current.component(.year, from: draft.paymentDate)
        let month = components.month ?? Calendar.current.component(.month, from: draft.paymentDate)
        let selectedSource = sources.first(where: { $0.id == draft.sourceID })
        let selectedTemplate = templates.first(where: { $0.id == draft.selectedTemplateID })

        if let record {
            record.kind = draft.kind
            record.periodYear = year
            record.periodMonth = month
            record.paymentDate = draft.paymentDate
            record.note = draft.note.trimmed
            record.source = selectedSource
            record.template = selectedTemplate
            record.replaceLineItems(with: lineItems, in: modelContext)
            record.replaceWorkHourEntries(with: workHourEntries, in: modelContext)
        } else {
            let record = PayrollRecord(
                kind: draft.kind,
                periodYear: year,
                periodMonth: month,
                paymentDate: draft.paymentDate,
                note: draft.note.trimmed,
                source: selectedSource,
                template: selectedTemplate
            )
            modelContext.insert(record)
            record.replaceLineItems(with: lineItems, in: modelContext)
            record.replaceWorkHourEntries(with: workHourEntries, in: modelContext)
        }

        try? modelContext.save()
        dismiss()
    }

    @MainActor
    private func importSelectedPhotoIfNeeded() async {
        guard let selectedSlipPhotoItem else {
            return
        }

        guard monetization.isPlusActive else {
            self.selectedSlipPhotoItem = nil
            plusSheet = .photoImport
            return
        }

        isImportingFromPhoto = true
        defer {
            isImportingFromPhoto = false
            self.selectedSlipPhotoItem = nil
        }

        do {
            guard let imageData = try await selectedSlipPhotoItem.loadTransferable(type: Data.self) else {
                throw PayrollSlipImportError.imageLoadFailed
            }

            let result = try await PayrollSlipImportService.importRecordDraft(
                from: imageData,
                fallbackKind: draft.kind,
                sourceID: draft.sourceID
            )

            draft.kind = result.kind
            draft.paymentDate = result.paymentDate
            draft.sourceID = result.sourceID ?? draft.sourceID
            draft.selectedTemplateID = nil
            draft.note = result.note
            draft.paymentItems = result.paymentItems.isEmpty ? [EditableLineItem()] : result.paymentItems
            draft.deductionItems = result.deductionItems.isEmpty ? [EditableLineItem()] : result.deductionItems
        } catch {
            importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct RecordDraftSummaryCard: View {
    let sourceName: String
    let kindTitle: String
    let paymentDateText: String
    let netAmount: Double
    let paymentTotal: Double
    let deductionTotal: Double
    let paymentItemCount: Int
    let deductionItemCount: Int
    let isValid: Bool
    let tint: Color

    var body: some View {
        PayrollSurfaceCard(cornerRadius: 26, padding: 18, tint: tint) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    PayrollIconBadge(systemImage: isValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill", tint: tint, size: 42)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(sourceName)
                            .font(.headline.weight(.bold))

                        Text(kindTitle + " / " + paymentDateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(PayrollLocalization.text(isValid ? "保存可能" : "未完了"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isValid ? tint : .orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background((isValid ? tint : Color.orange).opacity(0.12), in: Capsule())
                }

                Text(netAmount.currencyText)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                HStack(spacing: 10) {
                    RecordDraftMetric(title: "支給", value: paymentTotal.currencyText, detail: PayrollLocalization.countLabel(paymentItemCount), tint: .blue)
                    RecordDraftMetric(title: "控除", value: deductionTotal.currencyText, detail: PayrollLocalization.countLabel(deductionItemCount), tint: .orange)
                }
            }
        }
    }
}

private struct RecordDraftMetric: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(PayrollLocalization.text(title))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.subheadline.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct EditableWorkHourEntryRow: View {
    @Binding var item: EditableWorkHourItem
    let note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.name)
                    .font(.body.weight(.medium))

                Spacer()

                TextField(
                    "0",
                    value: $item.hours,
                    format: .number.precision(.fractionLength(0...2))
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)

                Text("時間")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let note {
                Text(PayrollLocalization.text(note))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct EditableLineItemEditorRow: View {
    @Binding var item: EditableLineItem
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                TextField("項目名", text: $item.name)

                Spacer()

                ControlGroup {
                    Button(action: moveUp) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(!canMoveUp)
                    .accessibilityLabel("上へ移動")

                    Button(action: moveDown) {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(!canMoveDown)
                    .accessibilityLabel("下へ移動")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }

            TextField(
                "金額",
                value: $item.amount,
                format: .number.precision(.fractionLength(0))
            )
            .keyboardType(.numberPad)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
