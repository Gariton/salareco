import SwiftUI
import UIKit

struct RecordSharePreviewView: View {
    let record: PayrollRecord
    let source: IncomeSource?

    @AppStorage(SharePrivacyOptions.hideSourceNameKey) private var hideSourceName = false
    @AppStorage(SharePrivacyOptions.hideAmountsKey) private var hideAmounts = false
    @AppStorage(SharePrivacyOptions.hideBreakdownKey) private var hideBreakdown = false
    @AppStorage(SharePrivacyOptions.hideNotesKey) private var hideNotes = true

    @State private var isShowingCopiedBanner = false

    private var privacyOptions: SharePrivacyOptions {
        SharePrivacyOptions(
            hideSourceName: hideSourceName,
            hideAmounts: hideAmounts,
            hideBreakdown: hideBreakdown,
            hideNotes: hideNotes
        )
    }

    private var sharedPayload: PayrollRecordSharePayload {
        PayrollRecordShareCodec.sharePayload(
            for: record,
            source: source,
            privacyOptions: privacyOptions
        )
    }

    private var shareURL: URL {
        PayrollRecordShareCodec.exportURL(
            for: record,
            source: source,
            privacyOptions: privacyOptions
        )
    }

    private var accentColor: Color {
        Color(hex: sharedPayload.accentHex)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("給与データ共有")
                    .font(.title3.weight(.bold))

                Text("リンクを開くか QR コードを読み取ると、共有された給与データをアプリ内でそのまま閲覧できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ShareQRCodeCard(
                    urlString: shareURL.absoluteString,
                    accentColor: accentColor,
                    caption: "別の端末では QR コードを読み取るだけで表示できます。"
                )

                ShareLink(
                    item: shareURL,
                    subject: Text(PayrollLocalization.format("給与データ: %@", sharedPayload.titleText)),
                    message: Text("リンクを開くと、給与管理アプリ内で共有データを表示できます。")
                ) {
                    Label("リンクを共有", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(accentColor)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    UIPasteboard.general.url = shareURL
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        isShowingCopiedBanner = true
                    }

                    Task {
                        try? await Task.sleep(for: .seconds(1.8))
                        await MainActor.run {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                isShowingCopiedBanner = false
                            }
                        }
                    }
                } label: {
                    Label("リンクをコピー", systemImage: "link")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)

                if isShowingCopiedBanner {
                    Text("共有リンクをクリップボードへコピーしました。")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !sharedPayload.privacyBadges.isEmpty {
                    SharedPrivacyBadgeSection(
                        title: "共有範囲",
                        subtitle: "設定タブの共有設定を反映しています。",
                        badges: sharedPayload.privacyBadges,
                        accentColor: accentColor
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("相手には次の見た目で表示されます。")
                        .font(.subheadline.weight(.semibold))

                    SharedPayrollRecordCardView(payload: sharedPayload)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("給与記録を共有")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SharedPayrollRecordView: View {
    let payload: PayrollRecordSharePayload

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("共有された給与データ")
                    .font(.title3.weight(.bold))

                Text("この給与データは共有リンクから表示しています。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !payload.privacyBadges.isEmpty {
                    SharedPrivacyBadgeSection(
                        title: "非表示になっている項目",
                        subtitle: "共有元の設定により、一部の情報は表示していません。",
                        badges: payload.privacyBadges,
                        accentColor: Color(hex: payload.accentHex)
                    )
                }

                SharedPayrollRecordCardView(payload: payload)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("共有データ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
    }
}

private struct SharedPrivacyBadgeSection: View {
    let title: String
    let subtitle: String
    let badges: [String]
    let accentColor: Color

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(PayrollLocalization.text(title))
                .font(.headline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(badges, id: \.self) { badge in
                    Text(PayrollLocalization.text(badge))
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(accentColor.opacity(0.12))
                        )
                }
            }

            Text(PayrollLocalization.text(subtitle))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct SharedPayrollRecordCardView: View {
    let payload: PayrollRecordSharePayload

    private var accentColor: Color {
        Color(hex: payload.accentHex)
    }

    private var heroAmountText: String {
        payload.netAmount?.currencyText ?? PayrollLocalization.text("非公開")
    }

    private var displayedSourceName: String {
        if let sourceName = payload.displaySourceName {
            return sourceName
        }

        return payload.isSourceNameHidden
            ? PayrollLocalization.text("共有された給与データ")
            : PayrollLocalization.text("未設定")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heroCard
            summarySection

            if payload.amountVisibility == .breakdown {
                lineItemSection(
                    title: "支給項目",
                    items: payload.paymentItems,
                    emptyMessage: "支給項目は含まれていません。",
                    tint: Color(hex: "#059669")
                )

                if !payload.deductionItems.isEmpty {
                    lineItemSection(
                        title: "控除項目",
                        items: payload.deductionItems,
                        emptyMessage: "控除項目は含まれていません。",
                        tint: Color(hex: "#DC2626")
                    )
                }
            }

            if payload.amountVisibility != .breakdown && payload.workHourItemCount > 0 {
                compactInfoCard(
                    title: "勤務時間",
                    value: PayrollLocalization.countLabel(payload.workHourItemCount),
                    description: "勤務時間の内訳は共有元の設定により表示していません。"
                )
            }

            if !payload.workHourEntries.isEmpty {
                workHourSection
            }

            if let note = payload.note {
                noteSection(note)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayedSourceName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))

                    Text(heroAmountText)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(payload.paymentDate.mediumJapaneseDateText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.74))
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    kindBadge

                    Text(payload.titleText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack(spacing: 10) {
                ForEach(heroMetrics) { metric in
                    heroMetricPill(title: metric.title, value: metric.value)
                }
            }
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
                summaryRow(title: "種別", value: payload.kind.title)
                summaryRow(
                    title: "支給元",
                    value: payload.displaySourceName
                        ?? (payload.isSourceNameHidden ? PayrollLocalization.text("非公開") : PayrollLocalization.text("未設定"))
                )
                summaryRow(title: "支給日", value: payload.paymentDate.mediumJapaneseDateText)
                summaryRow(title: "共有日時", value: payload.exportedAt.mediumJapaneseDateTimeText)

                switch payload.amountVisibility {
                case .hidden:
                    summaryRow(title: "金額", value: PayrollLocalization.text("非公開"), emphasize: true)
                    summaryRow(title: "支給項目", value: PayrollLocalization.countLabel(payload.paymentItemCount))
                    summaryRow(title: "控除項目", value: PayrollLocalization.countLabel(payload.deductionItemCount))
                case .totals, .breakdown:
                    summaryRow(title: "手取り", value: payload.netAmount?.currencyText ?? PayrollLocalization.text("非公開"), emphasize: true)
                    summaryRow(title: "支給合計", value: payload.totalPayments?.currencyText ?? PayrollLocalization.text("非公開"))
                    summaryRow(title: "控除合計", value: payload.totalDeductions?.currencyText ?? PayrollLocalization.text("非公開"))
                }

                if payload.workHourItemCount > 0 {
                    if payload.amountVisibility == .breakdown {
                        summaryRow(title: "勤務時間合計", value: payload.totalWorkHours.hourText)
                    } else {
                        summaryRow(title: "勤務時間項目", value: PayrollLocalization.countLabel(payload.workHourItemCount))
                    }
                }
            }
        }
        .padding(20)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private func lineItemSection(
        title: String,
        items: [PayrollRecordSharePayload.SharedLineItem],
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
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var workHourSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("勤務時間")
                .font(.headline)

            ForEach(payload.workHourEntries) { entry in
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

                if entry.id != payload.workHourEntries.last?.id {
                    Divider()
                }
            }
        }
        .padding(20)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private func noteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メモ")
                .font(.headline)

            Text(note)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private func compactInfoCard(title: String, value: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
            Text(PayrollLocalization.text(title))
                .font(.headline)

                Spacer()

                Text(value)
                    .font(.subheadline.weight(.semibold))
            }

            Text(PayrollLocalization.text(description))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var heroMetrics: [HeroMetric] {
        switch payload.amountVisibility {
        case .hidden:
            return [
                HeroMetric(title: "金額", value: PayrollLocalization.text("非公開")),
                HeroMetric(title: "支給項目", value: PayrollLocalization.countLabel(payload.paymentItemCount)),
                HeroMetric(
                    title: payload.workHourItemCount > 0 ? "勤務時間" : "控除項目",
                    value: payload.workHourItemCount > 0
                        ? PayrollLocalization.countLabel(payload.workHourItemCount)
                        : PayrollLocalization.countLabel(payload.deductionItemCount)
                ),
            ]
        case .totals, .breakdown:
            return [
                HeroMetric(title: "支給", value: payload.totalPayments?.currencyText ?? PayrollLocalization.text("非公開")),
                HeroMetric(title: "控除", value: payload.totalDeductions?.currencyText ?? PayrollLocalization.text("非公開")),
                HeroMetric(
                    title: payload.workHourItemCount > 0 ? "勤務時間" : "項目数",
                    value: payload.workHourItemCount > 0
                        ? (payload.amountVisibility == .breakdown ? payload.totalWorkHours.hourText : PayrollLocalization.countLabel(payload.workHourItemCount))
                        : PayrollLocalization.countLabel(payload.paymentItemCount + payload.deductionItemCount)
                ),
            ]
        }
    }

    private var kindBadge: some View {
        Text(payload.kind.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.14), in: Capsule())
            .foregroundStyle(.white)
    }

    private func heroMetricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PayrollLocalization.text(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func summaryRow(title: String, value: String, emphasize: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(PayrollLocalization.text(title))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(emphasize ? .headline.weight(.bold) : .subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct HeroMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}
