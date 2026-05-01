import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(PayrollAppState.self) private var appState
    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \PayrollRecord.paymentDate, order: .reverse) private var records: [PayrollRecord]

    @Namespace private var recordTransitionNamespace
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var activeComposerKind: PayrollRecordKind?

    var body: some View {
        @Bindable var appState = appState

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SourceFilterBar(sources: sources, selectedSourceID: $appState.selectedSourceID)

                yearFilterSection

                heroSection
                    .padding(.horizontal)

                FreePlanBannerAdView(placement: .dashboard)

                metricsSection
                
                FreePlanBannerAdView(placement: .dashboard)

                trendSection
                
                FreePlanBannerAdView(placement: .dashboard)

                recordsSection
            }
            .padding(.vertical)
        }
        .background(PayrollScreenBackground(accent: trendTint))
        .navigationTitle("ダッシュボード")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        activeComposerKind = .salary
                    } label: {
                        Label("給与を登録", systemImage: PayrollRecordKind.salary.systemImage)
                    }

                    Button {
                        activeComposerKind = .bonus
                    } label: {
                        Label("賞与を登録", systemImage: PayrollRecordKind.bonus.systemImage)
                    }
                } label: {
                    Label("記録を追加", systemImage: "plus")
                }
                .disabled(sources.isEmpty)
            }
        }
        .sheet(item: $activeComposerKind) { kind in
            NavigationStack {
                RecordEditorView(
                    initialKind: kind,
                    initialSourceID: appState.selectedSourceID
                )
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
        .task(id: availableYears) {
            synchronizeYearSelection()
        }
    }

    private var selectedSource: IncomeSource? {
        guard let selectedSourceID = appState.selectedSourceID else {
            return nil
        }

        return sources.first(where: { $0.id == selectedSourceID })
    }

    private var scopedRecords: [PayrollRecord] {
        records.filter { record in
            guard let selectedSourceID = appState.selectedSourceID else {
                return true
            }

            return record.sourceID == selectedSourceID
        }
    }

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        return Array(Set(scopedRecords.map(\.periodYear) + [currentYear])).sorted(by: >)
    }

    private var yearScopedRecords: [PayrollRecord] {
        scopedRecords.filter { $0.periodYear == selectedYear }
    }

    private var yearNetTotal: Double {
        yearScopedRecords.reduce(0) { $0 + $1.netAmount }
    }

    private var yearPaymentTotal: Double {
        yearScopedRecords.reduce(0) { $0 + $1.totalPayments }
    }

    private var yearDeductionTotal: Double {
        yearScopedRecords.reduce(0) { $0 + $1.totalDeductions }
    }

    private var yearBonusTotal: Double {
        yearScopedRecords
            .filter { $0.kind == .bonus }
            .reduce(0) { $0 + $1.netAmount }
    }

    private var deductionRate: Double {
        guard yearPaymentTotal > 0 else {
            return 0
        }

        return yearDeductionTotal / yearPaymentTotal
    }

    private var monthlyTrend: [MonthTrendEntry] {
        let grouped = Dictionary(grouping: yearScopedRecords, by: \.periodMonth)

        return (1...12).map { month in
            let monthlyRecords = grouped[month] ?? []
            return MonthTrendEntry(
                month: month,
                paymentTotal: monthlyRecords.reduce(0) { $0 + $1.totalPayments },
                deductionTotal: monthlyRecords.reduce(0) { $0 + $1.totalDeductions },
                netTotal: monthlyRecords.reduce(0) { $0 + $1.netAmount }
            )
        }
    }

    private var monthlyTrendSeries: [MonthTrendSeriesPoint] {
        monthlyTrend.flatMap { entry in
            [
                MonthTrendSeriesPoint(month: entry.month, kind: .payment, value: entry.paymentTotal),
                MonthTrendSeriesPoint(month: entry.month, kind: .deduction, value: entry.deductionTotal),
                MonthTrendSeriesPoint(month: entry.month, kind: .net, value: entry.netTotal),
            ]
        }
    }

    private var trendTint: Color {
        selectedAccent
    }

    private var selectedAccent: Color {
        selectedSource.map { Color(hex: $0.accentHex) } ?? Color(hex: "#0F766E")
    }

    private var salaryRecordCount: Int {
        yearScopedRecords.filter { $0.kind == .salary }.count
    }

    private var bonusRecordCount: Int {
        yearScopedRecords.filter { $0.kind == .bonus }.count
    }

    private var latestYearRecord: PayrollRecord? {
        yearScopedRecords.sorted { lhs, rhs in
            lhs.paymentDate > rhs.paymentDate
        }
        .first
    }

    private var maxTrendValue: Double {
        max(
            monthlyTrend
                .flatMap { [$0.paymentTotal, $0.deductionTotal, $0.netTotal] }
                .max() ?? 1,
            1
        )
    }

    private var peakPaymentTrendEntry: MonthTrendEntry? {
        guard let entry = monthlyTrend.max(by: { lhs, rhs in
            lhs.paymentTotal < rhs.paymentTotal
        }), entry.paymentTotal > 0 else {
            return nil
        }

        return entry
    }

    private var peakDeductionTrendEntry: MonthTrendEntry? {
        guard let entry = monthlyTrend.max(by: { lhs, rhs in
            lhs.deductionTotal < rhs.deductionTotal
        }), entry.deductionTotal > 0 else {
            return nil
        }

        return entry
    }

    private var averageNetTrendValue: Double {
        monthlyTrend.reduce(0) { $0 + $1.netTotal } / Double(monthlyTrend.count)
    }

    private var yearFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("対象年")
                    .font(.headline)

                Spacer()

                Text(PayrollLocalization.format("%lld件の記録", Int64(yearScopedRecords.count)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableYears, id: \.self) { year in
                        Button {
                            selectedYear = year
                        } label: {
                            Text(year.yearDisplayText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedYear == year ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(selectedYear == year ? selectedAccent : Color(.secondarySystemBackground))
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(selectedYear == year ? .white.opacity(0.22) : selectedAccent.opacity(0.12), lineWidth: 1)
                                }
                                .shadow(color: selectedYear == year ? selectedAccent.opacity(0.20) : .clear, radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedSource?.name ?? PayrollLocalization.text("全支給元"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))

                    Text(PayrollLocalization.format("%@の手取り合計", selectedYear.yearDisplayText))
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 12)

                Label(selectedYear.yearDisplayText, systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.13), in: Capsule())
            }

            Text(yearNetTotal.currencyText)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.64)

            HStack(spacing: 10) {
                DashboardHeroPill(title: "支給", value: yearPaymentTotal.currencyText)
                DashboardHeroPill(title: "控除", value: yearDeductionTotal.currencyText)
                DashboardHeroPill(title: "控除率", value: deductionRate.formatted(.percent.precision(.fractionLength(0))))
            }

            if sources.isEmpty {
                Button {
                    appState.selectedTab = .settings
                } label: {
                    Label("支給元を設定", systemImage: "building.2.crop.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 12) {
                    Button {
                        activeComposerKind = .salary
                    } label: {
                        Label("給与を追加", systemImage: PayrollRecordKind.salary.systemImage)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Button {
                        activeComposerKind = .bonus
                    } label: {
                        Label("賞与", systemImage: PayrollRecordKind.bonus.systemImage)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }

            Text(
                sources.isEmpty
                    ? PayrollLocalization.text("まず支給元を追加すると、登録、集計、テンプレートの色と絞り込みがそろいます。")
                    : yearScopedRecords.isEmpty
                    ? PayrollLocalization.text("この年の記録はまだありません。最初の給与明細を登録すると推移が育ちます。")
                    : PayrollLocalization.format(
                        "給与 %1$lld件 / 賞与 %2$lld件 / 直近 %@",
                        Int64(salaryRecordCount),
                        Int64(bonusRecordCount),
                        latestYearRecord?.paymentDate.mediumJapaneseDateText ?? "-"
                    )
            )
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.80))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    selectedAccent,
                    Color(hex: "#111827"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 86, weight: .bold))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 8, y: 18)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: selectedAccent.opacity(0.26), radius: 28, x: 0, y: 18)
    }

    private var metricsSection: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
            ],
            spacing: 14
        ) {
            MetricCard(
                title: "年間手取り",
                value: yearNetTotal.currencyText,
                caption: PayrollLocalization.format("%@の総額", selectedYear.yearDisplayText),
                iconName: "banknote",
                tint: .green
            )
            MetricCard(
                title: "年間支給総額",
                value: yearPaymentTotal.currencyText,
                caption: "給与と賞与の支給合計",
                iconName: "plus.circle",
                tint: .blue
            )
            MetricCard(
                title: "年間控除総額",
                value: yearDeductionTotal.currencyText,
                caption: deductionRate.formatted(.percent.precision(.fractionLength(0))),
                iconName: "minus.circle",
                tint: .orange
            )
            MetricCard(
                title: "賞与手取り合計",
                value: yearBonusTotal.currencyText,
                caption: PayrollLocalization.format("%@分", selectedYear.yearDisplayText),
                iconName: "sparkles",
                tint: .purple
            )
        }
        .padding(.horizontal)
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(PayrollLocalization.format("%@の月次推移", selectedYear.yearDisplayText))
                .font(.headline)
                .padding(.horizontal)

            if yearScopedRecords.isEmpty {
                EmptyStateCard(
                    title: "年次統計がありません",
                    message: "対象年の給与記録を追加すると、月ごとの推移を確認できます。",
                    systemImage: "chart.bar.doc.horizontal",
                    actionTitle: sources.isEmpty ? nil : "給与を追加",
                    actionSystemImage: sources.isEmpty ? nil : PayrollRecordKind.salary.systemImage,
                    action: sources.isEmpty ? nil : {
                        activeComposerKind = .salary
                    }
                )
            } else {
                PayrollSurfaceCard(cornerRadius: 24, padding: 18, tint: trendTint) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            TrendLegendBadge(title: PayrollLocalization.text("支給"), tint: .blue)
                            TrendLegendBadge(title: PayrollLocalization.text("控除"), tint: .orange)
                            TrendLegendBadge(title: PayrollLocalization.text("手取り"), tint: trendTint)
                        }
                        .font(.caption.weight(.semibold))

                        Chart(monthlyTrendSeries) { point in
                            LineMark(
                                x: .value(PayrollLocalization.text("月"), point.month),
                                y: .value(PayrollLocalization.text("金額"), point.value),
                                series: .value(PayrollLocalization.text("区分"), point.kind.title)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(by: .value(PayrollLocalization.text("区分"), point.kind.title))

                            PointMark(
                                x: .value(PayrollLocalization.text("月"), point.month),
                                y: .value(PayrollLocalization.text("金額"), point.value)
                            )
                            .symbolSize(point.kind == .net ? 52 : 44)
                            .foregroundStyle(by: .value(PayrollLocalization.text("区分"), point.kind.title))
                        }
                        .frame(height: 252)
                        .chartXScale(domain: 1...12)
                        .chartYScale(domain: 0...(maxTrendValue * 1.18))
                        .chartForegroundStyleScale([
                            TrendSeriesKind.payment.title: Color.blue,
                            TrendSeriesKind.deduction.title: Color.orange,
                            TrendSeriesKind.net.title: trendTint,
                        ])
                        .chartLegend(.hidden)
                        .chartXAxis {
                            AxisMarks(values: Array(1...12)) { value in
                                AxisGridLine().foregroundStyle(.clear)
                                AxisTick()
                                    .foregroundStyle(.secondary.opacity(0.24))
                                AxisValueLabel {
                                    if let month = value.as(Int.self) {
                                        Text(PayrollLocalization.monthLabel(month, abbreviated: true))
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                                    .foregroundStyle(.secondary.opacity(0.18))
                                AxisTick().foregroundStyle(.clear)
                                AxisValueLabel {
                                    if let amount = value.as(Double.self) {
                                        Text(compactCurrencyText(for: amount))
                                            .font(.caption2)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            if let peakPaymentTrendEntry {
                                Label(
                                    PayrollLocalization.format(
                                        "%@の支給が最多",
                                        PayrollLocalization.monthLabel(peakPaymentTrendEntry.month, abbreviated: true)
                                    ),
                                    systemImage: "arrow.up.forward.circle"
                                )
                            }

                            if let peakDeductionTrendEntry {
                                Label(
                                    PayrollLocalization.format(
                                        "%@の控除が最多",
                                        PayrollLocalization.monthLabel(peakDeductionTrendEntry.month, abbreviated: true)
                                    ),
                                    systemImage: "arrow.down.forward.circle"
                                )
                            }

                            if peakPaymentTrendEntry == nil && peakDeductionTrendEntry == nil {
                                Label("推移を集計中", systemImage: "chart.line.uptrend.xyaxis")
                            }

                            Label(
                                PayrollLocalization.format("月平均 %@", averageNetTrendValue.currencyText),
                                systemImage: "equal.circle"
                            )
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(PayrollLocalization.format("%@の記録", selectedYear.yearDisplayText))
                    .font(.headline)

                Spacer()

                if !yearScopedRecords.isEmpty {
                    Button {
                        appState.selectedTab = .records
                    } label: {
                        Label("すべて見る", systemImage: "arrow.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal)

            if yearScopedRecords.isEmpty {
                EmptyStateCard(
                    title: "対象年の記録がありません",
                    message: sources.isEmpty
                        ? "まず設定タブで支給元を追加してください。"
                        : "右上のボタンから給与や賞与を登録できます。",
                    systemImage: "tray",
                    actionTitle: sources.isEmpty ? nil : "給与を登録",
                    actionSystemImage: sources.isEmpty ? nil : PayrollRecordKind.salary.systemImage,
                    action: sources.isEmpty ? nil : {
                        activeComposerKind = .salary
                    }
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(yearScopedRecords.prefix(4))) { record in
                        NavigationLink(value: record.id) {
                            dashboardRecordCard(record)
                                .payrollTransitionSource(id: record.id, in: recordTransitionNamespace)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func synchronizeYearSelection() {
        guard !availableYears.isEmpty else {
            selectedYear = Calendar.current.component(.year, from: .now)
            return
        }

        if !availableYears.contains(selectedYear) {
            selectedYear = availableYears.first ?? Calendar.current.component(.year, from: .now)
        }
    }

    private func compactCurrencyText(for amount: Double) -> String {
        amount.compactCurrencyText
    }

    private func dashboardRecordCard(_ record: PayrollRecord) -> some View {
        PayrollSurfaceCard(cornerRadius: 22, padding: 16, tint: selectedAccent) {
            HStack(alignment: .center, spacing: 14) {
                PayrollIconBadge(systemImage: record.kind.systemImage, tint: selectedAccent, size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(record.periodMonth.monthDisplayText)
                            .font(.headline)

                        Text(record.kind.title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(selectedAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedAccent.opacity(0.12), in: Capsule())
                    }
                    .lineLimit(1)

                    Text(record.source(in: sources)?.name ?? PayrollLocalization.text("支給元未設定"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(record.netAmount.currencyText)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(record.paymentDate.monthDayJapaneseDateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 84, alignment: .trailing)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct MonthTrendEntry: Identifiable {
    let month: Int
    let paymentTotal: Double
    let deductionTotal: Double
    let netTotal: Double

    var id: Int { month }
}

private enum TrendSeriesKind: String {
    case payment
    case deduction
    case net

    var title: String {
        switch self {
        case .payment:
            PayrollLocalization.text("支給")
        case .deduction:
            PayrollLocalization.text("控除")
        case .net:
            PayrollLocalization.text("手取り")
        }
    }
}

private struct MonthTrendSeriesPoint: Identifiable {
    let month: Int
    let kind: TrendSeriesKind
    let value: Double

    var id: String {
        "\(kind.rawValue)-\(month)"
    }
}

private struct TrendLegendBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(title)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DashboardHeroPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PayrollLocalization.text(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
