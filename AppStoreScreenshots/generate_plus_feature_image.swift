import AppKit
import Foundation

private let canvasWidth: CGFloat = 1284
private let canvasHeight: CGFloat = 2778
private let outputSize = CGSize(width: canvasWidth, height: canvasHeight)

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let outputDirectory = root.appendingPathComponent("AppStoreScreenshots/iPhone_6_5_1284x2778", isDirectory: true)
private let iconPath = root.appendingPathComponent("PayrollLedger/PayrollLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")

private struct Feature {
    let title: String
    let detail: String
    let symbol: String
    let color: NSColor
}

private let features: [Feature] = [
    Feature(title: "支給元を無制限に登録", detail: "副業や転職前後の給与もまとめて管理", symbol: "building.2.crop.circle", color: NSColor(hex: 0x2563EB)),
    Feature(title: "テンプレートを無制限に保存", detail: "給与・賞与のひな形を何件でも作成", symbol: "square.stack.3d.up", color: NSColor(hex: 0x7C3AED)),
    Feature(title: "給与明細の写真から自動入力", detail: "支給項目と控除項目をOCRで読み取り", symbol: "photo.badge.magnifyingglass", color: NSColor(hex: 0x0EA5E9)),
    Feature(title: "勤務時間項目を無制限に管理", detail: "時間外・深夜・休日なども細かく記録", symbol: "clock.badge.checkmark", color: NSColor(hex: 0x10B981)),
    Feature(title: "給与記録をCSVで書き出し", detail: "表計算やバックアップに活用", symbol: "tablecells.badge.ellipsis", color: NSColor(hex: 0xF97316)),
    Feature(title: "アプリ内広告を非表示", detail: "記録と確認に集中できる画面へ", symbol: "rectangle.slash", color: NSColor(hex: 0x14B8A6)),
    Feature(title: "今後のPlus機能も利用可能", detail: "追加予定の便利機能にも対応", symbol: "sparkles", color: NSColor(hex: 0xEAB308))
]

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xff) / 255
        let green = CGFloat((hex >> 8) & 0xff) / 255
        let blue = CGFloat(hex & 0xff) / 255
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
}

private func rectTop(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: canvasHeight - y - height, width: width, height: height)
}

private func font(_ size: CGFloat, weight: NSFont.Weight) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

private func drawText(
    _ text: String,
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    font: NSFont,
    color: NSColor,
    lineSpacing: CGFloat = 0,
    alignment: NSTextAlignment = .left
) {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.alignment = alignment
    style.lineSpacing = lineSpacing
    style.minimumLineHeight = font.pointSize * 1.08
    style.maximumLineHeight = font.pointSize * 1.14
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style
    ]
    let measured = (text as NSString).boundingRect(
        with: CGSize(width: width, height: 900),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attributes
    )
    let height = ceil(measured.height) + 8
    (text as NSString).draw(
        with: rectTop(x, y, width, height),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attributes
    )
}

private func fillRoundedRect(
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat,
    radius: CGFloat,
    color: NSColor,
    shadowColor: NSColor? = nil,
    shadowBlur: CGFloat = 0,
    shadowOffset: CGSize = .zero
) {
    NSGraphicsContext.saveGraphicsState()
    if let shadowColor {
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowBlurRadius = shadowBlur
        shadow.shadowOffset = shadowOffset
        shadow.set()
    }
    color.setFill()
    NSBezierPath(roundedRect: rectTop(x, y, width, height), xRadius: radius, yRadius: radius).fill()
    NSGraphicsContext.restoreGraphicsState()
}

private func fillEllipse(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rectTop(x, y, width, height)).fill()
}

private func drawSymbol(_ name: String, x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor) {
    let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .bold)
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
    image?.isTemplate = true

    NSGraphicsContext.saveGraphicsState()
    color.set()
    image?.draw(in: rectTop(x, y, size, size), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

private func drawAppBadge() {
    guard let icon = NSImage(contentsOf: iconPath) else { return }
    let iconRect = rectTop(92, 84, 94, 94)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: iconRect, xRadius: 24, yRadius: 24).addClip()
    icon.draw(in: iconRect, from: NSRect(origin: .zero, size: icon.size), operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    drawText("サラレコ", x: 212, y: 100, width: 340, font: font(36, weight: .bold), color: NSColor(hex: 0x111827))
    drawText("給与をかんたん記録", x: 212, y: 143, width: 420, font: font(25, weight: .semibold), color: NSColor(hex: 0x667085))
}

private func drawCheckMark(x: CGFloat, y: CGFloat) {
    fillRoundedRect(x: x, y: y, width: 46, height: 46, radius: 23, color: NSColor(hex: 0x10B981))
    drawSymbol("checkmark", x: x + 11, y: y + 11, size: 24, color: .white)
}

private func drawMiniPaywallCard() {
    let x: CGFloat = 92
    let y: CGFloat = 548
    let width: CGFloat = 1100
    let height: CGFloat = 580

    fillRoundedRect(
        x: x,
        y: y,
        width: width,
        height: height,
        radius: 64,
        color: NSColor(hex: 0x0F766E),
        shadowColor: NSColor(hex: 0x0F766E).withAlphaComponent(0.26),
        shadowBlur: 72,
        shadowOffset: CGSize(width: 0, height: -28)
    )

    fillEllipse(x: x + 760, y: y - 80, width: 420, height: 420, color: NSColor.white.withAlphaComponent(0.10))
    fillEllipse(x: x - 140, y: y + 310, width: 360, height: 360, color: NSColor(hex: 0x14B8A6).withAlphaComponent(0.28))
    drawSymbol("sparkles", x: x + 854, y: y + 76, size: 138, color: NSColor.white.withAlphaComponent(0.30))

    fillRoundedRect(x: x + 52, y: y + 50, width: 238, height: 64, radius: 32, color: NSColor.white.withAlphaComponent(0.18))
    drawText("買い切りPlus", x: x + 86, y: y + 64, width: 190, font: font(28, weight: .bold), color: .white)

    drawText("無料プランの制限を\nまとめて解放", x: x + 52, y: y + 144, width: 720, font: font(70, weight: .heavy), color: .white, lineSpacing: 4)
    drawText("給与管理をもっと速く、もっと見やすく。複数勤務先からCSV書き出しまで対応します。", x: x + 56, y: y + 324, width: 720, font: font(31, weight: .semibold), color: NSColor.white.withAlphaComponent(0.80), lineSpacing: 4)

    let statsY = y + 438
    let stats = [("支給元", "無制限"), ("テンプレート", "無制限"), ("広告", "非表示")]
    for (index, stat) in stats.enumerated() {
        let sx = x + 52 + CGFloat(index) * 324
        fillRoundedRect(x: sx, y: statsY, width: 286, height: 94, radius: 28, color: NSColor.white.withAlphaComponent(0.16))
        drawText(stat.0, x: sx + 26, y: statsY + 16, width: 230, font: font(23, weight: .bold), color: NSColor.white.withAlphaComponent(0.72))
        drawText(stat.1, x: sx + 26, y: statsY + 46, width: 230, font: font(31, weight: .heavy), color: .white)
    }
}

private func drawFeatureCard(_ feature: Feature, index: Int) {
    let cardX: CGFloat = 92
    let cardY = CGFloat(1192 + index * 186)
    let cardWidth: CGFloat = 1100
    let cardHeight: CGFloat = 154

    fillRoundedRect(
        x: cardX,
        y: cardY,
        width: cardWidth,
        height: cardHeight,
        radius: 34,
        color: NSColor.white.withAlphaComponent(0.90),
        shadowColor: NSColor(hex: 0x1E3A8A).withAlphaComponent(0.10),
        shadowBlur: 32,
        shadowOffset: CGSize(width: 0, height: -10)
    )

    fillRoundedRect(x: cardX + 30, y: cardY + 33, width: 88, height: 88, radius: 26, color: feature.color.withAlphaComponent(0.13))
    drawSymbol(feature.symbol, x: cardX + 52, y: cardY + 55, size: 44, color: feature.color)

    drawText(feature.title, x: cardX + 148, y: cardY + 28, width: 740, font: font(32, weight: .heavy), color: NSColor(hex: 0x0B1220))
    drawText(feature.detail, x: cardX + 148, y: cardY + 76, width: 760, font: font(25, weight: .semibold), color: NSColor(hex: 0x667085))

    drawCheckMark(x: cardX + cardWidth - 88, y: cardY + 54)
}

private func drawBottomCTA() {
    fillRoundedRect(
        x: 92,
        y: 2506,
        width: 1100,
        height: 150,
        radius: 44,
        color: NSColor.white.withAlphaComponent(0.82),
        shadowColor: NSColor(hex: 0x0F172A).withAlphaComponent(0.10),
        shadowBlur: 32,
        shadowOffset: CGSize(width: 0, height: -8)
    )
    drawSymbol("sparkles", x: 142, y: 2550, size: 50, color: NSColor(hex: 0x0F766E))
    drawText("Plusで、毎月の給与管理をもっと快適に", x: 216, y: 2534, width: 720, font: font(34, weight: .heavy), color: NSColor(hex: 0x0B1220))
    drawText("購入後は対象機能がアプリ内で解放されます", x: 216, y: 2584, width: 760, font: font(25, weight: .semibold), color: NSColor(hex: 0x667085))
}

private func drawBackground() {
    let gradient = NSGradient(colors: [
        NSColor(hex: 0xF8FBFF),
        NSColor(hex: 0xEAF7F4),
        NSColor(hex: 0xF7FBFF)
    ])!
    gradient.draw(in: NSRect(origin: .zero, size: outputSize), angle: 270)

    fillEllipse(x: 730, y: -150, width: 660, height: 660, color: NSColor(hex: 0xD7E7FF).withAlphaComponent(0.78))
    fillEllipse(x: -190, y: 440, width: 650, height: 650, color: NSColor(hex: 0xBFF3E8).withAlphaComponent(0.55))
    fillEllipse(x: 934, y: 2090, width: 500, height: 500, color: NSColor(hex: 0xD7E7FF).withAlphaComponent(0.62))

    fillRoundedRect(x: 88, y: 2338, width: 1108, height: 374, radius: 92, color: NSColor.white.withAlphaComponent(0.34))
}

private func drawPlusImage() throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasWidth),
        pixelsHigh: Int(canvasHeight),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = outputSize

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    drawBackground()
    drawAppBadge()

    fillRoundedRect(x: 92, y: 226, width: 256, height: 62, radius: 31, color: NSColor(hex: 0x0F766E).withAlphaComponent(0.13))
    drawText("Plusプラン", x: 122, y: 239, width: 196, font: font(30, weight: .bold), color: NSColor(hex: 0x0F766E))
    drawText("購入で解放される\n便利機能", x: 88, y: 326, width: 1030, font: font(86, weight: .heavy), color: NSColor(hex: 0x0B1220), lineSpacing: 6)

    fillRoundedRect(x: 980, y: 116, width: 170, height: 44, radius: 22, color: NSColor(hex: 0x2563EB).withAlphaComponent(0.16))
    fillRoundedRect(x: 1030, y: 184, width: 92, height: 44, radius: 22, color: NSColor(hex: 0x14B8A6).withAlphaComponent(0.20))
    fillRoundedRect(x: 910, y: 184, width: 86, height: 44, radius: 22, color: NSColor(hex: 0x111827).withAlphaComponent(0.08))

    drawMiniPaywallCard()

    for (index, feature) in features.enumerated() {
        drawFeatureCard(feature, index: index)
    }

    drawBottomCTA()

    NSGraphicsContext.current = nil
    NSGraphicsContext.restoreGraphicsState()

    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "PlusFeatureImage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG data"])
    }
    let pngURL = outputDirectory.appendingPathComponent("05-plus-features.png")
    try png.write(to: pngURL)
    print(pngURL.path)

    guard let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.96]) else {
        throw NSError(domain: "PlusFeatureImage", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create JPEG data"])
    }
    let jpgURL = outputDirectory.appendingPathComponent("05-plus-features.jpg")
    try jpg.write(to: jpgURL)
    print(jpgURL.path)
}

try drawPlusImage()
