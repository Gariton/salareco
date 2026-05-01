import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct PayrollScreenBackground: View {
    let accent: Color

    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                accent.opacity(0.10),
                Color(.systemBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct PayrollSurfaceCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let tint: Color
    let content: Content

    init(
        cornerRadius: CGFloat = 24,
        padding: CGFloat = 18,
        tint: Color = Color(hex: "#0F766E"),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: tint.opacity(0.12), radius: 22, x: 0, y: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.36), lineWidth: 1)
            }
    }
}

struct PayrollIconBadge: View {
    let systemImage: String
    let tint: Color
    let size: CGFloat

    init(systemImage: String, tint: Color, size: CGFloat = 40) {
        self.systemImage = systemImage
        self.tint = tint
        self.size = size
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.35, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.35, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            }
    }
}

struct PayrollInfoPill: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .imageScale(.small)
                .accessibilityHidden(true)

            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SourceFilterBar: View {
    let sources: [IncomeSource]
    @Binding var selectedSourceID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                SourceChip(
                    title: PayrollLocalization.text("すべて"),
                    color: .secondary,
                    isSelected: selectedSourceID == nil
                ) {
                    selectedSourceID = nil
                }

                ForEach(sources) { source in
                    SourceChip(
                        title: source.name,
                        color: Color(hex: source.accentHex),
                        isSelected: selectedSourceID == source.id
                    ) {
                        selectedSourceID = source.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }
}

private struct SourceChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? .white.opacity(0.28) : color.opacity(0.18))
                        .frame(width: 14, height: 14)

                    Circle()
                        .fill(isSelected ? .white : color)
                        .frame(width: isSelected ? 6 : 8, height: isSelected ? 6 : 8)
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [color, color.opacity(0.76)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(.regularMaterial)
                    )
            )
            .overlay {
                Capsule()
                    .stroke(isSelected ? .white.opacity(0.22) : color.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: isSelected ? color.opacity(0.22) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let caption: String
    let iconName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PayrollIconBadge(systemImage: iconName, tint: tint)
                Spacer()
            }

            Text(PayrollLocalization.text(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.title3.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(PayrollLocalization.text(caption))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 148, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.14),
                            Color(.secondarySystemBackground),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: tint.opacity(0.10), radius: 18, x: 0, y: 10)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.34), lineWidth: 1)
        }
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String?
    let actionSystemImage: String?
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        actionSystemImage: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.actionSystemImage = actionSystemImage
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            PayrollIconBadge(systemImage: systemImage, tint: Color(hex: "#0F766E"))

            Text(PayrollLocalization.text(title))
                .font(.headline.weight(.bold))

            Text(PayrollLocalization.text(message))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle,
               let actionSystemImage,
               let action {
                Button(action: action) {
                    Label(PayrollLocalization.text(actionTitle), systemImage: actionSystemImage)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.34), lineWidth: 1)
        }
        .padding(.horizontal)
    }
}

struct TrendBarView: View {
    let label: String
    let value: Double
    let maxValue: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(value.currencyText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.gradient)
                    .frame(
                        width: max(24, proxy.size.width * CGFloat(value / max(maxValue, 1))),
                        height: 12
                    )
            }
            .frame(height: 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
        }
    }
}

struct ShareQRCodeCard: View {
    let urlString: String
    let accentColor: Color
    let caption: String

    var body: some View {
        VStack(spacing: 16) {
            if let qrImage = makeQRCodeImage(from: urlString) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.white)
                    )
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 240)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 40, weight: .medium))
                            Text("QRコードを生成できませんでした")
                                .font(.footnote)
                        }
                        .foregroundStyle(.secondary)
                    }
            }

            Text(PayrollLocalization.text(caption))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(accentColor.opacity(0.12))
        )
    }

    private func makeQRCodeImage(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
            let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

extension Color {
    init(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&value)

        let red, green, blue: UInt64
        switch hexString.count {
        case 6:
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
        default:
            red = 15
            green = 118
            blue = 110
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}
