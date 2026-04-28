import AppKit
import Foundation

private let canvasWidth: CGFloat = 2048
private let canvasHeight: CGFloat = 2732
private let outputSize = CGSize(width: canvasWidth, height: canvasHeight)

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let outputDirectory = root.appendingPathComponent("AppStoreScreenshots/iPad_13_2048x2732", isDirectory: true)
private let iconPath = root.appendingPathComponent("PayrollLedger/PayrollLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")

private struct Slide {
    let input: String
    let output: String
    let badge: String
    let headline: String
    let subhead: String
    let accent: NSColor
    let accent2: NSColor
}

private struct Feature {
    let title: String
    let detail: String
    let symbol: String
    let color: NSColor
}

private let slides: [Slide] = [
    Slide(
        input: "/Users/j.ooyama/Downloads/400x800bb.png",
        output: "01-ipad-dashboard",
        badge: "年間サマリー",
        headline: "iPadでも\n給与をひと目で",
        subhead: "大きな画面で手取り・控除・年次推移を確認",
        accent: NSColor(hex: 0x2563EB),
        accent2: NSColor(hex: 0x10B981)
    ),
    Slide(
        input: "/Users/j.ooyama/Downloads/400x800bb-2.png",
        output: "02-ipad-records",
        badge: "給与記録",
        headline: "毎月の給与を\n広い画面で整理",
        subhead: "支給額・控除額・手取りを月別に見返せる",
        accent: NSColor(hex: 0x2563EB),
        accent2: NSColor(hex: 0xF97316)
    ),
    Slide(
        input: "/Users/j.ooyama/Downloads/400x800bb-3.png",
        output: "03-ipad-templates",
        badge: "テンプレート",
        headline: "ひな形から\nすばやく入力",
        subhead: "毎月の明細をテンプレートで効率よく登録",
        accent: NSColor(hex: 0x2563EB),
        accent2: NSColor(hex: 0x8B5CF6)
    ),
    Slide(
        input: "/Users/j.ooyama/Downloads/400x800bb-4.png",
        output: "04-ipad-detail",
        badge: "明細管理",
        headline: "内訳まで\nしっかり保存",
        subhead: "支給項目・控除項目を一覧で確認",
        accent: NSColor(hex: 0x2563EB),
        accent2: NSColor(hex: 0x14B8A6)
    )
]

private let plusFeatures: [Feature] = [
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

private func rectTop(in height: CGFloat, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: height - y - h, width: width, height: h)
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
    style.maximumLineHeight = font.pointSize * 1.15

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style
    ]
    let measured = (text as NSString).boundingRect(
        with: CGSize(width: width, height: 1000),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attributes
    )
    let height = ceil(measured.height) + 10
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

private func strokeRoundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat, color: NSColor, lineWidth: CGFloat) {
    color.setStroke()
    let path = NSBezierPath(roundedRect: rectTop(x, y, width, height), xRadius: radius, yRadius: radius)
    path.lineWidth = lineWidth
    path.stroke()
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

private func drawImageClipped(_ image: NSImage, in rect: NSRect, radius: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

private func drawBackground(accent: NSColor, accent2: NSColor) {
    let gradient = NSGradient(colors: [
        NSColor(hex: 0xF8FBFF),
        NSColor(hex: 0xEDF5FF),
        NSColor(hex: 0xF8FBFF)
    ])!
    gradient.draw(in: NSRect(origin: .zero, size: outputSize), angle: 270)

    fillEllipse(x: 1250, y: -250, width: 980, height: 980, color: accent.withAlphaComponent(0.10))
    fillEllipse(x: -310, y: 420, width: 940, height: 940, color: accent2.withAlphaComponent(0.12))
    fillEllipse(x: 1390, y: 2060, width: 760, height: 760, color: accent.withAlphaComponent(0.08))
}

private func drawDecorativeBars(accent: NSColor, accent2: NSColor) {
    fillRoundedRect(x: 1580, y: 134, width: 276, height: 58, radius: 29, color: accent.withAlphaComponent(0.16))
    fillRoundedRect(x: 1662, y: 226, width: 146, height: 58, radius: 29, color: accent2.withAlphaComponent(0.20))
    fillRoundedRect(x: 1472, y: 226, width: 132, height: 58, radius: 29, color: NSColor(hex: 0x111827).withAlphaComponent(0.08))
}

private func drawAppBadge() {
    guard let icon = NSImage(contentsOf: iconPath) else { return }
    let iconRect = rectTop(144, 102, 126, 126)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: iconRect, xRadius: 30, yRadius: 30).addClip()
    icon.draw(in: iconRect, from: NSRect(origin: .zero, size: icon.size), operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    drawText("サラレコ", x: 304, y: 122, width: 420, font: font(46, weight: .bold), color: NSColor(hex: 0x111827))
    drawText("給与をかんたん記録", x: 304, y: 180, width: 560, font: font(31, weight: .semibold), color: NSColor(hex: 0x667085))
}

private func makeBitmap() -> NSBitmapImageRep {
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
    return rep
}

private func writeImage(_ rep: NSBitmapImageRep, basename: String) throws {
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "iPadAppStoreScreenshots", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG data"])
    }
    let pngURL = outputDirectory.appendingPathComponent("\(basename).png")
    try png.write(to: pngURL)
    print(pngURL.path)

    guard let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.96]) else {
        throw NSError(domain: "iPadAppStoreScreenshots", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create JPEG data"])
    }
    let jpgURL = outputDirectory.appendingPathComponent("\(basename).jpg")
    try jpg.write(to: jpgURL)
    print(jpgURL.path)
}

private func drawSlide(_ slide: Slide) throws {
    guard let screenshot = NSImage(contentsOfFile: slide.input) else {
        throw NSError(domain: "iPadAppStoreScreenshots", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing screenshot: \(slide.input)"])
    }

    let rep = makeBitmap()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    drawBackground(accent: slide.accent, accent2: slide.accent2)
    drawDecorativeBars(accent: slide.accent, accent2: slide.accent2)
    drawAppBadge()

    fillRoundedRect(x: 144, y: 308, width: 380, height: 78, radius: 39, color: slide.accent.withAlphaComponent(0.13))
    drawText(slide.badge, x: 186, y: 325, width: 300, font: font(38, weight: .bold), color: slide.accent)

    drawText(slide.headline, x: 144, y: 456, width: 1220, font: font(104, weight: .heavy), color: NSColor(hex: 0x0B1220), lineSpacing: 8)
    drawText(slide.subhead, x: 148, y: 718, width: 1280, font: font(42, weight: .semibold), color: NSColor(hex: 0x556170))

    let screenWidth: CGFloat = 1328
    let screenHeight = screenWidth * screenshot.size.height / screenshot.size.width
    let screenX = (canvasWidth - screenWidth) / 2
    let screenY: CGFloat = 880
    let framePadding: CGFloat = 26
    let frameX = screenX - framePadding
    let frameY = screenY - framePadding
    let frameWidth = screenWidth + framePadding * 2
    let frameHeight = screenHeight + framePadding * 2

    fillRoundedRect(
        x: frameX,
        y: frameY,
        width: frameWidth,
        height: frameHeight,
        radius: 88,
        color: NSColor.white.withAlphaComponent(0.96),
        shadowColor: NSColor(hex: 0x1E3A8A).withAlphaComponent(0.23),
        shadowBlur: 92,
        shadowOffset: CGSize(width: 0, height: -28)
    )
    strokeRoundedRect(x: frameX, y: frameY, width: frameWidth, height: frameHeight, radius: 88, color: NSColor.white.withAlphaComponent(0.88), lineWidth: 3)
    drawImageClipped(screenshot, in: rectTop(screenX, screenY, screenWidth, screenHeight), radius: 54)
    strokeRoundedRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight, radius: 54, color: NSColor(hex: 0xCBD5E1).withAlphaComponent(0.50), lineWidth: 1.5)

    NSGraphicsContext.current = nil
    NSGraphicsContext.restoreGraphicsState()

    try writeImage(rep, basename: slide.output)
}

private func drawCheckMark(x: CGFloat, y: CGFloat) {
    fillRoundedRect(x: x, y: y, width: 54, height: 54, radius: 27, color: NSColor(hex: 0x10B981))
    drawSymbol("checkmark", x: x + 13, y: y + 13, size: 28, color: .white)
}

private func drawPlusHeroCard() {
    let x: CGFloat = 144
    let y: CGFloat = 720
    let width: CGFloat = 1760
    let height: CGFloat = 520

    fillRoundedRect(
        x: x,
        y: y,
        width: width,
        height: height,
        radius: 70,
        color: NSColor(hex: 0x0F766E),
        shadowColor: NSColor(hex: 0x0F766E).withAlphaComponent(0.26),
        shadowBlur: 86,
        shadowOffset: CGSize(width: 0, height: -28)
    )

    fillEllipse(x: x + 1280, y: y - 160, width: 630, height: 630, color: NSColor.white.withAlphaComponent(0.10))
    fillEllipse(x: x - 190, y: y + 300, width: 500, height: 500, color: NSColor(hex: 0x14B8A6).withAlphaComponent(0.30))
    drawSymbol("sparkles", x: x + 1440, y: y + 108, size: 150, color: NSColor.white.withAlphaComponent(0.32))

    fillRoundedRect(x: x + 58, y: y + 52, width: 270, height: 72, radius: 36, color: NSColor.white.withAlphaComponent(0.18))
    drawText("買い切りPlus", x: x + 96, y: y + 68, width: 210, font: font(33, weight: .bold), color: .white)

    drawText("無料プランの制限を\nまとめて解放", x: x + 58, y: y + 154, width: 980, font: font(72, weight: .heavy), color: .white, lineSpacing: 6)
    drawText("複数勤務先からCSV書き出し、広告非表示まで対応します。", x: x + 62, y: y + 344, width: 940, font: font(36, weight: .semibold), color: NSColor.white.withAlphaComponent(0.80), lineSpacing: 4)

    let statY = y + 188
    let stats = [("支給元", "無制限"), ("テンプレート", "無制限"), ("広告", "非表示")]
    for (index, stat) in stats.enumerated() {
        let sx = x + 1070
        let sy = statY + CGFloat(index) * 98
        fillRoundedRect(x: sx, y: sy, width: 430, height: 74, radius: 24, color: NSColor.white.withAlphaComponent(0.16))
        drawText(stat.0, x: sx + 28, y: sy + 13, width: 180, font: font(25, weight: .bold), color: NSColor.white.withAlphaComponent(0.72))
        drawText(stat.1, x: sx + 210, y: sy + 12, width: 170, font: font(31, weight: .heavy), color: .white)
    }
}

private func drawPlusFeature(_ feature: Feature, index: Int) {
    let cardWidth: CGFloat = 848
    let cardHeight: CGFloat = 172
    let gapX: CGFloat = 64
    let gapY: CGFloat = 48
    let column = index % 2
    let row = index / 2
    let x = CGFloat(144 + column * Int(cardWidth + gapX))
    let y = CGFloat(1320 + row * Int(cardHeight + gapY))

    fillRoundedRect(
        x: x,
        y: y,
        width: cardWidth,
        height: cardHeight,
        radius: 36,
        color: NSColor.white.withAlphaComponent(0.91),
        shadowColor: NSColor(hex: 0x1E3A8A).withAlphaComponent(0.10),
        shadowBlur: 34,
        shadowOffset: CGSize(width: 0, height: -10)
    )

    fillRoundedRect(x: x + 28, y: y + 40, width: 92, height: 92, radius: 26, color: feature.color.withAlphaComponent(0.13))
    drawSymbol(feature.symbol, x: x + 52, y: y + 64, size: 44, color: feature.color)
    drawText(feature.title, x: x + 150, y: y + 32, width: 570, font: font(31, weight: .heavy), color: NSColor(hex: 0x0B1220))
    drawText(feature.detail, x: x + 150, y: y + 82, width: 560, font: font(24, weight: .semibold), color: NSColor(hex: 0x667085))
    drawCheckMark(x: x + cardWidth - 82, y: y + 59)
}

private func drawPlusBottomCTA() {
    fillRoundedRect(
        x: 144,
        y: 2394,
        width: 1760,
        height: 160,
        radius: 48,
        color: NSColor.white.withAlphaComponent(0.84),
        shadowColor: NSColor(hex: 0x0F172A).withAlphaComponent(0.10),
        shadowBlur: 34,
        shadowOffset: CGSize(width: 0, height: -8)
    )
    drawSymbol("sparkles", x: 204, y: 2444, size: 54, color: NSColor(hex: 0x0F766E))
    drawText("Plusで、毎月の給与管理をもっと快適に", x: 294, y: 2426, width: 1000, font: font(39, weight: .heavy), color: NSColor(hex: 0x0B1220))
    drawText("購入後は対象機能がアプリ内で解放されます", x: 294, y: 2486, width: 1040, font: font(27, weight: .semibold), color: NSColor(hex: 0x667085))
}

private func drawPlusImage() throws {
    let rep = makeBitmap()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    drawBackground(accent: NSColor(hex: 0x0F766E), accent2: NSColor(hex: 0x14B8A6))
    drawDecorativeBars(accent: NSColor(hex: 0x2563EB), accent2: NSColor(hex: 0x14B8A6))
    drawAppBadge()

    fillRoundedRect(x: 144, y: 308, width: 340, height: 78, radius: 39, color: NSColor(hex: 0x0F766E).withAlphaComponent(0.13))
    drawText("Plusプラン", x: 186, y: 325, width: 260, font: font(38, weight: .bold), color: NSColor(hex: 0x0F766E))
    drawText("購入で解放される\n便利機能", x: 144, y: 456, width: 1220, font: font(104, weight: .heavy), color: NSColor(hex: 0x0B1220), lineSpacing: 8)

    drawPlusHeroCard()
    for (index, feature) in plusFeatures.enumerated() {
        drawPlusFeature(feature, index: index)
    }
    drawPlusBottomCTA()

    NSGraphicsContext.current = nil
    NSGraphicsContext.restoreGraphicsState()

    try writeImage(rep, basename: "05-ipad-plus-features")
}

private func makeContactSheet() throws {
    let files = slides.map(\.output) + ["05-ipad-plus-features"]
    let thumbWidth: CGFloat = 260
    let thumbHeight = thumbWidth * canvasHeight / canvasWidth
    let padding: CGFloat = 28
    let columns = 3
    let rows = 2
    let sheetWidth = padding * CGFloat(columns + 1) + thumbWidth * CGFloat(columns)
    let sheetHeight = padding * CGFloat(rows + 1) + thumbHeight * CGFloat(rows)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(sheetWidth),
        pixelsHigh: Int(sheetHeight),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = CGSize(width: sheetWidth, height: sheetHeight)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor(hex: 0xEAF1FF).setFill()
    NSRect(origin: .zero, size: rep.size).fill()

    for (index, basename) in files.enumerated() {
        guard let image = NSImage(contentsOf: outputDirectory.appendingPathComponent("\(basename).jpg")) else { continue }
        let column = index % columns
        let row = index / columns
        let x = padding + CGFloat(column) * (thumbWidth + padding)
        let y = padding + CGFloat(row) * (thumbHeight + padding)
        image.draw(in: rectTop(in: sheetHeight, x, y, thumbWidth, thumbHeight), from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.current = nil
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    let previewURL = outputDirectory.appendingPathComponent("_preview_contact_sheet.png")
    try png.write(to: previewURL)
    print(previewURL.path)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for slide in slides {
    try drawSlide(slide)
}
try drawPlusImage()
try makeContactSheet()
