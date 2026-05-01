import SwiftData
import SwiftUI

private enum RecordFilter: String, CaseIterable, Identifiable {
    case all
    case salary
    case bonus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            PayrollLocalization.text("すべて")
        case .salary:
            PayrollLocalization.text("給与")
        case .bonus:
            PayrollLocalization.text("賞与")
        }
    }
}

private enum RecordSheet: Identifiable {
    case create(PayrollRecordKind)

    var id: String {
        switch self {
        case .create(let kind):
            "create-\(kind.rawValue)"
        }
    }
}

struct RecordsView: View {
    @Environment(PayrollAppState.self) private var appState
    @Environment(PayrollMonetizationStore.self) private var monetization
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \PayrollRecord.paymentDate, order: .reverse) private var records: [PayrollRecord]

    @Namespace private var recordTransitionNamespace
    @State private var filter: RecordFilter = .all
    @State private var activeSheet: RecordSheet?
    @State private var shareRecord: PayrollRecord?
    @State private var plusSheet: PayrollPlusPaywall?
    @State private var csvExport: RecordCSVExport?
    @State private var exportErrorMessage: String?

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 12) {
            SourceFilterBar(sources: sources, selectedSourceID: $appState.selectedSourceID)

            recordOverviewCard
                .padding(.horizontal)

            FreePlanBannerAdView(placement: .records)

            Picker("種別", selection: $filter) {
                ForEach(RecordFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if filteredRecords.isEmpty {
                Spacer()
                EmptyStateCard(
                    title: "記録がありません",
                    message: sources.isEmpty
                        ? "まず設定タブで支給元を追加してください。"
                        : "新規ボタンから給与・賞与の明細を登録できます。",
                    systemImage: "doc.badge.plus",
                    actionTitle: sources.isEmpty ? nil : "給与を登録",
                    actionSystemImage: sources.isEmpty ? nil : PayrollRecordKind.salary.systemImage,
                    action: sources.isEmpty ? nil : {
                        activeSheet = .create(.salary)
                    }
                )
                Spacer()
            } else {
                List {
                    ForEach(recordSections) { section in
                        Section {
                            ForEach(section.records) { record in
                                recordListItem(record)
                            }
                        } header: {
                            sectionHeader(for: section)
                        }
                        .textCase(nil)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .background(PayrollScreenBackground(accent: accentColor))
        .navigationTitle("給与記録")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("給与を登録") {
                        activeSheet = .create(.salary)
                    }

                    Button("賞与を登録") {
                        activeSheet = .create(.bonus)
                    }

                    Divider()

                    Button {
                        exportCSV()
                    } label: {
                        Label("CSVを書き出し", systemImage: "tablecells.badge.ellipsis")
                    }
                    .disabled(filteredRecords.isEmpty)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(sources.isEmpty)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .create(let kind):
                    RecordEditorView(
                        initialKind: kind,
                        initialSourceID: appState.selectedSourceID
                    )
                }
            }
        }
        .navigationDestination(for: UUID.self) { recordID in
            if let record = records.first(where: { $0.id == recordID }) {
                PayrollRecordDetailView(
                    record: record,
                    source: record.source(in: sources)
                )
                .payrollNavigationZoom(id: record.id, in: recordTransitionNamespace)
            }
        }
        .sheet(item: $shareRecord) { record in
            NavigationStack {
                RecordSharePreviewView(
                    record: record,
                    source: record.source(in: sources)
                )
            }
        }
        .sheet(item: $plusSheet) { paywall in
            NavigationStack {
                PlusPlanView(context: paywall)
            }
        }
        .sheet(item: $csvExport) { export in
            NavigationStack {
                RecordCSVExportView(export: export)
            }
        }
        .alert("CSVを書き出せませんでした", isPresented: exportErrorIsPresented) {
            Button("閉じる") {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private var filteredRecords: [PayrollRecord] {
        records.filter { record in
            let matchesSource: Bool
            if let selectedSourceID = appState.selectedSourceID {
                matchesSource = record.sourceID == selectedSourceID
            } else {
                matchesSource = true
            }

            let matchesKind: Bool
            switch filter {
            case .all:
                matchesKind = true
            case .salary:
                matchesKind = record.kind == .salary
            case .bonus:
                matchesKind = record.kind == .bonus
            }

            return matchesSource && matchesKind
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

    private var filteredNetTotal: Double {
        filteredRecords.reduce(0) { $0 + $1.netAmount }
    }

    private var filteredPaymentTotal: Double {
        filteredRecords.reduce(0) { $0 + $1.totalPayments }
    }

    private var filteredDeductionTotal: Double {
        filteredRecords.reduce(0) { $0 + $1.totalDeductions }
    }

    private var latestFilteredRecord: PayrollRecord? {
        filteredRecords.first
    }

    private var recordSections: [RecordYearSection] {
        let groupedRecords = Dictionary(grouping: filteredRecords, by: \.periodYear)

        return groupedRecords.keys
            .sorted(by: >)
            .map { year in
                let records = groupedRecords[year] ?? []
                return RecordYearSection(
                    year: year,
                    records: records,
                    netTotal: records.reduce(0) { $0 + $1.netAmount }
                )
            }
    }

    private var recordOverviewCard: some View {
        PayrollSurfaceCard(cornerRadius: 26, padding: 18, tint: accentColor) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    PayrollIconBadge(systemImage: "list.bullet.clipboard", tint: accentColor, size: 42)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(selectedSource?.name ?? PayrollLocalization.text("すべての支給元"))
                            .font(.headline.weight(.bold))

                        Text(filter.title + " / " + PayrollLocalization.format("%lld件", Int64(filteredRecords.count)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(latestFilteredRecord?.paymentDate.mediumJapaneseDateText ?? PayrollLocalization.text("未登録"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }

                HStack(spacing: 10) {
                    RecordOverviewMetric(title: "手取り", value: filteredNetTotal.currencyText, tint: accentColor)
                    RecordOverviewMetric(title: "支給", value: filteredPaymentTotal.currencyText, tint: .blue)
                    RecordOverviewMetric(title: "控除", value: filteredDeductionTotal.currencyText, tint: .orange)
                }
            }
        }
    }

    private func sectionHeader(for section: RecordYearSection) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(section.year.yearDisplayText)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Text(PayrollLocalization.format("%1$lld件 / %2$@", Int64(section.records.count), section.netTotal.currencyText))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func recordListItem(_ record: PayrollRecord) -> some View {
        NavigationLink(value: record.id) {
            recordRow(record)
                .payrollTransitionSource(id: record.id, in: recordTransitionNamespace)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                shareRecord = record
            } label: {
                Label("共有", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                delete(record)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func recordRow(_ record: PayrollRecord) -> some View {
        let rowTint = Color(hex: record.source(in: sources)?.accentHex ?? "#0F766E")

        return PayrollSurfaceCard(cornerRadius: 22, padding: 14, tint: rowTint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    PayrollIconBadge(systemImage: record.kind.systemImage, tint: rowTint, size: 48)

                    VStack(alignment: .leading, spacing: 5) {
//                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(record.periodMonth.monthDisplayText)
                                .font(.headline)
                                .lineLimit(1)

                            Text(record.kind.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(rowTint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(rowTint.opacity(0.12), in: Capsule())
//                        }
                    }
                    .layoutPriority(1)
                    
                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(record.netAmount.currencyText)
                            .font(.headline.weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)

                        Text("手取り")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 84, alignment: .trailing)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        recordPaymentSourcePill(record)
                        recordPaymentDatePill(record)
                        recordPaymentTotalPill(record)
                        recordDeductionTotalPill(record)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            recordPaymentSourcePill(record)
                            recordPaymentDatePill(record)
                        }

                        HStack(spacing: 8) {
                            recordPaymentTotalPill(record)
                            recordDeductionTotalPill(record)
                        }
                    }
                }

                if !record.note.trimmed.isEmpty {
                    Text(record.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func recordPaymentDatePill(_ record: PayrollRecord) -> some View {
        PayrollInfoPill(
            systemImage: "calendar",
            text: record.paymentDate.monthDayJapaneseDateText,
            tint: Color(.secondaryLabel)
        )
    }
    
    private func recordPaymentSourcePill(_ record: PayrollRecord) -> some View {
        PayrollInfoPill(
            systemImage: "building.2.crop.circle",
            text: record.source(in: sources)?.name ?? PayrollLocalization.text("支給元未設定"),
            tint: Color(.secondaryLabel)
        )
    }

    private func recordPaymentTotalPill(_ record: PayrollRecord) -> some View {
        PayrollInfoPill(
            systemImage: "plus.circle",
            text: PayrollLocalization.format("支給 %@", record.totalPayments.currencyText),
            tint: .blue
        )
    }

    private func recordDeductionTotalPill(_ record: PayrollRecord) -> some View {
        PayrollInfoPill(
            systemImage: "minus.circle",
            text: PayrollLocalization.format("控除 %@", record.totalDeductions.currencyText),
            tint: .orange
        )
    }

    private func delete(_ record: PayrollRecord) {
        modelContext.delete(record)
        try? modelContext.save()
    }

    private var exportErrorIsPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
    }

    private func exportCSV() {
        guard monetization.canExportCSV() else {
            plusSheet = .csvExport
            return
        }

        do {
            let title = selectedSource?.name ?? "payroll-records"
            let url = try PayrollCSVExporter.exportURL(
                for: filteredRecords,
                sources: sources,
                title: title
            )
            csvExport = RecordCSVExport(url: url, recordCount: filteredRecords.count)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

private struct RecordYearSection: Identifiable {
    let year: Int
    let records: [PayrollRecord]
    let netTotal: Double

    var id: Int { year }
}

private struct RecordCSVExport: Identifiable {
    let id = UUID()
    let url: URL
    let recordCount: Int
}

private struct RecordCSVExportView: View {
    let export: RecordCSVExport

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                ShareLink(item: export.url) {
                    Label("CSVを共有", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Section("書き出し内容") {
                LabeledContent("記録件数", value: PayrollLocalization.countLabel(export.recordCount))
                LabeledContent("ファイル名", value: export.url.lastPathComponent)
            }
        }
        .navigationTitle("CSVを書き出し")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
    }
}

private struct RecordOverviewMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PayrollLocalization.text(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
