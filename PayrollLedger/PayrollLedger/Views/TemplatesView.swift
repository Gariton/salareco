import SwiftData
import SwiftUI

private enum TemplateSheet: Identifiable {
    case create
    case makeRecord(UUID)
    case share(UUID)
    case importShared

    var id: String {
        switch self {
        case .create:
            "create"
        case .makeRecord(let id):
            "record-\(id.uuidString)"
        case .share(let id):
            "share-\(id.uuidString)"
        case .importShared:
            "import-shared"
        }
    }
}

struct TemplatesView: View {
    @Environment(PayrollAppState.self) private var appState
    @Environment(PayrollMonetizationStore.self) private var monetization
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \PayrollRecord.paymentDate, order: .reverse) private var records: [PayrollRecord]
    @Query(sort: \PayrollTemplate.createdAt, order: .reverse) private var templates: [PayrollTemplate]

    @State private var activeSheet: TemplateSheet?
    @State private var plusSheet: PayrollPlusPaywall?

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 12) {
            SourceFilterBar(sources: sources, selectedSourceID: $appState.selectedSourceID)

            templateOverviewCard
                .padding(.horizontal)

            FreePlanBannerAdView(placement: .templates)

            if filteredTemplates.isEmpty {
                Spacer()
                EmptyStateCard(
                    title: "テンプレートがありません",
                    message: "毎月の給与や賞与のひな形を登録しておくと、記録作成が速くなります。",
                    systemImage: "square.stack.3d.up.slash",
                    actionTitle: "テンプレートを追加",
                    actionSystemImage: "plus.circle",
                    action: {
                        presentTemplateCreation()
                    }
                )
                Spacer()
            } else {
                List {
                    ForEach(filteredTemplates) { template in
                        NavigationLink(value: template.id) {
                            templateRow(template)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                activeSheet = .makeRecord(template.id)
                            } label: {
                                Label("記録を作成", systemImage: "plus.rectangle.on.rectangle")
                            }
                            .tint(Color(hex: template.source(in: sources)?.accentHex ?? "#0F766E"))
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                activeSheet = .share(template.id)
                            } label: {
                                Label("共有", systemImage: "qrcode")
                            }
                            .tint(.indigo)

                            Button(role: .destructive) {
                                delete(template)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .background(PayrollScreenBackground(accent: accentColor))
        .navigationTitle("テンプレート")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("テンプレートを追加") {
                        presentTemplateCreation()
                    }

                    Button("共有リンクを読み込む") {
                        presentTemplateImport()
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .create:
                    TemplateEditorView(initialSourceID: appState.selectedSourceID)
                case .makeRecord(let id):
                    RecordEditorView(
                        initialTemplate: templates.first(where: { $0.id == id }),
                        initialSourceID: appState.selectedSourceID
                    )
                case .share(let id):
                    if let template = templates.first(where: { $0.id == id }) {
                        TemplateSharePreviewView(
                            template: template,
                            source: template.source(in: sources)
                        )
                    }
                case .importShared:
                    TemplateImportView(
                        sources: sources,
                        initialSourceID: appState.selectedSourceID,
                        canCreateSharedSource: monetization.canCreateIncomeSource(currentCount: sources.count),
                        onImport: { payload, destination in
                            try importSharedTemplate(payload, destination: destination)
                        },
                        onImported: { template in
                            appState.selectedSourceID = template.sourceID
                        }
                    )
                }
            }
        }
        .navigationDestination(for: UUID.self) { templateID in
            if let template = templates.first(where: { $0.id == templateID }) {
                TemplateEditorView(
                    template: template,
                    presentation: .push
                )
            }
        }
        .sheet(item: $plusSheet) { paywall in
            NavigationStack {
                PlusPlanView(context: paywall)
            }
        }
    }

    private var filteredTemplates: [PayrollTemplate] {
        templates.filter { template in
            guard let selectedSourceID = appState.selectedSourceID else {
                return true
            }

            return template.sourceID == selectedSourceID
        }
    }

    private var selectedSource: IncomeSource? {
        guard let selectedSourceID = appState.selectedSourceID else {
            return nil
        }

        return sources.first(where: { $0.id == selectedSourceID })
    }

    private var accentColor: Color {
        selectedSource.map { Color(hex: $0.accentHex) } ?? Color(hex: "#0F766E")
    }

    private var templateNetPreviewTotal: Double {
        filteredTemplates.reduce(0) { $0 + $1.netPreviewAmount }
    }

    private var templateOverviewCard: some View {
        PayrollSurfaceCard(cornerRadius: 26, padding: 18, tint: accentColor) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    PayrollIconBadge(systemImage: "square.stack.3d.up", tint: accentColor, size: 42)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(selectedSource?.name ?? PayrollLocalization.text("すべての支給元"))
                            .font(.headline.weight(.bold))

                        Text(PayrollLocalization.format("テンプレート %lld件", Int64(filteredTemplates.count)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(templateNetPreviewTotal.currencyText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }

                HStack(spacing: 10) {
                    Button {
                        presentTemplateCreation()
                    } label: {
                        Label("追加", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        presentTemplateImport()
                    } label: {
                        Label("読込", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.regular)
            }
        }
    }

    private func delete(_ template: PayrollTemplate) {
        for record in records where record.templateID == template.id {
            record.template = nil
        }

        modelContext.delete(template)
        try? modelContext.save()
    }

    private func presentTemplateCreation() {
        guard monetization.canCreateTemplate(currentCount: templates.count) else {
            plusSheet = .templateLimit
            return
        }

        activeSheet = .create
    }

    private func presentTemplateImport() {
        guard monetization.canCreateTemplate(currentCount: templates.count) else {
            plusSheet = .templateLimit
            return
        }

        activeSheet = .importShared
    }

    private func importSharedTemplate(
        _ payload: PayrollTemplateSharePayload,
        destination: TemplateImportDestination
    ) throws -> PayrollTemplate {
        guard monetization.canCreateTemplate(currentCount: templates.count) else {
            throw PayrollMonetizationError.requiresPlus(.templateLimit)
        }

        let source: IncomeSource
        switch destination {
        case .existing(let sourceID):
            guard let existingSource = sources.first(where: { $0.id == sourceID }) else {
                throw PayrollTemplateShareCodec.ImportError.missingSource
            }
            source = existingSource
        case .sharedSource:
            guard monetization.canCreateIncomeSource(currentCount: sources.count) else {
                throw PayrollMonetizationError.requiresPlus(.incomeSourceLimit)
            }
            let newSource = PayrollTemplateShareCodec.incomeSource(from: payload)
            modelContext.insert(newSource)
            source = newSource
        }

        return try PayrollTemplateShareCodec.importTemplate(
            from: payload,
            source: source,
            existingTemplates: templates,
            in: modelContext
        )
    }

    private func templateRow(_ template: PayrollTemplate) -> some View {
        let rowTint = Color(hex: template.source(in: sources)?.accentHex ?? "#0F766E")

        return PayrollSurfaceCard(cornerRadius: 22, padding: 14, tint: rowTint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    PayrollIconBadge(systemImage: template.kind.systemImage, tint: rowTint, size: 42)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(template.name)
                            .font(.headline)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(template.source(in: sources)?.name ?? PayrollLocalization.text("支給元未設定"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)
                    
                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(template.netPreviewAmount.currencyText)
                            .font(.headline.weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)

                        Text("想定")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 84, alignment: .trailing)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        templateKindPill(template, tint: rowTint)
                        templatePaymentCountPill(template)
                        templateDeductionCountPill(template)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        templateKindPill(template, tint: rowTint)

                        HStack(spacing: 8) {
                            templatePaymentCountPill(template)
                            templateDeductionCountPill(template)
                        }
                    }
                }

                if !template.note.trimmed.isEmpty {
                    Text(template.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func templateKindPill(_ template: PayrollTemplate, tint: Color) -> some View {
        PayrollInfoPill(
            systemImage: template.kind.systemImage,
            text: template.kind.title,
            tint: tint
        )
    }

    private func templatePaymentCountPill(_ template: PayrollTemplate) -> some View {
        PayrollInfoPill(
            systemImage: "plus.circle",
            text: PayrollLocalization.format("支給 %lld件", Int64(template.paymentItems.count)),
            tint: .blue
        )
    }

    private func templateDeductionCountPill(_ template: PayrollTemplate) -> some View {
        PayrollInfoPill(
            systemImage: "minus.circle",
            text: PayrollLocalization.format("控除 %lld件", Int64(template.deductionItems.count)),
            tint: .orange
        )
    }
}
