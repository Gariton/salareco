import Foundation
import Observation
import StoreKit

enum PayrollPlanLimits {
    static let freeIncomeSourceLimit = 1
    static let freeTemplateLimit = 3
    static let freeWorkHourDefinitionLimit = 2
}

struct PayrollPlusBenefit: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String

    static let all: [PayrollPlusBenefit] = [
        PayrollPlusBenefit(
            id: "income-sources",
            title: PayrollLocalization.text("支給元を無制限に登録"),
            detail: PayrollLocalization.text("無料プランは1社まで。副業、転職、複数勤務先の管理をPlusで解放します。"),
            systemImage: "building.2.crop.circle"
        ),
        PayrollPlusBenefit(
            id: "templates",
            title: PayrollLocalization.text("テンプレートを無制限に保存"),
            detail: PayrollLocalization.text("無料プランは3件まで。毎月の給与、賞与、勤務形態別のひな形を増やせます。"),
            systemImage: "square.stack.3d.up"
        ),
        PayrollPlusBenefit(
            id: "photo-import",
            title: PayrollLocalization.text("給与明細の写真から自動入力"),
            detail: PayrollLocalization.text("支給項目と控除項目をOCRで読み取り、手入力の手間を減らします。"),
            systemImage: "photo.badge.magnifyingglass"
        ),
        PayrollPlusBenefit(
            id: "work-hours",
            title: PayrollLocalization.text("勤務時間項目を無制限に管理"),
            detail: PayrollLocalization.text("無料プランは2件まで。時間外、深夜、休日など細かい内訳を残せます。"),
            systemImage: "clock.badge.checkmark"
        ),
        PayrollPlusBenefit(
            id: "csv-export",
            title: PayrollLocalization.text("給与記録をCSVで書き出し"),
            detail: PayrollLocalization.text("記録一覧をCSVにして、表計算やバックアップに使えます。"),
            systemImage: "tablecells.badge.ellipsis"
        ),
        PayrollPlusBenefit(
            id: "ad-free",
            title: PayrollLocalization.text("アプリ内広告を非表示"),
            detail: PayrollLocalization.text("無料プランのバナー広告を消して、記録と確認に集中できます。"),
            systemImage: "rectangle.slash"
        ),
        PayrollPlusBenefit(
            id: "future",
            title: PayrollLocalization.text("今後のPlus機能も利用可能"),
            detail: PayrollLocalization.text("買い切りのPlusとして、追加予定の便利機能にも対応しやすい設計です。"),
            systemImage: "sparkles"
        ),
    ]
}

enum PayrollPlusPaywall: Identifiable {
    case general
    case incomeSourceLimit
    case templateLimit
    case photoImport
    case workHourDefinitionLimit
    case csvExport
    case adFree

    var id: String {
        switch self {
        case .general:
            "general"
        case .incomeSourceLimit:
            "income-source-limit"
        case .templateLimit:
            "template-limit"
        case .photoImport:
            "photo-import"
        case .workHourDefinitionLimit:
            "work-hour-definition-limit"
        case .csvExport:
            "csv-export"
        case .adFree:
            "ad-free"
        }
    }

    var title: String {
        switch self {
        case .general:
            PayrollLocalization.text("給与管理 Plus")
        case .incomeSourceLimit:
            PayrollLocalization.text("支給元をさらに追加")
        case .templateLimit:
            PayrollLocalization.text("テンプレートをさらに追加")
        case .photoImport:
            PayrollLocalization.text("写真から自動入力")
        case .workHourDefinitionLimit:
            PayrollLocalization.text("勤務時間項目を増やす")
        case .csvExport:
            PayrollLocalization.text("CSVを書き出す")
        case .adFree:
            PayrollLocalization.text("広告を非表示")
        }
    }

    var message: String {
        switch self {
        case .general:
            PayrollLocalization.text("無料プランのまま給与記録は続けられます。Plusでは複数支給元、テンプレート、写真入力、CSV書き出し、広告非表示を買い切りで解放します。")
        case .incomeSourceLimit:
            PayrollLocalization.text("無料プランで登録できる支給元は1社までです。Plusにすると副業や転職前後の支給元もまとめて管理できます。")
        case .templateLimit:
            PayrollLocalization.text("無料プランで保存できるテンプレートは3件までです。Plusにすると給与、賞与、勤務形態別のひな形を無制限に保存できます。")
        case .photoImport:
            PayrollLocalization.text("無料プランでは手入力で記録できます。Plusでは給与明細の写真から支給項目と控除項目を読み取れます。")
        case .workHourDefinitionLimit:
            PayrollLocalization.text("無料プランで追加できる勤務時間項目は2件までです。Plusにすると時間外、深夜、休日などを細かく残せます。")
        case .csvExport:
            PayrollLocalization.text("無料プランではアプリ内で記録を確認できます。Plusでは給与記録をCSVで書き出し、表計算やバックアップに活用できます。")
        case .adFree:
            PayrollLocalization.text("無料プランでは画面内に小さなバナー広告が表示されます。Plusにすると広告を非表示にできます。")
        }
    }
}

enum PayrollMonetizationError: LocalizedError {
    case requiresPlus(PayrollPlusPaywall)

    var paywall: PayrollPlusPaywall {
        switch self {
        case .requiresPlus(let paywall):
            paywall
        }
    }

    var errorDescription: String? {
        paywall.message
    }
}

@MainActor
@Observable
final class PayrollMonetizationStore {
    static let plusProductID = "com.example.PayrollLedger.plus"

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var isRestoringPurchases = false
    var purchaseErrorMessage: String?
    var purchaseStatusMessage: String?

    private var hasPrepared = false
    private var entitlementRefreshToken = UUID()

    @ObservationIgnored
    private var transactionUpdatesTask: Task<Void, Never>?

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var plusProduct: Product? {
        products.first { $0.id == Self.plusProductID }
    }

    var plusDisplayPrice: String {
        plusProduct?.displayPrice ?? PayrollLocalization.text("買い切り")
    }

    var isPlusActive: Bool {
        _ = entitlementRefreshToken

        if purchasedProductIDs.contains(Self.plusProductID) {
            return true
        }

        #if DEBUG
        if UserDefaults.standard.bool(forKey: Self.debugPlusOverrideKey) {
            return true
        }
        #endif

        return false
    }

    var plusPurchaseButtonTitle: String {
        if isPlusActive {
            return PayrollLocalization.text("Plusは有効です")
        }

        if plusProduct == nil {
            return PayrollLocalization.text("Plusを読み込み中")
        }

        return PayrollLocalization.format("買い切りでPlusにする %@", plusDisplayPrice)
    }

    #if DEBUG
    static let debugPlusOverrideKey = "monetization.debugPlusOverride"

    var debugPlusOverrideEnabled: Bool {
        get {
            _ = entitlementRefreshToken
            return UserDefaults.standard.bool(forKey: Self.debugPlusOverrideKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.debugPlusOverrideKey)
            entitlementRefreshToken = UUID()
        }
    }
    #endif

    func prepare() async {
        guard !hasPrepared else {
            return
        }

        hasPrepared = true
        observeTransactionUpdates()
        await refreshPurchasedProducts()
        await loadProducts()
    }

    func loadProducts() async {
        guard !isLoadingProducts else {
            return
        }

        isLoadingProducts = true
        purchaseErrorMessage = nil

        defer {
            isLoadingProducts = false
        }

        do {
            products = try await Product.products(for: [Self.plusProductID])

            if plusProduct == nil {
                #if DEBUG
                purchaseErrorMessage = PayrollLocalization.format("Plusプランが見つかりません。App Store ConnectまたはStoreKit設定で商品ID %@ の買い切り商品を作成してください。", Self.plusProductID)
                #else
                purchaseErrorMessage = PayrollLocalization.text("現在Plusプランを利用できません。時間をおいて再度お試しください。")
                #endif
            }
        } catch {
            purchaseErrorMessage = PayrollLocalization.text("Plusプラン情報を読み込めませんでした。通信状況を確認してもう一度お試しください。")
        }
    }

    func purchasePlus() async {
        if plusProduct == nil {
            await loadProducts()
        }

        guard let product = plusProduct else {
            purchaseErrorMessage = PayrollLocalization.format("Plusプランが見つかりません。App Store Connectで商品ID %@ の買い切り商品を作成してください。", Self.plusProductID)
            return
        }

        isPurchasing = true
        purchaseErrorMessage = nil
        purchaseStatusMessage = nil

        defer {
            isPurchasing = false
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try checkVerified(verificationResult)
                purchasedProductIDs.insert(transaction.productID)
                entitlementRefreshToken = UUID()
                await transaction.finish()
                purchaseStatusMessage = PayrollLocalization.text("Plusプランが有効になりました。")
            case .pending:
                purchaseStatusMessage = PayrollLocalization.text("購入の承認待ちです。承認後にPlusが有効になります。")
            case .userCancelled:
                break
            @unknown default:
                purchaseErrorMessage = PayrollLocalization.text("購入状態を確認できませんでした。時間をおいて再度お試しください。")
            }
        } catch {
            purchaseErrorMessage = PayrollLocalization.text("購入を完了できませんでした。時間をおいて再度お試しください。")
        }
    }

    func restorePurchases() async {
        isRestoringPurchases = true
        purchaseErrorMessage = nil
        purchaseStatusMessage = nil

        defer {
            isRestoringPurchases = false
        }

        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()
            purchaseStatusMessage = isPlusActive
                ? PayrollLocalization.text("購入情報を復元しました。")
                : PayrollLocalization.text("復元できるPlus購入が見つかりませんでした。")
        } catch {
            purchaseErrorMessage = PayrollLocalization.text("購入情報を復元できませんでした。時間をおいて再度お試しください。")
        }
    }

    func refreshPurchasedProducts() async {
        var activeProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.productID == Self.plusProductID,
                  transaction.revocationDate == nil else {
                continue
            }

            activeProductIDs.insert(transaction.productID)
        }

        purchasedProductIDs = activeProductIDs
        entitlementRefreshToken = UUID()
    }

    func canCreateIncomeSource(currentCount: Int) -> Bool {
        isPlusActive || currentCount < PayrollPlanLimits.freeIncomeSourceLimit
    }

    func canCreateTemplate(currentCount: Int) -> Bool {
        isPlusActive || currentCount < PayrollPlanLimits.freeTemplateLimit
    }

    func canAddWorkHourDefinition(currentCount: Int) -> Bool {
        isPlusActive || currentCount < PayrollPlanLimits.freeWorkHourDefinitionLimit
    }

    func canExportCSV() -> Bool {
        isPlusActive
    }

    private func observeTransactionUpdates() {
        guard transactionUpdatesTask == nil else {
            return
        }

        transactionUpdatesTask = Task {
            for await result in Transaction.updates {
                guard let transaction = try? checkVerified(result) else {
                    continue
                }

                if transaction.productID == Self.plusProductID {
                    await refreshPurchasedProducts()
                }

                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}
