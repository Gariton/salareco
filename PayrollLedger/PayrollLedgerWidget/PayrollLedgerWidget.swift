import AppIntents
import SwiftUI
import WidgetKit

private struct PayrollWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: PayrollWidgetSnapshot
    let isSensitiveInformationRevealed: Bool
}

private struct PayrollWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PayrollWidgetEntry {
        PayrollWidgetEntry(
            date: .now,
            snapshot: .placeholder,
            isSensitiveInformationRevealed: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PayrollWidgetEntry) -> Void) {
        completion(currentEntry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PayrollWidgetEntry>) -> Void) {
        let nextRefreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [currentEntry], policy: .after(nextRefreshDate)))
    }

    private var currentEntry: PayrollWidgetEntry {
        PayrollWidgetEntry(
            date: .now,
            snapshot: PayrollWidgetStore.load() ?? .placeholder,
            isSensitiveInformationRevealed: PayrollWidgetStore.isSensitiveInformationRevealed()
        )
    }
}

struct TogglePayrollWidgetPrivacyIntent: AppIntent {
    static var title: LocalizedStringResource {
        LocalizedStringResource("ウィジェットの表示を切り替える")
    }
    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("給与ウィジェットの金額と支給元名の表示/マスクを切り替えます。"))
    }

    func perform() async throws -> some IntentResult {
        PayrollWidgetStore.toggleSensitiveInformationVisibility()
        WidgetCenter.shared.reloadTimelines(ofKind: "PayrollLedgerWidget")
        return .result()
    }
}

struct PayrollLedgerWidget: Widget {
    private let kind = "PayrollLedgerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PayrollWidgetProvider()) { entry in
            PayrollLedgerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("給与記録")
        .description("最新の給与と今年の累計をホーム画面ですぐ確認できます。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct PayrollLedgerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: PayrollWidgetEntry

    private var accentColor: Color {
        Color(hex: entry.snapshot.latestRecord?.sourceAccentHex ?? "#0F766E")
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumWidget
            default:
                smallWidget
            }
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var widgetBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accentColor.opacity(0.94),
                    Color(hex: "#0F172A"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 120, height: 120)
                .blur(radius: 12)
                .offset(x: 46, y: -52)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
                .padding(1)
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetHeader

            if let latestRecord = entry.snapshot.latestRecord {
                Text(recordHeadline(for: latestRecord))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(privateCurrencyText(latestRecord.netAmount))
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                HStack(alignment: .lastTextBaseline) {
                    Text(latestRecord.paymentDate.widgetMonthDayText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer(minLength: 0)

                    Text(PayrollLocalization.format("%lld件", Int64(entry.snapshot.recordCount)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Text(privateCurrencyText(entry.snapshot.yearNetTotal))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Spacer(minLength: 0)

                Text("未登録")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)

                Text("給与記録を追加")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader

            if let latestRecord = entry.snapshot.latestRecord {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(privateSourceName(latestRecord.sourceName))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)

                        Text(recordHeadline(for: latestRecord))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(1)
                    }
                    .layoutPriority(1)

                    Text(privateCurrencyText(latestRecord.netAmount))
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
                HStack(spacing: 8) {
                    compactMetricPill(
                        title: "支給",
                        value: privateCurrencyText(latestRecord.totalPayments)
                    )

                    compactMetricPill(
                        title: "控除",
                        value: privateCurrencyText(latestRecord.totalDeductions)
                    )

                    compactMetricPill(
                        title: "年累計",
                        value: privateCurrencyText(entry.snapshot.yearNetTotal)
                    )
                }
            } else {
                Spacer(minLength: 0)

                Text("給与記録なし")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)

                Text("アプリで保存すると反映されます")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 0)
        }
        .padding(8)
    }

    private var widgetHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "banknote")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(6)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("給与")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            privacyButton
        }
    }

    private var privacyButton: some View {
        Button(intent: TogglePayrollWidgetPrivacyIntent()) {
            Image(systemName: entry.isSensitiveInformationRevealed ? "eye.slash" : "eye")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(PayrollLocalization.text(entry.isSensitiveInformationRevealed ? "金額を隠す" : "金額を表示")))
    }

    private func kindTitle(for rawValue: String) -> String {
        switch rawValue {
        case "bonus":
            return PayrollLocalization.text("賞与")
        default:
            return PayrollLocalization.text("給与")
        }
    }

    private func recordHeadline(for latestRecord: PayrollWidgetSnapshot.LatestRecord) -> String {
        PayrollLocalization.format(
            "%1$@の%2$@",
            PayrollLocalization.monthLabel(latestRecord.periodMonth),
            kindTitle(for: latestRecord.kindRawValue)
        )
    }

    private func privateCurrencyText(_ amount: Double) -> String {
        entry.isSensitiveInformationRevealed ? amount.widgetCurrencyText : "¥•••"
    }

    private func privateSourceName(_ sourceName: String) -> String {
        entry.isSensitiveInformationRevealed ? sourceName : PayrollLocalization.text("支給元非表示")
    }

    private func compactMetricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(PayrollLocalization.text(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.64))

            Text(value)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func yearDisplayText(_ year: Int) -> String {
        PayrollLocalization.yearLabel(year)
    }
}

private extension Double {
    var widgetCurrencyText: String {
        formatted(
            .currency(code: "JPY")
                .locale(PayrollLocalization.locale)
                .precision(.fractionLength(0))
        )
    }
}

private extension Date {
    var widgetMonthDayText: String {
        formatted(.dateTime.month(.abbreviated).day().locale(PayrollLocalization.locale))
    }
}

private extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch sanitized.count {
        case 8:
            red = Double((value & 0xFF000000) >> 24) / 255
            green = Double((value & 0x00FF0000) >> 16) / 255
            blue = Double((value & 0x0000FF00) >> 8) / 255
            alpha = Double(value & 0x000000FF) / 255
        default:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
