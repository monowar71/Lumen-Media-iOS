import SwiftUI

public enum LumenColors {
    /// Brand palette — aligned with docs/brand/lumen-mark.svg
    public static let bg = Color(red: 0x0b / 255, green: 0x1f / 255, blue: 0x1a / 255)
    public static let surface = Color(red: 0x12 / 255, green: 0x2a / 255, blue: 0x23 / 255)
    public static let surface2 = Color(red: 0x1a / 255, green: 0x38 / 255, blue: 0x30 / 255)
    public static let surface3 = Color(red: 0x22 / 255, green: 0x48 / 255, blue: 0x40 / 255)
    public static let border = Color(red: 0x2a / 255, green: 0x55 / 255, blue: 0x4a / 255)
    public static let muted = Color(red: 0x8a / 255, green: 0xa3 / 255, blue: 0x99 / 255)
    public static let text = Color(red: 0xe7 / 255, green: 0xf6 / 255, blue: 0xf0 / 255)
    public static let accent = Color(red: 0x3e / 255, green: 0xcf / 255, blue: 0x9a / 255)
    public static let accentHover = Color(red: 0x5f / 255, green: 0xe0 / 255, blue: 0xb0 / 255)
    public static let onAccent = Color(red: 0x0b / 255, green: 0x1f / 255, blue: 0x1a / 255)
}

public enum LumenLayout {
    /// Adaptive poster columns for iPhone / iPad widths.
    public static func posterColumns(for width: CGFloat) -> [GridItem] {
        let count: Int
        switch width {
        case ..<400: count = 3
        case ..<700: count = 4
        case ..<1000: count = 5
        case ..<1200: count = 6
        default: count = 7
        }
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    public static let posterAspect: CGFloat = 2.0 / 3.0
    public static let cardWidthPhone: CGFloat = 120
    public static let cardWidthPad: CGFloat = 160
}

/// Official LM outline mark (docs/brand/lumen-mark.svg).
public struct LumenBrandMark: View {
    public var size: CGFloat = 48

    public init(size: CGFloat = 48) {
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 128
            context.scaleBy(x: scale, y: scale)

            let bg = Path(roundedRect: CGRect(x: 0, y: 0, width: 128, height: 128), cornerRadius: 28)
            context.fill(bg, with: .color(LumenColors.bg))

            var l = Path()
            l.move(to: CGPoint(x: 36, y: 30))
            l.addLine(to: CGPoint(x: 36, y: 92))
            l.addLine(to: CGPoint(x: 64, y: 92))
            context.stroke(
                l,
                with: .color(LumenColors.text),
                style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
            )

            var m = Path()
            m.move(to: CGPoint(x: 48, y: 30))
            m.addLine(to: CGPoint(x: 64, y: 62))
            m.addLine(to: CGPoint(x: 80, y: 30))
            m.addLine(to: CGPoint(x: 94, y: 30))
            m.addLine(to: CGPoint(x: 94, y: 92))
            context.stroke(
                m,
                with: .color(LumenColors.accent),
                style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
