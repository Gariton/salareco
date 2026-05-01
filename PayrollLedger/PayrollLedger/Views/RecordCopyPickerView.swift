import SwiftUI

struct RecordCopyPickerView: View {
    let records: [PayrollRecord]
    let sources: [IncomeSource]
    let selectedSourceID: UUID?
    let onSelect: (PayrollRecord) -> Void

    @Environment(\.dismiss) private var dismiss

    private var filteredRecords: [PayrollRecord] {
        records.filter { record in
            guard let selectedSourceID else {
                return true
            }

            return record.sourceID == selectedSourceID
        }
    }

    var body: some View {
        List {
            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    "コピーできる過去データがありません",
                    systemImage: "doc.on.doc",
                    description: Text(selectedSourceID == nil
                                      ? PayrollLocalization.text("先に給与記録を追加すると、ここから下書きとしてコピーできます。")
                                      : PayrollLocalization.text("選択中の支給元に一致する過去データがまだありません。"))
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filteredRecords) { record in
                        Button {
                            onSelect(record)
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Circle()
                                    .fill(Color(hex: record.source(in: sources)?.accentHex ?? "#0F766E"))
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(record.titleText)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text(record.source(in: sources)?.name ?? PayrollLocalization.text("支給元未設定"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(record.paymentDate.mediumJapaneseDateText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(record.netAmount.currencyText)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.primary)

                                    Text(PayrollLocalization.format("支給 %@", record.totalPayments.currencyText))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(PayrollLocalization.text(selectedSourceID == nil ? "過去の給与データ" : "選択中の支給元の過去データ"))
                } footer: {
                    Text("選んだ記録の種別、支給元、メモ、支給項目、控除項目を下書きへコピーします。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("過去データをコピー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
