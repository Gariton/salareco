import SwiftData
import SwiftUI
import WidgetKit

struct AppRootView: View {
    @AppStorage("app.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppLockOptions.requiresAuthenticationAtLaunchKey)
    private var requiresAuthenticationAtLaunch = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \PayrollRecord.paymentDate, order: .reverse) private var records: [PayrollRecord]
    @Query(sort: \PayrollTemplate.createdAt, order: .reverse) private var templates: [PayrollTemplate]

    @State private var appState = PayrollAppState()
    @State private var monetizationStore = PayrollMonetizationStore()
    @State private var isShowingLaunchSplash = true
    @State private var hasStartedLaunchExperience = false
    @State private var shareAlert: ShareAlert?
    @State private var sharedTemplateImportPresentation: SharedTemplateImportPresentation?
    @State private var sharedRecordPresentation: SharedRecordPresentation?
    @State private var isAppLocked = false
    @State private var isAuthenticating = false
    @State private var authenticationErrorMessage: String?
    @State private var hasConfiguredInitialLockState = false
    @State private var lockAttemptToken = UUID()
    @State private var quickActionSheet: HomeQuickActionSheet?
    @State private var plusSheet: PayrollPlusPaywall?
    @State private var trackingAuthorizationRequestTask: Task<Void, Never>?
    @State private var viewportOrientation: PayrollViewportOrientation = .portrait

    var body: some View {
        @Bindable var appState = appState

        ZStack {
            mainContent(selectedTab: $appState.selectedTab)
                .id(viewportOrientation)
                .blur(radius: appState.isPresentingOnboarding || isAppLocked ? 14 : 0)
                .scaleEffect(appState.isPresentingOnboarding || isAppLocked ? 0.97 : 1)
                .allowsHitTesting(
                    !isShowingLaunchSplash && !appState.isPresentingOnboarding && !isAppLocked
                )

            if isShowingLaunchSplash {
                LaunchSplashView()
                    .transition(.opacity)
                    .zIndex(2)
            }

            if appState.isPresentingOnboarding {
                OnboardingTourView(onComplete: { destinationTab in
                    finishOnboarding(routeTo: destinationTab)
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }

            if isAppLocked, !isShowingLaunchSplash {
                AppLockView(
                    tint: currentTint,
                    availabilitySummary: AppAuthenticationManager.availability().summary,
                    errorMessage: authenticationErrorMessage,
                    isAuthenticating: isAuthenticating,
                    unlockAction: {
                        Task {
                            await authenticateAppIfNeeded()
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(4)
                .task(id: lockAttemptToken) {
                    await authenticateAppIfNeeded()
                }
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateViewportOrientation(for: proxy.size)
                    }
                    .onChange(of: proxy.size) { _, size in
                        updateViewportOrientation(for: size)
                    }
            }
        }
        .environment(appState)
        .environment(monetizationStore)
        .environment(\.locale, PayrollLocalization.locale)
        .tint(currentTint)
        .task {
            await monetizationStore.prepare()
        }
        .task {
            configureInitialLockStateIfNeeded()
        }
        .task {
            handlePendingQuickActionIfNeeded()
        }
        .task(id: sources.count) {
            await synchronizeAppState()
        }
        .task(id: widgetSyncKey) {
            await refreshWidgetSnapshot()
        }
        .task(id: notificationSyncKey) {
            await refreshNotifications()
        }
        .task {
            await runLaunchExperienceIfNeeded()
        }
        .task {
            scheduleTrackingAuthorizationRequestIfReady()
        }
        .onOpenURL { url in
            Task {
                await handleIncomingSharedURL(url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: PayrollQuickActionDispatcher.notificationName)) { notification in
            guard let action = notification.userInfo?["action"] as? PayrollHomeQuickAction else {
                return
            }

            _ = PayrollQuickActionDispatcher.shared.consumePendingAction()
            handleQuickAction(action)
        }
        .onChange(of: requiresAuthenticationAtLaunch) { _, newValue in
            handleAuthenticationSettingChange(isEnabled: newValue)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
            scheduleTrackingAuthorizationRequestIfReady()
        }
        .onChange(of: isShowingLaunchSplash) { _, isShowing in
            guard !isShowing else {
                return
            }

            Task {
                await authenticateAppIfNeeded()
            }
            scheduleTrackingAuthorizationRequestIfReady()
        }
        .onChange(of: appState.isPresentingOnboarding) { _, _ in
            scheduleTrackingAuthorizationRequestIfReady()
        }
        .onChange(of: isAppLocked) { _, _ in
            scheduleTrackingAuthorizationRequestIfReady()
        }
        .onChange(of: isAuthenticating) { _, _ in
            scheduleTrackingAuthorizationRequestIfReady()
        }
        .onChange(of: appState.launchExperienceReplayRequest) { _, request in
            guard let request else {
                return
            }

            Task {
                await replayLaunchExperience(request)
            }
        }
        .sheet(item: $sharedRecordPresentation) { presentation in
            NavigationStack {
                SharedPayrollRecordView(payload: presentation.payload)
            }
        }
        .sheet(item: $sharedTemplateImportPresentation) { presentation in
            NavigationStack {
                TemplateImportSourceSelectionView(
                    payload: presentation.payload,
                    sources: sources,
                    initialSourceID: appState.selectedSourceID,
                    canCreateSharedSource: monetizationStore.canCreateIncomeSource(currentCount: sources.count),
                    onImport: { destination in
                        try importSharedTemplate(
                            presentation.payload,
                            destination: destination
                        )
                    },
                    onImported: { template in
                        finishSharedTemplateImport(template)
                    }
                )
            }
        }
        .sheet(item: $quickActionSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .record(let kind):
                    RecordEditorView(
                        initialKind: kind,
                        initialSourceID: appState.selectedSourceID
                    )
                case .template:
                    TemplateEditorView(initialSourceID: appState.selectedSourceID)
                }
            }
        }
        .sheet(item: $plusSheet) { paywall in
            NavigationStack {
                PlusPlanView(context: paywall)
            }
        }
        .alert(item: $shareAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("閉じる"))
            )
        }
        .animation(.spring(response: 0.65, dampingFraction: 0.84), value: isShowingLaunchSplash)
        .animation(.spring(response: 0.72, dampingFraction: 0.88), value: appState.isPresentingOnboarding)
    }

    private func mainContent(selectedTab: Binding<AppTab>) -> some View {
        TabView(selection: selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage)
            }
            .tag(AppTab.dashboard)

            NavigationStack {
                RecordsView()
            }
            .tabItem {
                Label(AppTab.records.title, systemImage: AppTab.records.systemImage)
            }
            .tag(AppTab.records)

            NavigationStack {
                TemplatesView()
            }
            .tabItem {
                Label(AppTab.templates.title, systemImage: AppTab.templates.systemImage)
            }
            .tag(AppTab.templates)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
            }
            .tag(AppTab.settings)
        }
    }

    private func updateViewportOrientation(for size: CGSize) {
        guard size.width > 0, size.height > 0 else {
            return
        }

        let nextOrientation = PayrollViewportOrientation(size: size)
        guard nextOrientation != viewportOrientation else {
            return
        }

        viewportOrientation = nextOrientation
    }

    private var currentTint: Color {
        guard let selectedSourceID = appState.selectedSourceID,
              let selectedSource = sources.first(where: { $0.id == selectedSourceID }) else {
            return Color(hex: "#0F766E")
        }

        return Color(hex: selectedSource.accentHex)
    }

    private var widgetSyncKey: Int {
        var hasher = Hasher()
        hasher.combine(records.count)
        hasher.combine(sources.count)

        for record in records {
            hasher.combine(record.id)
            hasher.combine(record.kind.rawValue)
            hasher.combine(record.periodYear)
            hasher.combine(record.periodMonth)
            hasher.combine(record.paymentDate.timeIntervalSince1970)
            hasher.combine(record.netAmount)
            hasher.combine(record.totalPayments)
            hasher.combine(record.totalDeductions)
            hasher.combine(record.sourceID)
        }

        for source in sources {
            hasher.combine(source.id)
            hasher.combine(source.name)
            hasher.combine(source.accentHex)
        }

        return hasher.finalize()
    }

    private var notificationSyncKey: Int {
        var hasher = Hasher()
        hasher.combine(sources.count)

        for source in sources {
            hasher.combine(source.id)
            hasher.combine(source.name)
            hasher.combine(source.salaryPaymentDay)
            hasher.combine(source.salaryAnnouncementDay)
        }

        return hasher.finalize()
    }

    @MainActor
    private func synchronizeAppState() async {
        if sources.isEmpty {
            appState.selectedSourceID = nil
            return
        }

        if let selectedSourceID = appState.selectedSourceID {
            guard sources.contains(where: { $0.id == selectedSourceID }) else {
                appState.selectedSourceID = sources.first?.id
                return
            }
        } else {
            appState.selectedSourceID = sources.first?.id
        }
    }

    @MainActor
    private func refreshWidgetSnapshot() async {
        let currentYear = Calendar.current.component(.year, from: .now)
        let yearRecords = records.filter { $0.periodYear == currentYear }
        let latestRecord = records.first

        let snapshot = PayrollWidgetSnapshot(
            generatedAt: .now,
            currentYear: currentYear,
            yearNetTotal: yearRecords.reduce(0) { $0 + $1.netAmount },
            yearPaymentTotal: yearRecords.reduce(0) { $0 + $1.totalPayments },
            yearDeductionTotal: yearRecords.reduce(0) { $0 + $1.totalDeductions },
            recordCount: records.count,
            sourceCount: sources.count,
            latestRecord: latestRecord.map { record in
                let source = record.source(in: sources)
                return PayrollWidgetSnapshot.LatestRecord(
                    id: record.id,
                    kindRawValue: record.kind.rawValue,
                    sourceName: source?.name ?? PayrollLocalization.text("支給元未設定"),
                    sourceAccentHex: source?.accentHex ?? "#0F766E",
                    paymentDate: record.paymentDate,
                    periodYear: record.periodYear,
                    periodMonth: record.periodMonth,
                    netAmount: record.netAmount,
                    totalPayments: record.totalPayments,
                    totalDeductions: record.totalDeductions
                )
            }
        )

        PayrollWidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func refreshNotifications() async {
        await PayrollNotificationScheduler.refreshNotifications(for: sources)
    }

    private func configureInitialLockStateIfNeeded() {
        guard !hasConfiguredInitialLockState else {
            return
        }

        hasConfiguredInitialLockState = true

        if requiresAuthenticationAtLaunch {
            lockApp()
        }
    }

    private func handleAuthenticationSettingChange(isEnabled: Bool) {
        if isEnabled {
            hasConfiguredInitialLockState = true
        } else {
            unlockApp()
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            guard requiresAuthenticationAtLaunch else {
                return
            }

            lockApp()
        case .active:
            Task {
                await authenticateAppIfNeeded()
            }
        default:
            break
        }
    }

    @MainActor
    private func authenticateAppIfNeeded() async {
        guard requiresAuthenticationAtLaunch,
              isAppLocked,
              !isShowingLaunchSplash,
              scenePhase == .active,
              !isAuthenticating else {
            return
        }

        isAuthenticating = true
        authenticationErrorMessage = nil

        defer {
            isAuthenticating = false
        }

        do {
            try await AppAuthenticationManager.authenticate()
            unlockApp()
        } catch {
            authenticationErrorMessage = AppAuthenticationManager.errorMessage(for: error)
        }
    }

    private func lockApp() {
        authenticationErrorMessage = nil
        isAppLocked = true
        lockAttemptToken = UUID()
    }

    private func unlockApp() {
        authenticationErrorMessage = nil
        isAppLocked = false
    }

    @MainActor
    private func scheduleTrackingAuthorizationRequestIfReady() {
        trackingAuthorizationRequestTask?.cancel()

        guard
            scenePhase == .active,
            !isShowingLaunchSplash,
            !appState.isPresentingOnboarding,
            !isAppLocked,
            !isAuthenticating
        else {
            return
        }

        trackingAuthorizationRequestTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))

            guard
                !Task.isCancelled,
                scenePhase == .active,
                !isShowingLaunchSplash,
                !appState.isPresentingOnboarding,
                !isAppLocked,
                !isAuthenticating
            else {
                return
            }

            AdMobConfiguration.requestTrackingAuthorizationIfNeeded()
        }
    }

    @MainActor
    private func runLaunchExperienceIfNeeded() async {
        guard !hasStartedLaunchExperience else {
            return
        }

        hasStartedLaunchExperience = true
        await playLaunchExperience()
    }

    @MainActor
    private func replayLaunchExperience(_ request: LaunchExperienceReplayRequest) async {
        shareAlert = nil
        sharedTemplateImportPresentation = nil
        sharedRecordPresentation = nil
        quickActionSheet = nil
        plusSheet = nil
        appState.selectedTab = .dashboard
        appState.selectedSourceID = nil

        if request.resetsOnboarding {
            hasCompletedOnboarding = false
        }

        if appState.isPresentingOnboarding {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.86)) {
                appState.isPresentingOnboarding = false
            }
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingLaunchSplash = true
        }

        await playLaunchExperience()
    }

    @MainActor
    private func playLaunchExperience() async {
        try? await Task.sleep(for: .milliseconds(1800))

        withAnimation(.easeInOut(duration: 0.45)) {
            isShowingLaunchSplash = false
        }

        guard !hasCompletedOnboarding else {
            return
        }

        try? await Task.sleep(for: .milliseconds(220))

        withAnimation(.spring(response: 0.76, dampingFraction: 0.88)) {
            appState.isPresentingOnboarding = true
        }
    }

    @MainActor
    private func finishOnboarding(routeTo destinationTab: AppTab) {
        hasCompletedOnboarding = true
        appState.selectedTab = destinationTab

        withAnimation(.spring(response: 0.7, dampingFraction: 0.86)) {
            appState.isPresentingOnboarding = false
        }
    }

    @MainActor
    private func handlePendingQuickActionIfNeeded() {
        guard let action = PayrollQuickActionDispatcher.shared.consumePendingAction() else {
            return
        }

        handleQuickAction(action)
    }

    @MainActor
    private func handleQuickAction(_ action: PayrollHomeQuickAction) {
        hasCompletedOnboarding = true

        if appState.isPresentingOnboarding {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.86)) {
                appState.isPresentingOnboarding = false
            }
        }

        switch action {
        case .createSalaryRecord:
            appState.selectedTab = .records
            quickActionSheet = .record(.salary)
        case .createBonusRecord:
            appState.selectedTab = .records
            quickActionSheet = .record(.bonus)
        case .createTemplate:
            appState.selectedTab = .templates
            if monetizationStore.canCreateTemplate(currentCount: templates.count) {
                quickActionSheet = .template
            } else {
                quickActionSheet = nil
                plusSheet = .templateLimit
            }
        case .openTemplates:
            appState.selectedTab = .templates
            quickActionSheet = nil
        }
    }

    @MainActor
    private func handleIncomingSharedURL(_ url: URL) async {
        if await importSharedTemplateIfNeeded(from: url) {
            return
        }

        _ = presentSharedRecordIfNeeded(from: url)
    }

    @MainActor
    private func importSharedTemplateIfNeeded(from url: URL) async -> Bool {
        do {
            let payload = try PayrollTemplateShareCodec.payload(from: url)
            guard canPresentSharedTemplateImport(payload) else {
                return true
            }

            sharedTemplateImportPresentation = SharedTemplateImportPresentation(payload: payload)
            return true
        } catch PayrollTemplateShareCodec.Error.unsupportedLink {
            return false
        } catch {
            shareAlert = ShareAlert(
                title: PayrollLocalization.text("読み込みに失敗しました"),
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
            return true
        }
    }

    @MainActor
    private func canPresentSharedTemplateImport(_ payload: PayrollTemplateSharePayload) -> Bool {
        guard monetizationStore.canCreateTemplate(currentCount: templates.count) else {
            plusSheet = .templateLimit
            return false
        }

        guard !payload.paymentItems.isEmpty else {
            shareAlert = ShareAlert(
                title: PayrollLocalization.text("読み込みに失敗しました"),
                message: PayrollTemplateShareCodec.Error.noPaymentItems.errorDescription
                    ?? PayrollLocalization.text("支給項目が含まれていないため、このテンプレートは読み込めません。")
            )
            return false
        }

        return true
    }

    @MainActor
    private func importSharedTemplate(
        _ payload: PayrollTemplateSharePayload,
        destination: TemplateImportDestination
    ) throws -> PayrollTemplate {
        guard monetizationStore.canCreateTemplate(currentCount: templates.count) else {
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
            guard monetizationStore.canCreateIncomeSource(currentCount: sources.count) else {
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

    @MainActor
    private func finishSharedTemplateImport(_ template: PayrollTemplate) {
        sharedTemplateImportPresentation = nil
        appState.selectedTab = .templates
        appState.selectedSourceID = template.sourceID
        shareAlert = ShareAlert(
            title: PayrollLocalization.text("テンプレートを読み込みました"),
            message: PayrollLocalization.format("「%@」をテンプレート一覧に追加しました。", template.name)
        )
    }

    @MainActor
    private func presentSharedRecordIfNeeded(from url: URL) -> Bool {
        do {
            let payload = try PayrollRecordShareCodec.payload(from: url)
            sharedRecordPresentation = SharedRecordPresentation(payload: payload)
            return true
        } catch PayrollRecordShareCodec.Error.unsupportedLink {
            return false
        } catch {
            shareAlert = ShareAlert(
                title: PayrollLocalization.text("共有データを開けませんでした"),
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
            return true
        }
    }
}

private struct ShareAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct SharedTemplateImportPresentation: Identifiable {
    let id = UUID()
    let payload: PayrollTemplateSharePayload
}

private struct SharedRecordPresentation: Identifiable {
    let id = UUID()
    let payload: PayrollRecordSharePayload
}

private enum PayrollViewportOrientation: Hashable {
    case portrait
    case landscape

    init(size: CGSize) {
        self = size.width > size.height ? .landscape : .portrait
    }
}

private enum HomeQuickActionSheet: Identifiable {
    case record(PayrollRecordKind)
    case template

    var id: String {
        switch self {
        case .record(let kind):
            "record-\(kind.rawValue)"
        case .template:
            "template"
        }
    }
}

private struct AppLockView: View {
    let tint: Color
    let availabilitySummary: String
    let errorMessage: String?
    let isAuthenticating: Bool
    let unlockAction: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(tint)
                    }

                VStack(spacing: 8) {
                    Text("アプリを保護しています")
                        .font(.title3.weight(.bold))

                    Text(PayrollLocalization.format("%@でロックを解除してください。", availabilitySummary))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button(action: unlockAction) {
                    if isAuthenticating {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("認証する")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(tint)
                )
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .disabled(isAuthenticating)

                Spacer()
            }
            .padding(.vertical, 48)
        }
    }
}
