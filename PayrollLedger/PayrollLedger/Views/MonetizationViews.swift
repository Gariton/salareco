import GoogleMobileAds
import SwiftUI
import UIKit

enum FreePlanAdPlacement {
    case dashboard
    case records
    case templates
    case settings
    case recordEditor
    case templateEditor
    case recordDetail
}

struct PlusPlanView: View {
    let context: PayrollPlusPaywall

    @Environment(PayrollMonetizationStore.self) private var monetization
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard

                benefitsSection

                purchaseSection
            }
            .padding()
        }
        .background(PayrollScreenBackground(accent: Color(hex: "#0F766E")))
        .navigationTitle("Plusプラン")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
        .task {
            await monetization.prepare()
        }
    }

    private var heroCard: some View {
        PayrollSurfaceCard(cornerRadius: 28, padding: 22, tint: Color(hex: "#0F766E")) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    PayrollIconBadge(
                        systemImage: monetization.isPlusActive ? "checkmark.seal.fill" : "sparkles",
                        tint: Color(hex: "#0F766E"),
                        size: 48
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.title)
                            .font(.title3.weight(.black))

                        Text("買い切りのPlusプラン")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#0F766E"))
                    }

                    Spacer(minLength: 8)
                }

                Text(context.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(monetization.isPlusActive ? PayrollLocalization.text("Plus有効") : monetization.plusDisplayPrice)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(hex: "#0F766E"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#0F766E").opacity(0.12), in: Capsule())
            }
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plusで解放される機能")
                .font(.headline)

            ForEach(PayrollPlusBenefit.all) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    PayrollIconBadge(systemImage: benefit.systemImage, tint: Color(hex: "#0F766E"), size: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(benefit.title)
                            .font(.subheadline.weight(.bold))

                        Text(benefit.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.34), lineWidth: 1)
                }
            }
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = monetization.purchaseStatusMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#0F766E"))
            }

            if let message = monetization.purchaseErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task {
                    await monetization.purchasePlus()
                }
            } label: {
                HStack {
                    Spacer()
                    if monetization.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(monetization.plusPurchaseButtonTitle)
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(monetization.isPlusActive || monetization.plusProduct == nil ? Color.gray : Color(hex: "#0F766E"))
            )
            .disabled(monetization.isPlusActive || monetization.plusProduct == nil || monetization.isPurchasing)

            Button {
                Task {
                    await monetization.restorePurchases()
                }
            } label: {
                HStack {
                    Spacer()
                    if monetization.isRestoringPurchases {
                        ProgressView()
                    } else {
                        Label("購入情報を復元", systemImage: "arrow.clockwise")
                    }
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
            .disabled(monetization.isRestoringPurchases)

            #if DEBUG
            Text(PayrollLocalization.format("StoreKitテスト用の商品ID: %@", PayrollMonetizationStore.plusProductID))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Debug: Plusを有効化", isOn: Binding(
                get: { monetization.debugPlusOverrideEnabled },
                set: { monetization.debugPlusOverrideEnabled = $0 }
            ))
            .font(.footnote)
            #endif
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.34), lineWidth: 1)
        }
    }
}

struct PlusPlanStatusRow: View {
    let sourceCount: Int
    let templateCount: Int
    let action: () -> Void

    @Environment(PayrollMonetizationStore.self) private var monetization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PayrollIconBadge(
                    systemImage: monetization.isPlusActive ? "checkmark.seal.fill" : "sparkles",
                    tint: Color(hex: "#0F766E"),
                    size: 42
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(PayrollLocalization.text(monetization.isPlusActive ? "Plusプラン有効" : "無料プラン"))
                        .font(.headline)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            Button(action: action) {
                HStack(spacing: 8) {
                    Label(PayrollLocalization.text(monetization.isPlusActive ? "Plus内容を確認" : "Plusプランを見る"), systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "#0F766E"))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        if monetization.isPlusActive {
            return PayrollLocalization.text("支給元、テンプレート、写真入力、CSV書き出し、広告非表示が解放されています。")
        }

        return PayrollLocalization.format(
            "支給元 %1$lld/%2$lld社、テンプレート %3$lld/%4$lld件まで利用できます。",
            Int64(sourceCount),
            Int64(PayrollPlanLimits.freeIncomeSourceLimit),
            Int64(templateCount),
            Int64(PayrollPlanLimits.freeTemplateLimit)
        )
    }
}

struct FreePlanBannerAdView: View {
    let placement: FreePlanAdPlacement
    let horizontalPadding: Bool

    @Environment(PayrollMonetizationStore.self) private var monetization

    init(
        placement: FreePlanAdPlacement = .dashboard,
        horizontalPadding: Bool = true
    ) {
        self.placement = placement
        self.horizontalPadding = horizontalPadding
    }

    var body: some View {
        if !monetization.isPlusActive, let bannerAdUnitID = AdMobConfiguration.bannerAdUnitID {
            AdMobAdaptiveBannerView(adUnitID: bannerAdUnitID)
                .padding(.horizontal, horizontalPadding ? 16 : 0)
                .accessibilityLabel(Text("広告"))
        }
    }
}

private struct AdMobAdaptiveBannerView: View {
    let adUnitID: String

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        VStack {
            if availableWidth > 0 {
                let adSize = currentOrientationAnchoredAdaptiveBanner(width: availableWidth)
                AdMobBannerViewRepresentable(adUnitID: adUnitID, adSize: adSize)
                    .frame(width: adSize.size.width, height: adSize.size.height)
                    .id(bannerIdentity(for: adSize))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: bannerHeight)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateAvailableWidth(proxy.size.width)
                    }
                    .onChange(of: proxy.size.width) { _, width in
                        updateAvailableWidth(width)
                    }
            }
        }
    }

    private var bannerHeight: CGFloat {
        guard availableWidth > 0 else {
            return 50
        }

        return currentOrientationAnchoredAdaptiveBanner(width: availableWidth).size.height
    }

    private func updateAvailableWidth(_ width: CGFloat) {
        let roundedWidth = max(0, width.rounded(.down))
        guard abs(roundedWidth - availableWidth) >= 1 else {
            return
        }

        availableWidth = roundedWidth
    }

    private func bannerIdentity(for adSize: AdSize) -> String {
        "\(Int(availableWidth.rounded()))-\(Int(adSize.size.height.rounded()))"
    }
}

private struct AdMobBannerViewRepresentable: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = UIApplication.shared.payrollTopViewController
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ bannerView: BannerView, context: Context) {
        bannerView.rootViewController = UIApplication.shared.payrollTopViewController
    }
}

private extension UIApplication {
    var payrollTopViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .payrollTopPresentedViewController
    }
}

private extension UIViewController {
    var payrollTopPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.payrollTopPresentedViewController
        }

        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.payrollTopPresentedViewController ?? navigationController
        }

        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.payrollTopPresentedViewController ?? tabBarController
        }

        return self
    }
}

struct PlusLockedFeatureRow: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                PayrollIconBadge(systemImage: systemImage, tint: Color(hex: "#0F766E"), size: 36)

                VStack(alignment: .leading, spacing: 5) {
                    Text(PayrollLocalization.text(title))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(PayrollLocalization.text(message))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(PayrollLocalization.text(actionTitle), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "#0F766E"))
                }

                Spacer(minLength: 8)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
