import SwiftUI
import AppKit

/// 复古包豪斯设计系统
/// 三原色强调（深浅通用）+ 随系统深/浅色自适应的语义色 + 几何母题
enum Bauhaus {

    // MARK: - 三原色（两种模式通用）

    /// 包豪斯红 #D6482B
    static let red = Color(red: 0.839, green: 0.282, blue: 0.169)
    /// 包豪斯蓝 #1E63B0
    static let blue = Color(red: 0.118, green: 0.388, blue: 0.690)
    /// 包豪斯黄 #F2B705
    static let yellow = Color(red: 0.949, green: 0.718, blue: 0.020)

    /// 三原色轮换（用于导航项、装饰）
    static let accents: [Color] = [red, blue, yellow]
    static func accent(_ index: Int) -> Color { accents[((index % accents.count) + accents.count) % accents.count] }

    // MARK: - 语义色（深/浅自适应）

    /// 主背景（浅：象牙 #F4ECD9 / 深：#1A1A1A）
    static let paper = dynamic(
        light: NSColor(srgbRed: 0.957, green: 0.925, blue: 0.851, alpha: 1),
        dark:  NSColor(srgbRed: 0.102, green: 0.102, blue: 0.102, alpha: 1)
    )
    /// 卡片/面板（浅：白 / 深：#262626）
    static let surface = dynamic(
        light: NSColor(srgbRed: 1.0,   green: 1.0,   blue: 1.0,   alpha: 1),
        dark:  NSColor(srgbRed: 0.149, green: 0.149, blue: 0.149, alpha: 1)
    )
    /// 描边 / 主文字（浅：#1A1A1A / 深：象牙）
    static let ink = dynamic(
        light: NSColor(srgbRed: 0.102, green: 0.102, blue: 0.102, alpha: 1),
        dark:  NSColor(srgbRed: 0.957, green: 0.925, blue: 0.851, alpha: 1)
    )
    /// 次级文字
    static let inkSecondary = dynamic(
        light: NSColor(srgbRed: 0.353, green: 0.353, blue: 0.353, alpha: 1),
        dark:  NSColor(srgbRed: 0.659, green: 0.659, blue: 0.659, alpha: 1)
    )

    /// 硬阴影色（固定深色，深/浅模式一致，避免深色模式下出现亮色重影）
    static let shadow = dynamic(
        light: NSColor(srgbRed: 0.102, green: 0.102, blue: 0.102, alpha: 1),
        dark:  NSColor(srgbRed: 0.0,   green: 0.0,   blue: 0.0,   alpha: 1)
    )

    /// 生成随外观切换的动态颜色
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
            return match == .darkAqua ? dark : light
        })
    }
}

// MARK: - 字体

enum BauhausFont {
    /// 大写标题（Futura 加粗，缺失回退系统圆体加粗）
    static func title(_ size: CGFloat = 26) -> Font {
        if NSFont(name: "Futura-Bold", size: size) != nil {
            return .custom("Futura-Bold", size: size)
        }
        return .system(size: size, weight: .heavy, design: .rounded)
    }

    /// 小标题
    static func heading(_ size: CGFloat = 16) -> Font {
        if NSFont(name: "Futura-Medium", size: size) != nil {
            return .custom("Futura-Medium", size: size)
        }
        return .system(size: size, weight: .bold, design: .rounded)
    }

    /// 正文
    static func body(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular)
    }
}

// MARK: - 视图修饰

extension View {
    /// 2pt 描边硬边框
    func bauhausBorder(_ color: Color = Bauhaus.ink, width: CGFloat = 2, cornerRadius: CGFloat = 3) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: width)
        )
    }

    /// 硬阴影（无模糊，复古海报质感）
    func bauhausHardShadow(_ color: Color = Bauhaus.shadow, x: CGFloat = 4, y: CGFloat = 4) -> some View {
        shadow(color: color.opacity(0.85), radius: 0, x: x, y: y)
    }

    /// 卡片：surface 底 + 描边 +（可选）硬阴影
    func bauhausCard(cornerRadius: CGFloat = 3, padding: CGFloat = 12, shadow: Bool = false) -> some View {
        self
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(Bauhaus.surface))
            .bauhausBorder(cornerRadius: cornerRadius)
            .modifier(ConditionalHardShadow(enabled: shadow))
    }
}

/// 条件硬阴影修饰
private struct ConditionalHardShadow: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.bauhausHardShadow()
        } else {
            content
        }
    }
}

// MARK: - 几何形状

/// 等腰三角形（顶点朝上）
struct BauhausTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// App 标记：红圆 + 蓝方 + 黄三角 组合
struct BauhausMark: View {
    var size: CGFloat = 24

    var body: some View {
        HStack(spacing: -size * 0.16) {
            Circle()
                .fill(Bauhaus.red)
                .frame(width: size, height: size)
            Rectangle()
                .fill(Bauhaus.blue)
                .frame(width: size * 0.85, height: size * 0.85)
            BauhausTriangle()
                .fill(Bauhaus.yellow)
                .frame(width: size * 0.9, height: size * 0.85)
        }
    }
}

// MARK: - 封面缩略图

/// 封面缩略图：从本地路径加载，失败时显示几何占位
struct CoverImageView: View {
    let path: String?
    var fallbackIcon: String = "music.note"
    var accent: Color = Bauhaus.blue

    var body: some View {
        if let path, let img = NSImage(contentsOfFile: path) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Rectangle().fill(accent.opacity(0.22))
                Image(systemName: fallbackIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(accent)
            }
        }
    }
}
