import AppKit
import Foundation

private let canvasWidth: CGFloat = 1284
private let canvasHeight: CGFloat = 2778
private let outputSize = CGSize(width: canvasWidth, height: canvasHeight)

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let outputDirectory = root.appendingPathComponent("AppStoreScreenshots/iPhone_6_5_1284x2778", isDirectory: true)
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

private let slides: [Slide] = [
    Slide(
        input: "/Users/j.ooyama/Downloads/0x0ss.png",
        output: "01-dashboard.png",
        badge: "年間サマリー",
        headline: "手取りも控除も\nひと目で把握",
        subhead: "給与・賞与・控除を年ごとにまとめて確認",
        accent: NSColor(hex: 0x2563EB),
        accent2: NSColor(hex: 0x10B981)
    ),
    Slide(
        input: "/Users/j.ooyama/Downloads/0x0ss-2.png",
        output: "02-records.png",
        badge: "給与記録",
        headline: "毎月の給与を\nすっきり整理",
        subhead: "支給額・控除額・手取りを月別に見返せる",
        accent: NSColor(hex: 0x2563EB),
        accent2: NSColor(hex: 0xF97316)
    ),
    Slide(
        input: "/Users/j.ooyama/Downloads/0x0ss-3.png",
        output: "03-templates.png",
        badge: "テンプレート",
        headline: "ひな形から\nすばやく入力",
        subhead: "毎月の明細をテンプレートで効率よく登録",
        accent: NSColor(hex: 0x2563EB),
        accent2: NSColor(hex: 0x8B5CF6)
    ),
    Slide(
        input: "/Users/j.ooyama/Downloads/0x0ss-4.png",
        output: "04-detail.png",
        badge: "明細管理",
        headline: "内訳まで\nしっかり保存",
        subhead: "支給項目・控除項目を残してあとから確認",
        accent: NSColor(hex: 0x2563EB),
        accent2: NSColor(hex: 0x14B8A6)
    )
]

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xff) / 255
        let green = CGFloat((hex >> 8) & 0xff) / 255
        let blue = CGFloat(hex & 0xff) / 255
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
}

private extension NSBezierPath {
    static func rounded(topLeftX x: CGFloat, topY y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rectTop(x, y, width, height), xRadius: radius, yRadius: radius)
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
    style.maximumLineHeight = font.pointSize * 1.12
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
    NSBezierPath.rounded(topLeftX: x, topY: y, width: width, height: height, radius: radius).fill()
    NSGraphicsContext.restoreGraphicsState()
}

private func fillEllipse(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rectTop(x, y, width, height)).fill()
}

private func strokeRoundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat, color: NSColor, lineWidth: CGFloat) {
    color.setStroke()
    let path = NSBezierPath.rounded(topLeftX: x, topY: y, width: width, height: height, radius: radius)
    path.lineWidth = lineWidth
    path.stroke()
}

private func drawImageClipped(_ image: NSImage, in rect: NSRect, radius: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1)
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

private func drawBackground(accent: NSColor, accent2: NSColor) {
    let gradient = NSGradient(colors: [
        NSColor(hex: 0xF8FBFF),
        NSColor(hex: 0xECF4FF),
        NSColor(hex: 0xF8FBFF)
    ])!
    gradient.draw(in: NSRect(origin: .zero, size: outputSize), angle: 270)

    fillEllipse(x: 750, y: -150, width: 640, height: 640, color: accent.withAlphaComponent(0.10))
    fillEllipse(x: -170, y: 520, width: 650, height: 650, color: accent2.withAlphaComponent(0.12))
    fillEllipse(x: 905, y: 2060, width: 520, height: 520, color: accent.withAlphaComponent(0.08))

    fillRoundedRect(x: 84, y: 2300, width: 1122, height: 320, radius: 92, color: NSColor.white.withAlphaComponent(0.38))
}

private func drawDecorativeBars(accent: NSColor, accent2: NSColor) {
    fillRoundedRect(x: 984, y: 116, width: 170, height: 44, radius: 22, color: accent.withAlphaComponent(0.16))
    fillRoundedRect(x: 1034, y: 184, width: 92, height: 44, radius: 22, color: accent2.withAlphaComponent(0.20))
    fillRoundedRect(x: 914, y: 184, width: 86, height: 44, radius: 22, color: NSColor(hex: 0x111827).withAlphaComponent(0.08))
}

private func drawSlide(_ slide: Slide) throws {
    guard let screenshot = NSImage(contentsOfFile: slide.input) else {
        throw NSError(domain: "AppStoreScreenshots", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing screenshot: \(slide.input)"])
    }

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

    drawBackground(accent: slide.accent, accent2: slide.accent2)
    drawDecorativeBars(accent: slide.accent, accent2: slide.accent2)
    drawAppBadge()

    fillRoundedRect(x: 92, y: 226, width: 280, height: 62, radius: 31, color: slide.accent.withAlphaComponent(0.13))
    drawText(slide.badge, x: 122, y: 239, width: 220, font: font(30, weight: .bold), color: slide.accent)

    drawText(slide.headline, x: 88, y: 326, width: 1030, font: font(86, weight: .heavy), color: NSColor(hex: 0x0B1220), lineSpacing: 6)
    drawText(slide.subhead, x: 92, y: 543, width: 1050, font: font(34, weight: .semibold), color: NSColor(hex: 0x556170))

    let screenWidth: CGFloat = 930
    let screenHeight = screenWidth * screenshot.size.height / screenshot.size.width
    let screenX = (canvasWidth - screenWidth) / 2
    let screenY: CGFloat = 660
    let framePadding: CGFloat = 18
    let frameX = screenX - framePadding
    let frameY = screenY - framePadding
    let frameWidth = screenWidth + framePadding * 2
    let frameHeight = screenHeight + framePadding * 2

    fillRoundedRect(
        x: frameX,
        y: frameY,
        width: frameWidth,
        height: frameHeight,
        radius: 92,
        color: NSColor.white.withAlphaComponent(0.95),
        shadowColor: NSColor(hex: 0x1E3A8A).withAlphaComponent(0.24),
        shadowBlur: 78,
        shadowOffset: CGSize(width: 0, height: -26)
    )
    strokeRoundedRect(x: frameX, y: frameY, width: frameWidth, height: frameHeight, radius: 92, color: NSColor.white.withAlphaComponent(0.85), lineWidth: 2)
    drawImageClipped(screenshot, in: rectTop(screenX, screenY, screenWidth, screenHeight), radius: 72)
    strokeRoundedRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight, radius: 72, color: NSColor(hex: 0xCBD5E1).withAlphaComponent(0.50), lineWidth: 1)

    NSGraphicsContext.current = nil
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppStoreScreenshots", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG data"])
    }
    let destination = outputDirectory.appendingPathComponent(slide.output)
    try png.write(to: destination)
    print(destination.path)

    if let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.96]) {
        let jpgDestination = outputDirectory.appendingPathComponent(slide.output.replacingOccurrences(of: ".png", with: ".jpg"))
        try jpg.write(to: jpgDestination)
        print(jpgDestination.path)
    }
}

private func makeContactSheet() throws {
    let thumbWidth: CGFloat = 300
    let thumbHeight = thumbWidth * canvasHeight / canvasWidth
    let padding: CGFloat = 36
    let sheetWidth = padding * 3 + thumbWidth * 2
    let sheetHeight = padding * 3 + thumbHeight * 2

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

    for (index, slide) in slides.enumerated() {
        guard let image = NSImage(contentsOf: outputDirectory.appendingPathComponent(slide.output)) else { continue }
        let column = index % 2
        let row = index / 2
        let x = padding + CGFloat(column) * (thumbWidth + padding)
        let y = padding + CGFloat(row) * (thumbHeight + padding)
        let rect = rectTop(in: sheetHeight, x, y, thumbWidth, thumbHeight)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(hex: 0x0F172A).withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 20
        shadow.shadowOffset = CGSize(width: 0, height: -8)
        shadow.set()
        image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.current = nil
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try png.write(to: outputDirectory.appendingPathComponent("_preview_contact_sheet.png"))
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for slide in slides {
    try drawSlide(slide)
}
try makeContactSheet()
print(outputDirectory.appendingPathComponent("_preview_contact_sheet.png").path)
