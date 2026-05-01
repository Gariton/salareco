import SwiftUI

struct PayrollRecordDetailView: View {
    let record: PayrollRecord
    let source: IncomeSource?

    @State private var isShowingCopyComposer = false
    @State private var isShowingEditor = false
    @State private var isShowingSharePreview = false

    private var accentColor: Color {
        Color(hex: source?.accentHex ?? "#0F766E")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard

                FreePlanBannerAdView(placement: .recordDetail, horizontalPadding: false)

                summarySection

                lineItemSection(
                    title: "支給項目",
                    items: record.paymentItems,
                    emptyMessage: "支給項目は登録されていません。",
                    tint: Color(hex: "#059669")
                )

                if !record.deductionItems.isEmpty {
                    lineItemSection(
                        title: "控除項目",
                        items: record.deductionItems,
                        emptyMessage: "控除項目は登録されていません。",
                        tint: Color(hex: "#DC2626")
                    )
                }

                if !record.sortedWorkHourEntries.isEmpty {
                    workHourSection
                }

                if !record.note.trimmed.isEmpty {
                    noteSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(record.titleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isShowingSharePreview = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                Button("編集") {
                    isShowingEditor = true
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                RecordEditorView(record: record)
            }
        }
        .sheet(isPresented: $isShowingCopyComposer) {
            NavigationStack {
                RecordEditorView(
                    initialKind: record.kind,
                    initialSourceID: record.sourceID,
                    copySourceRecord: record
                )
            }
        }
        .sheet(isPresented: $isShowingSharePreview) {
            NavigationStack {
                RecordSharePreviewView(record: record, source: source)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(source?.name ?? PayrollLocalization.text("支給元未設定"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))

                    Text(record.netAmount.currencyText)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(record.paymentDate.mediumJapaneseDateText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.74))
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    kindBadge

                    Text(record.titleText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack(spacing: 10) {
                summaryPill(title: "支給", value: record.totalPayments.currencyText)
                summaryPill(title: "控除", value: record.totalDeductions.currencyText)
                summaryPill(title: "項目数", value: PayrollLocalization.countLabel(record.paymentItems.count + record.deductionItems.count))
            }

            Button {
                isShowingCopyComposer = true
            } label: {
                Label("この内容をコピーして新規登録", systemImage: "plus.square.on.square")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    accentColor,
                    Color(hex: "#0F172A"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 160, height: 160)
                .blur(radius: 14)
                .offset(x: 24, y: 22)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("概要")
                .font(.headline)

            VStack(spacing: 12) {
                summaryRow(title: "種別", value: record.kind.title)
                summaryRow(title: "支給元", value: source?.name ?? PayrollLocalization.text("未設定"))
                summaryRow(title: "支給日", value: record.paymentDate.mediumJapaneseDateText)
                if !record.sortedWorkHourEntries.isEmpty {
                    summaryRow(title: "勤務時間合計", value: record.totalWorkHours.hourText)
                }
                summaryRow(title: "手取り", value: record.netAmount.currencyText, emphasize: true)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func lineItemSection(
        title: String,
        items: [PayrollLineItem],
        emptyMessage: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(PayrollLocalization.text(title))
                .font(.headline)

            if items.isEmpty {
                Text(PayrollLocalization.text(emptyMessage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(tint.opacity(0.18))
                            .frame(width: 30, height: 30)
                            .overlay {
                                Circle()
                                    .fill(tint)
                                    .frame(width: 10, height: 10)
                            }

                        Text(item.name)
                            .font(.body.weight(.medium))

                        Spacer()

                        Text(item.amount.currencyText)
                            .font(.body.weight(.semibold))
                    }
                    .padding(.vertical, 4)

                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var workHourSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("勤務時間")
                .font(.headline)

            ForEach(record.sortedWorkHourEntries) { entry in
                HStack(spacing: 12) {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 30, height: 30)
                        .overlay {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 10, height: 10)
                        }

                    Text(entry.name)
                        .font(.body.weight(.medium))

                    Spacer()

                    Text(entry.hours.hourText)
                        .font(.body.weight(.semibold))
                }
                .padding(.vertical, 4)

                if entry.id != record.sortedWorkHourEntries.last?.id {
                    Divider()
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メモ")
                .font(.headline)

            Text(record.note)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var kindBadge: some View {
        Label(record.kind.title, systemImage: record.kind.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PayrollLocalization.text(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryRow(title: String, value: String, emphasize: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(PayrollLocalization.text(title))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(emphasize ? .headline.weight(.bold) : .subheadline.weight(.semibold))
                .foregroundStyle(emphasize ? accentColor : .primary)
        }
    }
}

extension View {
    @ViewBuilder
    func payrollTransitionSource<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func payrollNavigationZoom<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
