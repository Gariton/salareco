import SwiftData
import SwiftUI

enum TemplateEditorPresentation {
    case modal
    case push
}

struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PayrollMonetizationStore.self) private var monetization

    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @State private var draft: TemplateDraft

    private let template: PayrollTemplate?
    private let presentation: TemplateEditorPresentation

    init(
        template: PayrollTemplate? = nil,
        initialSourceID: UUID? = nil,
        presentation: TemplateEditorPresentation = .modal
    ) {
        self.template = template
        self.presentation = presentation
        _draft = State(initialValue: TemplateDraft(template: template, initialSourceID: initialSourceID))
    }

    var body: some View {
        Form {
            templateSummarySection
            if !monetization.isPlusActive {
                Section {
                    FreePlanBannerAdView(placement: .templateEditor, horizontalPadding: false)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section("基本情報") {
                TextField("テンプレート名", text: $draft.name)

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
            }

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

            Section("メモ") {
                TextField("新規記録へ引き継ぐ補足", text: $draft.note, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("サマリー") {
                LabeledContent("支給合計", value: draft.totalPayments.currencyText)
                LabeledContent("控除合計", value: draft.totalDeductions.currencyText)
                LabeledContent("想定手取り", value: draft.netAmount.currencyText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PayrollScreenBackground(accent: accentColor))
        .navigationTitle(PayrollLocalization.text(template == nil ? "テンプレートを追加" : "テンプレートを編集"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentation == .modal {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
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
        }
    }

    private var selectedSource: IncomeSource? {
        sources.first(where: { $0.id == draft.sourceID })
    }

    private var accentColor: Color {
        selectedSource.map { Color(hex: $0.accentHex) } ?? Color(hex: "#0F766E")
    }

    private var templateSummarySection: some View {
        Section {
            TemplateDraftSummaryCard(
                templateName: draft.name.trimmed.isEmpty ? PayrollLocalization.text("テンプレート名未入力") : draft.name.trimmed,
                sourceName: selectedSource?.name ?? PayrollLocalization.text("支給元未選択"),
                kindTitle: draft.kind.title,
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

    private func itemSection(
        title: String,
        items: Binding<[EditableLineItem]>,
        addAction: @escaping () -> Void
    ) -> some View {
        Section(PayrollLocalization.text(title)) {
            ForEach(items.wrappedValue, id: \.id) { item in
                if let itemBinding = binding(for: item.id, in: items) {
                    TemplateEditableLineItemEditorRow(
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
        let selectedSource = sources.first(where: { $0.id == draft.sourceID })

        if let template {
            template.name = draft.name.trimmed
            template.kind = draft.kind
            template.source = selectedSource
            template.note = draft.note.trimmed
            template.replaceLineItems(with: lineItems, in: modelContext)
        } else {
            let template = PayrollTemplate(
                name: draft.name.trimmed,
                kind: draft.kind,
                note: draft.note.trimmed,
                source: selectedSource
            )
            modelContext.insert(template)
            template.replaceLineItems(with: lineItems, in: modelContext)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct TemplateDraftSummaryCard: View {
    let templateName: String
    let sourceName: String
    let kindTitle: String
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
                    PayrollIconBadge(systemImage: isValid ? "square.stack.3d.up.fill" : "square.stack.3d.up.slash", tint: tint)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(templateName)
                            .font(.headline.weight(.bold))
                            .lineLimit(1)

                        Text(sourceName + " / " + kindTitle)
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
                    TemplateDraftMetric(title: "支給", value: paymentTotal.currencyText, detail: PayrollLocalization.countLabel(paymentItemCount), tint: .blue)
                    TemplateDraftMetric(title: "控除", value: deductionTotal.currencyText, detail: PayrollLocalization.countLabel(deductionItemCount), tint: .orange)
                }
            }
        }
    }
}

private struct TemplateDraftMetric: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack() {
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

private struct TemplateEditableLineItemEditorRow: View {
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
