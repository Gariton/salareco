import SwiftData
import SwiftUI

private enum SourceEditorSheet: Identifiable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let id):
            "edit-\(id.uuidString)"
        }
    }
}

private enum SourceColorOption: String, CaseIterable, Identifiable {
    case teal = "#0F766E"
    case blue = "#2563EB"
    case amber = "#D97706"
    case rose = "#E11D48"
    case violet = "#7C3AED"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teal:
            PayrollLocalization.text("Teal")
        case .blue:
            PayrollLocalization.text("Blue")
        case .amber:
            PayrollLocalization.text("Amber")
        case .rose:
            PayrollLocalization.text("Rose")
        case .violet:
            PayrollLocalization.text("Violet")
        }
    }
}

private struct SettingsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct SourceDraft {
    var name: String
    var note: String
    var accentHex: String
    var salaryPaymentDay: Int?
    var salaryAnnouncementDay: Int?
    var workHourDefinitions: [EditableWorkHourDefinition]

    init(source: IncomeSource? = nil) {
        name = source?.name ?? ""
        note = source?.note ?? ""
        accentHex = source?.accentHex ?? SourceColorOption.teal.rawValue
        salaryPaymentDay = source?.salaryPaymentDay
        salaryAnnouncementDay = source?.salaryAnnouncementDay
        workHourDefinitions = source?.sortedWorkHourDefinitions.map {
            EditableWorkHourDefinition(id: $0.id, name: $0.name)
        } ?? []
    }

    var isValid: Bool {
        !name.trimmed.isEmpty
    }

    var normalizedWorkHourDefinitions: [EditableWorkHourDefinition] {
        var seenNames = Set<String>()

        return workHourDefinitions.compactMap { definition in
            let trimmedName = definition.trimmedName
            guard !trimmedName.isEmpty else {
                return nil
            }

            let deduplicationKey = trimmedName.lowercased()
            guard seenNames.insert(deduplicationKey).inserted else {
                return nil
            }

            return EditableWorkHourDefinition(id: definition.id, name: trimmedName)
        }
    }
}

struct SettingsView: View {
    @Environment(PayrollAppState.self) private var appState
    @Environment(PayrollMonetizationStore.self) private var monetization
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \PayrollRecord.paymentDate, order: .reverse) private var records: [PayrollRecord]
    @Query(sort: \PayrollTemplate.createdAt, order: .reverse) private var templates: [PayrollTemplate]

    @AppStorage(SharePrivacyOptions.hideSourceNameKey) private var hideSourceName = false
    @AppStorage(SharePrivacyOptions.hideAmountsKey) private var hideAmounts = false
    @AppStorage(SharePrivacyOptions.hideBreakdownKey) private var hideBreakdown = false
    @AppStorage(SharePrivacyOptions.hideNotesKey) private var hideNotes = true
    @AppStorage(AppLockOptions.requiresAuthenticationAtLaunchKey)
    private var requiresAuthenticationAtLaunch = false

    @State private var activeSheet: SourceEditorSheet?
    @State private var plusSheet: PayrollPlusPaywall?
    @State private var settingsAlert: SettingsAlert?
    @State private var isResetConfirmationPresented = false
    @State private var isAuthenticatingForDataReset = false

    var body: some View {
        List {
            Section("表示中の支給元") {
                Text(currentSource?.name ?? PayrollLocalization.text("すべての支給元"))
                    .font(.headline)
                Text("ダッシュボードや記録画面の上部フィルタから支給元を切り替えられます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("プラン") {
                PlusPlanStatusRow(
                    sourceCount: sources.count,
                    templateCount: templates.count
                ) {
                    plusSheet = .general
                }
            }

            Section("支給元管理") {
                ForEach(sources) { source in
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(hex: source.accentHex))
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(source.name)
                                    .font(.headline)

                                if appState.selectedSourceID == source.id {
                                    Text("表示中")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: source.accentHex).opacity(0.14))
                                        .clipShape(Capsule())
                                }
                            }

                            Text(source.note.isEmpty ? PayrollLocalization.text("メモなし") : source.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(sourceSummary(for: source))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let reminderSummary = reminderSummary(for: source) {
                                Text(reminderSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let workHourSummary = workHourSummary(for: source) {
                                Text(workHourSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("編集") {
                            activeSheet = .edit(source.id)
                        }
                        .buttonStyle(.borderless)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectedSourceID = source.id
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(source)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }

                Button {
                    presentSourceCreation()
                } label: {
                    Label("支給元を追加", systemImage: "plus.circle")
                }
            }

            Section("共有設定") {
                Toggle("支給元名を隠す", isOn: $hideSourceName)
                Toggle("金額をすべて隠す", isOn: $hideAmounts)
                Toggle("明細の内訳を隠す", isOn: $hideBreakdown)
                Toggle("メモを隠す", isOn: $hideNotes)
            }

            if !monetization.isPlusActive {
                Section("広告") {
                    FreePlanBannerAdView(placement: .settings, horizontalPadding: false)
                }
            }

            Section("セキュリティ") {
                Toggle("起動時に認証を要求", isOn: launchAuthenticationBinding)

                Text("有効にすると、アプリ起動時とバックグラウンドから戻った時に認証を要求します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if appAuthenticationAvailability.isAvailable {
                    Text(PayrollLocalization.format("%@で解除します。", appAuthenticationAvailability.summary))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let unavailableReason = appAuthenticationAvailability.unavailableReason {
                    Text(unavailableReason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("データ管理") {
                Button(role: .destructive) {
                    startDataResetFlow()
                } label: {
                    if isAuthenticatingForDataReset {
                        Label("認証中...", systemImage: "lock.fill")
                    } else {
                        Label("給与データをすべて削除", systemImage: "trash")
                    }
                }
                .disabled(!hasStoredPayrollData || isAuthenticatingForDataReset)

                Text("共有設定や認証設定は残したまま、支給元、給与記録、テンプレート、勤務時間項目を削除します。この操作は取り消せません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !hasStoredPayrollData {
                    Text("削除できる給与データはありません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("ガイド") {
                Button {
                    withAnimation(.spring(response: 0.72, dampingFraction: 0.88)) {
                        appState.isPresentingOnboarding = true
                    }
                } label: {
                    Label("使い方ツアーをもう一度見る", systemImage: "sparkles.rectangle.stack")
                }

                Text("初回ツアーで紹介する、支給元登録、記録追加、テンプレート活用、共有設定をいつでも見直せます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("同期") {
                Text("iCloud と CloudKit が利用できる環境では、同じ Apple ID の端末間で給与データを同期します。利用できない場合は、この端末内にローカル保存されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PayrollScreenBackground(accent: currentTint))
        .navigationTitle("設定")
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .create:
                    SourceEditorView()
                case .edit(let id):
                    SourceEditorView(source: sources.first(where: { $0.id == id }))
                }
            }
        }
        .sheet(item: $plusSheet) { paywall in
            NavigationStack {
                PlusPlanView(context: paywall)
            }
        }
        .confirmationDialog(
            "給与データをすべて削除しますか？",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("削除して初期化", role: .destructive) {
                resetAllPayrollData()
            }

            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(dataResetConfirmationMessage)
        }
        .alert(item: $settingsAlert) { alert in
            Alert(
                title: Text(PayrollLocalization.text(alert.title)),
                message: Text(PayrollLocalization.text(alert.message)),
                dismissButton: .default(Text("閉じる"))
            )
        }
    }

    private var currentSource: IncomeSource? {
        guard let selectedSourceID = appState.selectedSourceID else {
            return nil
        }

        return sources.first(where: { $0.id == selectedSourceID })
    }

    private var currentTint: Color {
        currentSource.map { Color(hex: $0.accentHex) } ?? Color(hex: "#0F766E")
    }

    private var appAuthenticationAvailability: AppAuthenticationAvailability {
        AppAuthenticationManager.availability()
    }

    private var hasStoredPayrollData: Bool {
        !sources.isEmpty || !records.isEmpty || !templates.isEmpty
    }

    private var dataResetConfirmationMessage: String {
        PayrollLocalization.format(
            "支給元 %1$lld件、給与記録 %2$lld件、テンプレート %3$lld件を削除します。この操作は取り消せません。",
            Int64(sources.count),
            Int64(records.count),
            Int64(templates.count)
        )
    }

    private var launchAuthenticationBinding: Binding<Bool> {
        Binding(
            get: { requiresAuthenticationAtLaunch },
            set: { newValue in
                guard newValue else {
                    requiresAuthenticationAtLaunch = false
                    return
                }

                let availability = appAuthenticationAvailability
                guard availability.isAvailable else {
                    requiresAuthenticationAtLaunch = false
                    settingsAlert = SettingsAlert(
                        title: PayrollLocalization.text("認証を有効にできません"),
                        message: availability.unavailableReason
                            ?? PayrollLocalization.text("この端末では認証を利用できません。")
                    )
                    return
                }

                requiresAuthenticationAtLaunch = true
            }
        )
    }

    private func sourceSummary(for source: IncomeSource) -> String {
        let sourceRecords = records.filter { $0.sourceID == source.id }
        let sourceTemplates = templates.filter { $0.sourceID == source.id }
        let latestNet = sourceRecords.first?.netAmount.currencyText ?? 0.currencyText
        return PayrollLocalization.format(
            "記録 %1$lld件 / テンプレート %2$lld件 / 直近手取り %3$@",
            Int64(sourceRecords.count),
            Int64(sourceTemplates.count),
            latestNet
        )
    }

    private func reminderSummary(for source: IncomeSource) -> String? {
        var components: [String] = []

        if let announcementDay = source.salaryAnnouncementDay {
            components.append(PayrollLocalization.format("開示日 %lld日", Int64(announcementDay)))
        }

        if let paymentDay = source.salaryPaymentDay {
            components.append(PayrollLocalization.format("支給日 %lld日", Int64(paymentDay)))
        }

        guard !components.isEmpty else {
            return nil
        }

        return PayrollLocalization.text("通知: ") + components.joined(separator: " / ")
    }

    private func workHourSummary(for source: IncomeSource) -> String? {
        let count = source.sortedWorkHourDefinitions.count
        guard count > 0 else {
            return nil
        }

        return PayrollLocalization.format("勤務時間項目 %lld件", Int64(count))
    }

    private func delete(_ source: IncomeSource) {
        if appState.selectedSourceID == source.id {
            appState.selectedSourceID = nil
        }

        modelContext.delete(source)
        try? modelContext.save()
    }

    private func presentSourceCreation() {
        guard monetization.canCreateIncomeSource(currentCount: sources.count) else {
            plusSheet = .incomeSourceLimit
            return
        }

        activeSheet = .create
    }

    private func startDataResetFlow() {
        guard hasStoredPayrollData else {
            settingsAlert = SettingsAlert(
                title: PayrollLocalization.text("削除するデータがありません"),
                message: PayrollLocalization.text("支給元、給与記録、テンプレートはまだ登録されていません。")
            )
            return
        }

        guard requiresAuthenticationAtLaunch else {
            isResetConfirmationPresented = true
            return
        }

        Task {
            await authenticateForDataReset()
        }
    }

    @MainActor
    private func authenticateForDataReset() async {
        guard !isAuthenticatingForDataReset else {
            return
        }

        isAuthenticatingForDataReset = true
        defer {
            isAuthenticatingForDataReset = false
        }

        do {
            try await AppAuthenticationManager.authenticate(
                localizedReason: PayrollLocalization.text("給与データを初期化するために認証してください。")
            )
            isResetConfirmationPresented = true
        } catch {
            guard let message = AppAuthenticationManager.errorMessage(for: error) else {
                return
            }

            settingsAlert = SettingsAlert(
                title: PayrollLocalization.text("認証できませんでした"),
                message: message
            )
        }
    }

    private func resetAllPayrollData() {
        do {
            try deleteAllPayrollData()
            appState.selectedSourceID = nil
            appState.requestInitialLaunchExperienceReplay()

            Task {
                await PayrollNotificationScheduler.refreshNotifications(for: [])
            }
        } catch {
            modelContext.rollback()
            settingsAlert = SettingsAlert(
                title: PayrollLocalization.text("データを削除できませんでした"),
                message: error.localizedDescription
            )
        }
    }

    private func deleteAllPayrollData() throws {
        try deleteAll(PayrollWorkHourEntry.self)
        try deleteAll(PayrollLineItem.self)
        try deleteAll(WorkHourDefinition.self)
        try deleteAll(PayrollRecord.self)
        try deleteAll(PayrollTemplate.self)
        try deleteAll(IncomeSource.self)
        try modelContext.save()
    }

    private func deleteAll<Model: PersistentModel>(_: Model.Type) throws {
        let models = try modelContext.fetch(FetchDescriptor<Model>())

        for model in models {
            modelContext.delete(model)
        }
    }
}

private struct SourceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PayrollMonetizationStore.self) private var monetization

    @State private var draft: SourceDraft
    @State private var plusSheet: PayrollPlusPaywall?

    private let source: IncomeSource?
    private var suggestedWorkHourNames: [String] {
        [
            PayrollLocalization.text("時間外"),
            PayrollLocalization.text("深夜"),
            PayrollLocalization.text("休日"),
            PayrollLocalization.text("早出"),
        ]
    }

    init(source: IncomeSource? = nil) {
        self.source = source
        _draft = State(initialValue: SourceDraft(source: source))
    }

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("支給元名", text: $draft.name)
                TextField("補足メモ", text: $draft.note, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("カラー") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 12)], spacing: 12) {
                    ForEach(SourceColorOption.allCases) { color in
                        Button {
                            draft.accentHex = color.rawValue
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: color.rawValue))
                                    .frame(width: 28, height: 28)

                                Text(color.title)
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        draft.accentHex == color.rawValue
                                            ? Color(hex: color.rawValue).opacity(0.14)
                                            : Color(.secondarySystemBackground)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("通知") {
                reminderDayPicker(title: "給与支給日", selection: $draft.salaryPaymentDay)
                reminderDayPicker(title: "給与開示日", selection: $draft.salaryAnnouncementDay)

                Text("設定すると毎月その日の午前9時ごろに通知します。29〜31日を指定した場合、該当日がない月は通知されません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("勤務時間項目") {
                if draft.workHourDefinitions.isEmpty {
                    Text("時間外や深夜など、給与記録に入力したい勤務時間項目を追加できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(draft.workHourDefinitions, id: \.id) { definition in
                    if let definitionBinding = workHourDefinitionBinding(for: definition.id) {
                        SourceWorkHourDefinitionRow(
                            definition: definitionBinding,
                            canMoveUp: canMoveWorkHourDefinition(withID: definition.id, direction: -1),
                            canMoveDown: canMoveWorkHourDefinition(withID: definition.id, direction: 1),
                            moveUp: {
                                moveWorkHourDefinition(withID: definition.id, direction: -1)
                            },
                            moveDown: {
                                moveWorkHourDefinition(withID: definition.id, direction: 1)
                            },
                            remove: {
                                removeWorkHourDefinition(withID: definition.id)
                            }
                        )
                    }
                }

                if canAddWorkHourDefinition {
                    Button {
                        addWorkHourDefinition()
                    } label: {
                        Label("項目を追加", systemImage: "plus.circle")
                    }
                } else {
                    PlusLockedFeatureRow(
                        title: "Plusで勤務時間項目を増やす",
                        message: PayrollLocalization.format(
                            "無料プランでは勤務時間項目を%lld件まで設定できます。",
                            Int64(PayrollPlanLimits.freeWorkHourDefinitionLimit)
                        ),
                        systemImage: "clock.badge.checkmark",
                        actionTitle: "Plusを見る"
                    ) {
                        plusSheet = .workHourDefinitionLimit
                    }
                }

                if canAddWorkHourDefinition && !remainingSuggestedWorkHourNames.isEmpty {
                    Menu("定番の項目を追加") {
                        ForEach(remainingSuggestedWorkHourNames, id: \.self) { suggestedName in
                            Button(suggestedName) {
                                addWorkHourDefinition(named: suggestedName)
                            }
                        }
                    }
                }

                Text("ここで追加した項目が、給与記録の勤務時間入力欄に表示されます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(PayrollLocalization.text(source == nil ? "支給元を追加" : "支給元を編集"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
                    .disabled(!draft.isValid)
            }
        }
        .sheet(item: $plusSheet) { paywall in
            NavigationStack {
                PlusPlanView(context: paywall)
            }
        }
    }

    private func reminderDayPicker(
        title: String,
        selection: Binding<Int?>
    ) -> some View {
        Picker(PayrollLocalization.text(title), selection: selection) {
            Text("なし").tag(Optional<Int>.none)
            ForEach(1...31, id: \.self) { day in
                Text(PayrollLocalization.dayLabel(day)).tag(Optional(day))
            }
        }
    }

    private var remainingSuggestedWorkHourNames: [String] {
        let existingNames = Set(
            draft.normalizedWorkHourDefinitions.map { $0.trimmedName.lowercased() }
        )

        return suggestedWorkHourNames.filter { suggestedName in
            !existingNames.contains(suggestedName.lowercased())
        }
    }

    private var canAddWorkHourDefinition: Bool {
        monetization.canAddWorkHourDefinition(currentCount: draft.workHourDefinitions.count)
    }

    private func addWorkHourDefinition(named name: String = "") {
        guard canAddWorkHourDefinition else {
            plusSheet = .workHourDefinitionLimit
            return
        }

        draft.workHourDefinitions.append(EditableWorkHourDefinition(name: name))
    }

    private func workHourDefinitionBinding(
        for id: UUID
    ) -> Binding<EditableWorkHourDefinition>? {
        guard draft.workHourDefinitions.contains(where: { $0.id == id }) else {
            return nil
        }

        return Binding(
            get: {
                draft.workHourDefinitions.first(where: { $0.id == id }) ?? EditableWorkHourDefinition(id: id)
            },
            set: { updatedValue in
                guard let index = draft.workHourDefinitions.firstIndex(where: { $0.id == id }) else {
                    return
                }

                draft.workHourDefinitions[index] = updatedValue
            }
        )
    }

    private func canMoveWorkHourDefinition(
        withID id: UUID,
        direction: Int
    ) -> Bool {
        guard let index = draft.workHourDefinitions.firstIndex(where: { $0.id == id }) else {
            return false
        }

        return draft.workHourDefinitions.indices.contains(index + direction)
    }

    private func moveWorkHourDefinition(
        withID id: UUID,
        direction: Int
    ) {
        guard let index = draft.workHourDefinitions.firstIndex(where: { $0.id == id }) else {
            return
        }

        let destinationIndex = index + direction
        guard draft.workHourDefinitions.indices.contains(destinationIndex) else {
            return
        }

        withAnimation {
            draft.workHourDefinitions.swapAt(index, destinationIndex)
        }
    }

    private func removeWorkHourDefinition(withID id: UUID) {
        guard let index = draft.workHourDefinitions.firstIndex(where: { $0.id == id }) else {
            return
        }

        draft.workHourDefinitions.remove(at: index)
    }

    private func save() {
        let shouldRequestAuthorization =
            draft.salaryPaymentDay != nil || draft.salaryAnnouncementDay != nil
        let workHourDefinitions = draft.normalizedWorkHourDefinitions.enumerated().map { offset, definition in
            WorkHourDefinition(
                id: definition.id,
                name: definition.trimmedName,
                sortOrder: offset
            )
        }

        if let source {
            source.name = draft.name.trimmed
            source.note = draft.note.trimmed
            source.accentHex = draft.accentHex
            source.salaryPaymentDay = draft.salaryPaymentDay
            source.salaryAnnouncementDay = draft.salaryAnnouncementDay
            source.replaceWorkHourDefinitions(with: workHourDefinitions, in: modelContext)
        } else {
            let source = IncomeSource(
                name: draft.name.trimmed,
                note: draft.note.trimmed,
                accentHex: draft.accentHex,
                salaryPaymentDay: draft.salaryPaymentDay,
                salaryAnnouncementDay: draft.salaryAnnouncementDay
            )
            modelContext.insert(source)
            source.replaceWorkHourDefinitions(with: workHourDefinitions, in: modelContext)
        }

        try? modelContext.save()
        let sources = (try? modelContext.fetch(FetchDescriptor<IncomeSource>())) ?? []

        Task {
            await PayrollNotificationScheduler.refreshNotifications(
                for: sources,
                requestingAuthorization: shouldRequestAuthorization
            )
        }

        dismiss()
    }
}

private struct SourceWorkHourDefinitionRow: View {
    @Binding var definition: EditableWorkHourDefinition
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("項目名", text: $definition.name)

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

                Button(role: .destructive, action: remove) {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("削除")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
