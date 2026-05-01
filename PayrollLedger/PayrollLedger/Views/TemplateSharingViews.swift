import AVFoundation
import SwiftUI
import UIKit

enum TemplateImportDestination: Hashable {
    case existing(UUID)
    case sharedSource
}

struct TemplateSharePreviewView: View {
    let template: PayrollTemplate
    let source: IncomeSource?

    @State private var isShowingCopiedBanner = false

    private var shareURL: URL {
        PayrollTemplateShareCodec.exportURL(for: template, source: source)
    }

    private var accentColor: Color {
        Color(hex: source?.accentHex ?? "#0F766E")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("テンプレート共有")
                    .font(.title3.weight(.bold))

                Text("リンクを開くか QR コードを読み取ると、相手のアプリへテンプレートをそのまま取り込めます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ShareQRCodeCard(
                    urlString: shareURL.absoluteString,
                    accentColor: accentColor,
                    caption: "別の端末では QR コードを読み取るだけで取り込めます。"
                )

                VStack(alignment: .leading, spacing: 10) {
                    detailRow(title: "テンプレート名", value: template.name)
                    detailRow(title: "種別", value: template.kind.title)
                    detailRow(title: "支給元", value: source?.name ?? PayrollLocalization.text("未設定"))
                    detailRow(title: "支給項目", value: PayrollLocalization.countLabel(template.paymentItems.count))
                    detailRow(title: "控除項目", value: PayrollLocalization.countLabel(template.deductionItems.count))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

                ShareLink(
                    item: shareURL,
                    subject: Text(PayrollLocalization.format("給与記録テンプレート: %@", template.name)),
                    message: Text("リンクを開くと、給与記録アプリにテンプレートを取り込めます。")
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
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("テンプレートを共有")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(PayrollLocalization.text(title))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}

struct TemplateImportView: View {
    let sources: [IncomeSource]
    let initialSourceID: UUID?
    let canCreateSharedSource: Bool
    let onImport: (PayrollTemplateSharePayload, TemplateImportDestination) throws -> PayrollTemplate
    let onImported: (PayrollTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingQRCodeScanner = false
    @State private var isShowingTextImport = false
    @State private var scannedImportValue: String?
    @State private var textImportValue: String?
    @State private var pendingImport: PendingTemplateImport?
    @State private var errorMessage: String?
    @State private var plusSheet: PayrollPlusPaywall?

    var body: some View {
        Form {
            Section("カメラで読み込み") {
                Button {
                    isShowingQRCodeScanner = true
                } label: {
                    Label("カメラでQRコードを読み取る", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("カメラで共有テンプレートの QR コードを読み取ると、読み込み先の選択へ進みます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("オプション") {
                Button {
                    isShowingTextImport = true
                } label: {
                    Label("リンクや共有テキストから読み込む", systemImage: "doc.text.viewfinder")
                }

                Text("QRコードを読み取れない場合は、共有リンクや共有テキストを貼り付けて読み込めます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("共有テンプレートを読み込む")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isShowingQRCodeScanner, onDismiss: handleQRCodeScannerDismiss) {
            NavigationStack {
                TemplateQRCodeScannerView { scannedValue in
                    let trimmedValue = scannedValue.trimmed
                    guard !trimmedValue.isEmpty else {
                        return
                    }

                    scannedImportValue = trimmedValue
                    isShowingQRCodeScanner = false
                }
            }
        }
        .sheet(isPresented: $isShowingTextImport, onDismiss: handleTextImportDismiss) {
            NavigationStack {
                TemplateTextImportView { sharedValue in
                    let trimmedValue = sharedValue.trimmed
                    guard !trimmedValue.isEmpty else {
                        return
                    }

                    textImportValue = trimmedValue
                    isShowingTextImport = false
                }
            }
        }
        .sheet(item: $plusSheet) { paywall in
            NavigationStack {
                PlusPlanView(context: paywall)
            }
        }
        .sheet(item: $pendingImport) { pendingImport in
            NavigationStack {
                TemplateImportSourceSelectionView(
                    payload: pendingImport.payload,
                    sources: sources,
                    initialSourceID: initialSourceID,
                    canCreateSharedSource: canCreateSharedSource,
                    onImport: { destination in
                        try onImport(pendingImport.payload, destination)
                    },
                    onImported: { template in
                        self.pendingImport = nil
                        onImported(template)
                        dismiss()
                    }
                )
            }
        }
        .alert("読み込みに失敗しました", isPresented: errorIsPresented) {
            Button("閉じる") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func handleQRCodeScannerDismiss() {
        guard let scannedImportValue else {
            return
        }

        self.scannedImportValue = nil

        DispatchQueue.main.async {
            prepareSharedTemplateImport(from: scannedImportValue)
        }
    }

    private func handleTextImportDismiss() {
        guard let textImportValue else {
            return
        }

        self.textImportValue = nil

        DispatchQueue.main.async {
            prepareSharedTemplateImport(from: textImportValue)
        }
    }

    private func prepareSharedTemplateImport(from sharedValue: String) {
        do {
            let payload = try PayrollTemplateShareCodec.payload(from: sharedValue)
            guard !payload.paymentItems.isEmpty else {
                throw PayrollTemplateShareCodec.Error.noPaymentItems
            }

            pendingImport = PendingTemplateImport(payload: payload)
        } catch let error as PayrollMonetizationError {
            plusSheet = error.paywall
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct TemplateTextImportView: View {
    let onImport: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var importText = ""

    var body: some View {
        Form {
            Section("リンクや共有テキスト") {
                TextField("payrollledger://...", text: $importText, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(3...8)

                Button("クリップボードのリンクを貼り付け") {
                    importText = UIPasteboard.general.url?.absoluteString
                        ?? UIPasteboard.general.string
                        ?? ""
                }
            }

            Section {
                Button("テンプレートを読み込む") {
                    onImport(importText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(importText.trimmed.isEmpty)
            }

            Section("ヒント") {
                Text("通常は、相手から届いた共有リンクをそのまま開くだけで自動取り込みできます。うまく開けない場合だけ、この画面にリンクを貼り付けてください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("テキストから読み込む")
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

private struct TemplateQRCodeScannerView: View {
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var cameraErrorMessage: String?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            scannerContent
        }
        .navigationTitle("QRコードを読み取る")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.black.opacity(0.72), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }
        }
        .task {
            await requestCameraAccessIfNeeded()
        }
        .onAppear {
            authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    @ViewBuilder
    private var scannerContent: some View {
        switch authorizationStatus {
        case .authorized:
            ZStack {
                TemplateQRCodeCameraPreview(
                    onScan: onScan,
                    onFailure: { message in
                        cameraErrorMessage = message
                    }
                )
                .ignoresSafeArea()

                TemplateQRCodeScannerOverlay(message: cameraErrorMessage)
            }
        case .notDetermined:
            TemplateQRCodeScannerStatusView(
                systemImage: "camera.viewfinder",
                title: "カメラの使用許可を確認しています",
                message: nil
            )
        case .restricted:
            TemplateQRCodeScannerStatusView(
                systemImage: "lock.slash",
                title: "カメラへのアクセスが制限されています。",
                message: "スクリーンタイムや管理設定によりカメラを利用できません。"
            )
        case .denied:
            TemplateQRCodeScannerStatusView(
                systemImage: "camera.badge.ellipsis",
                title: "カメラへのアクセスが許可されていません。",
                message: "設定でカメラへのアクセスを許可すると、QRコードを読み取れます。",
                actionTitle: "設定を開く",
                action: openAppSettings
            )
        @unknown default:
            TemplateQRCodeScannerStatusView(
                systemImage: "exclamationmark.triangle",
                title: "カメラを起動できませんでした。",
                message: nil
            )
        }
    }

    @MainActor
    private func requestCameraAccessIfNeeded() async {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard currentStatus == .notDetermined else {
            authorizationStatus = currentStatus
            return
        }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = granted ? .authorized : .denied
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }
}

private struct TemplateQRCodeScannerOverlay: View {
    let message: String?

    var body: some View {
        GeometryReader { geometry in
            let scannerSide = min(geometry.size.width * 0.78, 320)

            VStack(spacing: 24) {
                Spacer()

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white, lineWidth: 3)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.black.opacity(0.24), lineWidth: 8)
                    )
                    .frame(width: scannerSide, height: scannerSide)
                    .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)

                VStack(spacing: 8) {
                    Text("QRコードを枠に合わせてください")
                        .font(.headline.weight(.bold))

                    Text(message ?? PayrollLocalization.text("読み取れたら自動で読み込み先の選択へ進みます。"))
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(message == nil ? .white.opacity(0.78) : Color.yellow)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
}

private struct TemplateQRCodeScannerStatusView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(.white)

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
        }
        .padding(28)
    }
}

private struct TemplateQRCodeCameraPreview: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> TemplateQRCodeScannerViewController {
        TemplateQRCodeScannerViewController(
            metadataDelegate: context.coordinator,
            onFailure: onFailure
        )
    }

    func updateUIViewController(_ uiViewController: TemplateQRCodeScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
    }

    static func dismantleUIViewController(_ uiViewController: TemplateQRCodeScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didScan,
                  let readableCode = metadataObjects
                    .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
                    .first(where: { $0.type == .qr }),
                  let scannedValue = readableCode.stringValue else {
                return
            }

            didScan = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onScan(scannedValue)
        }
    }
}

private final class TemplateQRCodeScannerViewController: UIViewController {
    private let captureSession = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let metadataDelegate: AVCaptureMetadataOutputObjectsDelegate
    private let onFailure: (String) -> Void
    private let sessionQueue = DispatchQueue(label: "com.salarylog.template-qr-scanner.session")
    private var isSessionConfigured = false

    init(
        metadataDelegate: AVCaptureMetadataOutputObjectsDelegate,
        onFailure: @escaping (String) -> Void
    ) {
        self.metadataDelegate = metadataDelegate
        self.onFailure = onFailure
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds

        if let connection = previewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    func stopScanning() {
        let captureSession = captureSession
        sessionQueue.async {
            guard captureSession.isRunning else {
                return
            }

            captureSession.stopRunning()
        }
    }

    private func startScanning() {
        guard isSessionConfigured else {
            return
        }

        let captureSession = captureSession
        sessionQueue.async {
            guard !captureSession.isRunning else {
                return
            }

            captureSession.startRunning()
        }
    }

    private func configureSession() {
        guard !isSessionConfigured else {
            return
        }

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            reportFailure("この端末ではカメラを利用できません。")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)

            captureSession.beginConfiguration()
            captureSession.sessionPreset = .high
            defer {
                captureSession.commitConfiguration()
            }

            guard captureSession.canAddInput(videoInput) else {
                reportFailure("カメラを起動できませんでした。")
                return
            }
            captureSession.addInput(videoInput)

            guard captureSession.canAddOutput(metadataOutput) else {
                reportFailure("QRコードの読み取りに対応していません。")
                return
            }
            captureSession.addOutput(metadataOutput)

            guard metadataOutput.availableMetadataObjectTypes.contains(.qr) else {
                reportFailure("QRコードの読み取りに対応していません。")
                return
            }
            metadataOutput.setMetadataObjectsDelegate(metadataDelegate, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]

            previewLayer.session = captureSession
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.insertSublayer(previewLayer, at: 0)
            isSessionConfigured = true
        } catch {
            reportFailure("カメラを起動できませんでした。")
        }
    }

    private func reportFailure(_ message: String) {
        DispatchQueue.main.async {
            self.onFailure(PayrollLocalization.text(message))
        }
    }
}

struct TemplateImportSourceSelectionView: View {
    let payload: PayrollTemplateSharePayload
    let sources: [IncomeSource]
    let initialSourceID: UUID?
    let canCreateSharedSource: Bool
    let onImport: (TemplateImportDestination) throws -> PayrollTemplate
    let onImported: (PayrollTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var destination: TemplateImportDestination
    @State private var errorMessage: String?
    @State private var plusSheet: PayrollPlusPaywall?

    init(
        payload: PayrollTemplateSharePayload,
        sources: [IncomeSource],
        initialSourceID: UUID?,
        canCreateSharedSource: Bool,
        onImport: @escaping (TemplateImportDestination) throws -> PayrollTemplate,
        onImported: @escaping (PayrollTemplate) -> Void
    ) {
        self.payload = payload
        self.sources = sources
        self.initialSourceID = initialSourceID
        self.canCreateSharedSource = canCreateSharedSource
        self.onImport = onImport
        self.onImported = onImported
        _destination = State(
            initialValue: Self.initialDestination(
                payload: payload,
                sources: sources,
                initialSourceID: initialSourceID,
                canCreateSharedSource: canCreateSharedSource
            )
        )
    }

    var body: some View {
        Form {
            Section("共有テンプレート") {
                detailRow(
                    title: "テンプレート名",
                    value: payload.templateName.trimmed.isEmpty
                        ? PayrollLocalization.text("共有テンプレート")
                        : payload.templateName.trimmed
                )
                detailRow(title: "共有元", value: sharedSourceName)
                detailRow(title: "種別", value: sharedKind.title)
                detailRow(title: "支給項目", value: PayrollLocalization.countLabel(payload.paymentItems.count))
                detailRow(title: "控除項目", value: PayrollLocalization.countLabel(payload.deductionItems.count))
            }

            Section("読み込み先の支給元") {
                Picker("支給元", selection: $destination) {
                    ForEach(sources) { source in
                        Text(source.name)
                            .tag(TemplateImportDestination.existing(source.id))
                    }

                    if canCreateSharedSource {
                        Text(PayrollLocalization.format("新規作成: %@", sharedSourceName))
                            .tag(TemplateImportDestination.sharedSource)
                    }
                }
                .pickerStyle(.inline)

                Text("共有されたテンプレートを、選択した支給元のテンプレートとして保存します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(importButtonTitle) {
                    importSharedTemplate()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(!canImportSelectedDestination)
            }
        }
        .navigationTitle("読み込み先を選択")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
        .sheet(item: $plusSheet) { paywall in
            NavigationStack {
                PlusPlanView(context: paywall)
            }
        }
        .alert("読み込みに失敗しました", isPresented: errorIsPresented) {
            Button("閉じる") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var sharedSourceName: String {
        PayrollTemplateShareCodec.sourceName(for: payload)
    }

    private var sharedKind: PayrollRecordKind {
        PayrollRecordKind(rawValue: payload.kindRawValue) ?? .salary
    }

    private var canImportSelectedDestination: Bool {
        switch destination {
        case .existing(let sourceID):
            sources.contains { $0.id == sourceID }
        case .sharedSource:
            canCreateSharedSource
        }
    }

    private var importButtonTitle: String {
        switch destination {
        case .existing:
            PayrollLocalization.text("この支給元に読み込む")
        case .sharedSource:
            PayrollLocalization.text("新規支給元に読み込む")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func detailRow(title: String, value: String) -> some View {
        LabeledContent(PayrollLocalization.text(title), value: value)
    }

    private func importSharedTemplate() {
        do {
            let template = try onImport(destination)
            onImported(template)
            dismiss()
        } catch let error as PayrollMonetizationError {
            plusSheet = error.paywall
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private static func initialDestination(
        payload: PayrollTemplateSharePayload,
        sources: [IncomeSource],
        initialSourceID: UUID?,
        canCreateSharedSource: Bool
    ) -> TemplateImportDestination {
        let sharedSourceName = PayrollTemplateShareCodec.sourceName(for: payload)

        if let matchingSource = sources.first(where: {
            $0.name.trimmed.localizedCaseInsensitiveCompare(sharedSourceName) == .orderedSame
        }) {
            return .existing(matchingSource.id)
        }

        if let initialSourceID,
           sources.contains(where: { $0.id == initialSourceID }) {
            return .existing(initialSourceID)
        }

        if let firstSource = sources.first {
            return .existing(firstSource.id)
        }

        if canCreateSharedSource {
            return .sharedSource
        }

        return .sharedSource
    }
}

private struct PendingTemplateImport: Identifiable {
    let id = UUID()
    let payload: PayrollTemplateSharePayload
}
