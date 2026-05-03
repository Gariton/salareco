import SwiftUI

struct LaunchSplashView: View {
    @State private var isRevealed = false
    @State private var rotatesOrbit = false
    @State private var pulsesGlow = false

    var body: some View {
        GeometryReader { geometry in
            let heroSize = min(geometry.size.width, geometry.size.height) * 0.38

            ZStack {
                AnimatedAuroraBackdrop(
                    primary: Color(hex: "#0F766E"),
                    secondary: Color(hex: "#2563EB"),
                    tertiary: Color(hex: "#111827")
                )

                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(0.34),
                                        Color(hex: "#A7F3D0").opacity(0.08),
                                        .clear,
                                    ],
                                    center: .center,
                                    startRadius: 14,
                                    endRadius: heroSize * 0.68
                                )
                            )
                            .scaleEffect(pulsesGlow ? 1.12 : 0.92)
                            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulsesGlow)

                        Circle()
                            .stroke(.white.opacity(0.16), lineWidth: 1.5)
                            .frame(width: heroSize * 1.04, height: heroSize * 1.04)

                        Circle()
                            .trim(from: 0.08, to: 0.72)
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        Color(hex: "#A7F3D0"),
                                        Color(hex: "#BFDBFE"),
                                        Color(hex: "#A7F3D0"),
                                    ],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: heroSize * 1.16, height: heroSize * 1.16)
                            .rotationEffect(.degrees(rotatesOrbit ? 360 : 0))

                        Circle()
                            .trim(from: 0.24, to: 0.88)
                            .stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: heroSize * 0.88, height: heroSize * 0.88)
                            .rotationEffect(.degrees(rotatesOrbit ? -270 : 0))

                        SplashLedgerMark(isRevealed: isRevealed)
                            .frame(width: heroSize, height: heroSize)
                    }
                    .frame(width: heroSize * 1.3, height: heroSize * 1.3)

                    VStack(spacing: 12) {
                        Text("給与記録")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .offset(y: isRevealed ? 0 : 18)
                            .opacity(isRevealed ? 1 : 0)

                        Text("記録、分析、共有までを一つの流れに。")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .offset(y: isRevealed ? 0 : 16)
                            .opacity(isRevealed ? 1 : 0)
                    }

                    SplashProgressBar(isAnimating: isRevealed)
                        .frame(width: min(geometry.size.width - 64, 320))
                }
                .padding(.horizontal, 32)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.78)) {
                    isRevealed = true
                }
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    rotatesOrbit = true
                }
                pulsesGlow = true
            }
        }
    }
}

struct OnboardingTourView: View {
    let onComplete: (AppTab) -> Void

    @State private var currentPage = 0

    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                title: PayrollLocalization.text("支給元を整える"),
                subtitle: PayrollLocalization.text("最初に勤務先や支給元を登録すると、画面全体のフィルタとカラーがそろいます。"),
                accent: Color(hex: "#0F766E"),
                hero: .source,
                highlights: [
                    .init(systemImage: "building.2.crop.circle", title: PayrollLocalization.text("支給元を追加"), detail: PayrollLocalization.text("設定タブから勤務先名と色を登録します。")),
                    .init(systemImage: "line.3.horizontal.decrease.circle", title: PayrollLocalization.text("絞り込みが連動"), detail: PayrollLocalization.text("ダッシュボード、記録、テンプレートで同じ支給元に絞れます。")),
                ]
            ),
            OnboardingPage(
                title: PayrollLocalization.text("記録はすばやく入力"),
                subtitle: PayrollLocalization.text("給与と賞与を分けて管理でき、明細写真からAI読み取りで下書きを作ることもできます。"),
                accent: Color(hex: "#2563EB"),
                hero: .capture,
                highlights: [
                    .init(systemImage: "plus.circle", title: PayrollLocalization.text("新規記録を追加"), detail: PayrollLocalization.text("記録タブ右上の追加ボタンから入力します。")),
                    .init(systemImage: "photo.badge.magnifyingglass", title: PayrollLocalization.text("写真から自動入力"), detail: PayrollLocalization.text("支給項目と控除項目を読み取って確認しながら保存できます。")),
                ]
            ),
            OnboardingPage(
                title: PayrollLocalization.text("テンプレートで毎月を時短"),
                subtitle: PayrollLocalization.text("固定の支給項目や控除項目はテンプレート化して、次回の記録作成を一気に短くします。"),
                accent: Color(hex: "#D97706"),
                hero: .template,
                highlights: [
                    .init(systemImage: "square.stack.3d.up", title: PayrollLocalization.text("ひな形を保存"), detail: PayrollLocalization.text("よく使う明細をテンプレートとして保持できます。")),
                    .init(systemImage: "arrow.triangle.branch", title: PayrollLocalization.text("記録へ展開"), detail: PayrollLocalization.text("テンプレートからそのまま新しい給与記録を作成できます。")),
                ]
            ),
            OnboardingPage(
                title: PayrollLocalization.text("振り返りと共有も自然に"),
                subtitle: PayrollLocalization.text("年間推移の確認、共有用のマスク設定、CloudKit 同期まで、毎日の運用をまとめて支えます。"),
                accent: Color(hex: "#E11D48"),
                hero: .insight,
                highlights: [
                    .init(systemImage: "chart.line.uptrend.xyaxis", title: PayrollLocalization.text("ダッシュボードで確認"), detail: PayrollLocalization.text("年ごとの手取り、控除率、月次推移を見返せます。")),
                    .init(systemImage: "lock.shield", title: PayrollLocalization.text("共有は情報を隠せる"), detail: PayrollLocalization.text("支給元名や金額、メモを非表示にして共有できます。")),
                ]
            ),
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = min(max(24, geometry.size.width * 0.07), 72)

            ZStack {
                AnimatedAuroraBackdrop(
                    primary: pages[currentPage].accent,
                    secondary: Color(hex: "#111827"),
                    tertiary: Color(hex: "#0B1220")
                )
                .overlay(Color.black.opacity(0.18))

                VStack(spacing: 24) {
                    onboardingHeader
                        .padding(.top, max(geometry.safeAreaInsets.top, 12) + 10)
                        .padding(.horizontal, horizontalPadding)

                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            OnboardingPageView(
                                page: page,
                                isActive: currentPage == index,
                                availableWidth: geometry.size.width - horizontalPadding * 2
                            )
                            .padding(.horizontal, horizontalPadding)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    onboardingFooter
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, max(24, geometry.safeAreaInsets.bottom + 8))
                }
            }
            .ignoresSafeArea()
        }
    }

    private var onboardingHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? pages[index].accent : .white.opacity(0.18))
                        .frame(width: index == currentPage ? 34 : 10, height: 10)
                }
            }

            Spacer()

            Button {
                completeTour()
            } label: {
                Text("スキップ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var onboardingFooter: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                if currentPage > 0 {
                    Button {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                            currentPage -= 1
                        }
                    } label: {
                        Text("戻る")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if currentPage == pages.count - 1 {
                        completeTour()
                    } else {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                            currentPage += 1
                        }
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? finalButtonTitle : PayrollLocalization.text("次へ"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [pages[currentPage].accent, .white.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text("あとから設定タブの「使い方ツアー」からいつでも見直せます。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var finalButtonTitle: String {
        PayrollLocalization.text("ダッシュボードへ")
    }

    private func completeTour() {
        onComplete(.dashboard)
    }
}

private struct SplashLedgerMark: View {
    let isRevealed: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .rotationEffect(.degrees(isRevealed ? -12 : -24))
                .offset(x: -30, y: 14)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color(hex: "#0F766E").opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .rotationEffect(.degrees(isRevealed ? 10 : 20))
                .offset(x: 26, y: 18)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 78, height: 78)

                    Circle()
                        .stroke(Color(hex: "#0F766E").opacity(0.24), lineWidth: 10)
                        .frame(width: 78, height: 78)

                    Image(systemName: "yensign")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "#0F766E"))
                }
                .shadow(color: .black.opacity(0.18), radius: 24, y: 10)

                VStack(spacing: 9) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(index == 0 ? 0.92 : 0.4))
                            .frame(width: index == 0 ? 108 : 84 - CGFloat(index) * 10, height: 12)
                    }
                }
            }
            .scaleEffect(isRevealed ? 1 : 0.84)
            .opacity(isRevealed ? 1 : 0)
        }
    }
}

private struct SplashProgressBar: View {
    let isAnimating: Bool

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.12))
            .frame(height: 10)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#A7F3D0"),
                                .white,
                                Color(hex: "#BFDBFE"),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: isAnimating ? 210 : 56, height: 10)
                    .shadow(color: .white.opacity(0.28), radius: 14)
            }
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    let availableWidth: CGFloat

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            OnboardingHeroView(page: page, isActive: isActive)
                .frame(height: min(availableWidth * 0.56, 310))

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                ForEach(page.highlights) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: item.systemImage)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(page.accent)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text(item.detail)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(18)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingHeroView: View {
    let page: OnboardingPage
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )

            switch page.hero {
            case .source:
                SourceHeroIllustration(accent: page.accent, isActive: isActive)
            case .capture:
                CaptureHeroIllustration(accent: page.accent, isActive: isActive)
            case .template:
                TemplateHeroIllustration(accent: page.accent, isActive: isActive)
            case .insight:
                InsightHeroIllustration(accent: page.accent, isActive: isActive)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 32, y: 18)
    }
}

private struct SourceHeroIllustration: View {
    let accent: Color
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 210, height: 210)
                    .blur(radius: 14)
                    .offset(x: sin(t * 0.8) * 18, y: cos(t * 0.7) * 14)

                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        SmallSourceCard(name: PayrollLocalization.text("A社"), accent: accent, isPrimary: true)
                            .offset(y: isActive ? sin(t * 1.8) * 6 : 0)

                        SmallSourceCard(name: PayrollLocalization.text("副業"), accent: Color(hex: "#F59E0B"), isPrimary: false)
                            .offset(y: isActive ? cos(t * 1.6) * 7 : 0)
                    }

                    HStack(spacing: 16) {
                        FilterChip(title: PayrollLocalization.text("すべて"), isSelected: false, accent: accent)
                        FilterChip(title: PayrollLocalization.text("A社"), isSelected: true, accent: accent)
                        FilterChip(title: PayrollLocalization.text("副業"), isSelected: false, accent: accent)
                    }
                }
                .padding(26)
            }
        }
    }
}

private struct CaptureHeroIllustration: View {
    let accent: Color
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let scanProgress = CGFloat((sin(t * 2.2) + 1) * 0.5)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .frame(width: 250, height: 190)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white.opacity(index == 0 ? 0.92 : 0.35))
                            .frame(width: index == 2 ? 150 : 196 - CGFloat(index) * 10, height: 10)
                    }
                }
                .offset(y: -18)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0), accent.opacity(0.5), accent.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 214, height: 18)
                    .offset(y: -50 + scanProgress * 100)
                    .blur(radius: 2)

                Image(systemName: "viewfinder")
                    .font(.system(size: 170, weight: .thin))
                    .foregroundStyle(.white.opacity(0.7))
                    .offset(y: isActive ? sin(t * 1.1) * 4 : 0)
            }
        }
    }
}

private struct TemplateHeroIllustration: View {
    let accent: Color
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                VStack(spacing: 14) {
                    TemplateCard(accent: accent, title: PayrollLocalization.text("月給テンプレート"), subtitle: PayrollLocalization.text("支給 2件 / 控除 1件"))
                        .rotationEffect(.degrees(isActive ? sin(t * 1.0) * 3 : 0))

                    Image(systemName: "arrow.down")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))

                    RecordCard(accent: accent)
                        .rotationEffect(.degrees(isActive ? cos(t * 1.2) * 2 : 0))
                }
                .padding(24)
            }
        }
    }
}

private struct InsightHeroIllustration: View {
    let accent: Color
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let bars = makeBars(at: t)

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("年間手取り")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.74))

                    Text("¥4,980,000")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(bars) { bar in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(bar.index.isMultiple(of: 2) ? accent : .white.opacity(0.34))
                                .frame(width: 18, height: bar.height)
                        }
                    }
                }
                .padding(22)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 16) {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 92, height: 92)
                        .overlay {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    HStack(spacing: 10) {
                        Circle().fill(.green).frame(width: 10, height: 10)
                        Text("同期準備 OK")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
            }
            .padding(24)
        }
    }

    private func makeBars(at time: TimeInterval) -> [InsightBar] {
        (0..<6).map { index in
            let baseHeight = CGFloat(44 + index * 14)
            let animatedOffset = isActive ? CGFloat(sin(time * 1.3 + Double(index)) * 10) : 0
            return InsightBar(index: index, height: baseHeight + animatedOffset)
        }
    }
}

private struct InsightBar: Identifiable {
    let index: Int
    let height: CGFloat

    var id: Int { index }
}

private struct SmallSourceCard: View {
    let name: String
    let accent: Color
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)

                Spacer()

                if isPrimary {
                    Text("表示中")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                }
            }

            Text(name)
                .font(.headline)
                .foregroundStyle(.white)

            Text("記録 12件")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(18)
        .frame(width: 144)
        .background(.white.opacity(isPrimary ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let accent: Color

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? .white : .white.opacity(0.78))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? accent : .white.opacity(0.08), in: Capsule())
    }
}

private struct TemplateCard: View {
    let accent: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Image(systemName: "square.stack.3d.up.fill")
                .font(.title2)
                .foregroundStyle(accent)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct RecordCard: View {
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("2026年4月 給与")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("¥450,000")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                Label("支給 2件", systemImage: "plus.circle")
                Label("控除 1件", systemImage: "minus.circle")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.72))
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.4), .white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

private struct AnimatedAuroraBackdrop: View {
    let primary: Color
    let secondary: Color
    let tertiary: Color

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    LinearGradient(
                        colors: [
                            tertiary,
                            Color(hex: "#0B1120"),
                            Color(hex: "#07111B"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(primary.opacity(0.44))
                        .frame(width: geometry.size.width * 0.72)
                        .blur(radius: 60)
                        .offset(
                            x: cos(t * 0.48) * geometry.size.width * 0.18 - geometry.size.width * 0.12,
                            y: sin(t * 0.36) * geometry.size.height * 0.12 - geometry.size.height * 0.18
                        )

                    Circle()
                        .fill(secondary.opacity(0.32))
                        .frame(width: geometry.size.width * 0.58)
                        .blur(radius: 56)
                        .offset(
                            x: sin(t * 0.34) * geometry.size.width * 0.16 + geometry.size.width * 0.18,
                            y: cos(t * 0.42) * geometry.size.height * 0.14 + geometry.size.height * 0.2
                        )

                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: geometry.size.width * 0.34)
                        .blur(radius: 46)
                        .offset(
                            x: cos(t * 0.72) * geometry.size.width * 0.12,
                            y: sin(t * 0.64) * geometry.size.height * 0.18
                        )

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.04), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .rotationEffect(.degrees(-18))
                        .scaleEffect(1.4)
                }
            }
        }
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let accent: Color
    let hero: OnboardingHeroStyle
    let highlights: [OnboardingHighlight]
}

private struct OnboardingHighlight: Identifiable {
    let id = UUID()
    let systemImage: String
    let title: String
    let detail: String
}

private enum OnboardingHeroStyle {
    case source
    case capture
    case template
    case insight
}

#Preview("Splash") {
    LaunchSplashView()
}

#Preview("Onboarding") {
    OnboardingTourView(onComplete: { _ in })
}
