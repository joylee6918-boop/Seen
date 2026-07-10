import SwiftUI
import UIKit

// MARK: - Seen 设计系统 · 中性系统底 + 单一品牌色 + 健康语义色
// 黑白灰负责结构；干玫瑰只代表依安/选中；数据色只服务具体指标。

extension Color {
    /// 根据系统的浅色/深色外观自动解析的颜色 token。
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    // MARK: 基础色
    /// 页面环境色：iOS 中性灰白 / 中性深黑，不带任何数据色倾向。
    static let gBg = adaptive(
        light: UIColor(red: 0xF5/255, green: 0xF5/255, blue: 0xF7/255, alpha: 1),
        dark: UIColor(red: 0x0B/255, green: 0x0B/255, blue: 0x0D/255, alpha: 1)
    )
    /// 普通卡片底
    static let gSurface = adaptive(
        light: UIColor.white,
        dark: UIColor(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255, alpha: 1)
    )
    /// AI/重点卡片底
    static let gCompanionSurface = adaptive(
        light: UIColor(red: 0xFF/255, green: 0xF1/255, blue: 0xE8/255, alpha: 1),
        dark: UIColor(red: 0x2A/255, green: 0x20/255, blue: 0x1B/255, alpha: 1)
    )
    /// 极浅描边 / 分割线
    static let gHairline = adaptive(
        light: UIColor(red: 0xE5/255, green: 0xE5/255, blue: 0xEA/255, alpha: 1),
        dark: UIColor(red: 0x38/255, green: 0x38/255, blue: 0x3A/255, alpha: 1)
    )
    /// 主卡描边
    static let gNoteBorder = adaptive(
        light: UIColor(red: 0xD1/255, green: 0xD1/255, blue: 0xD6/255, alpha: 1),
        dark: UIColor(red: 0x48/255, green: 0x48/255, blue: 0x4A/255, alpha: 1)
    )
    /// 主文字
    static let gTextPrimary = adaptive(
        light: UIColor(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255, alpha: 1),
        dark: UIColor(red: 0xF2/255, green: 0xF2/255, blue: 0xF7/255, alpha: 1)
    )
    /// 正文文字
    static let gTextBody = adaptive(
        light: UIColor(red: 0x3A/255, green: 0x3A/255, blue: 0x3C/255, alpha: 1),
        dark: UIColor(red: 0xD1/255, green: 0xD1/255, blue: 0xD6/255, alpha: 1)
    )
    /// 次级文字
    static let gTextSecondary = adaptive(
        light: UIColor(red: 0x8E/255, green: 0x8E/255, blue: 0x93/255, alpha: 1),
        dark: UIColor(red: 0x8E/255, green: 0x8E/255, blue: 0x93/255, alpha: 1)
    )
    /// 弱文字
    static let gTextWeak = adaptive(
        light: UIColor(red: 0xC7/255, green: 0xC7/255, blue: 0xCC/255, alpha: 1),
        dark: UIColor(red: 0x63/255, green: 0x63/255, blue: 0x66/255, alpha: 1)
    )
    /// 选中底色
    static let gSelectedBg = adaptive(
        light: UIColor(red: 0xFE/255, green: 0xE7/255, blue: 0xDA/255, alpha: 1),
        dark: UIColor(red: 0x3A/255, green: 0x27/255, blue: 0x1F/255, alpha: 1)
    )
    /// 辅助暖黄
    static let gWarmApricot   = Color(red: 0xF2/255, green: 0x8C/255, blue: 0x53/255)
    /// 暖黄淡底
    static let gWarmApricotBg = Color(red: 0xFF/255, green: 0xED/255, blue: 0xE3/255)

    // MARK: 数据语义色 — 每种数据类型固定一色
    // 心情 · 柔玫瑰
    static let dMoodBg = adaptive(light: UIColor(red: 0xFD/255, green: 0xE8/255, blue: 0xEE/255, alpha: 1), dark: UIColor(red: 0.23, green: 0.16, blue: 0.18, alpha: 1))
    static let dMood     = Color(red: 0xEE/255, green: 0x7C/255, blue: 0x8D/255)
    // 睡眠 · 湖蓝
    static let dSleepBg = adaptive(light: UIColor(red: 0xE7/255, green: 0xF4/255, blue: 0xFD/255, alpha: 1), dark: UIColor(red: 0.12, green: 0.17, blue: 0.20, alpha: 1))
    static let dSleep    = Color(red: 0x6D/255, green: 0xB8/255, blue: 0xE8/255)
    // HRV / 恢复 · 薰衣草
    static let dHrvBg = adaptive(light: UIColor(red: 0xEE/255, green: 0xEB/255, blue: 0xFA/255, alpha: 1), dark: UIColor(red: 0.18, green: 0.15, blue: 0.22, alpha: 1))
    static let dHrv      = Color(red: 0x8C/255, green: 0x87/255, blue: 0xD3/255)
    // 心率 · 暖珊瑚
    static let dHeartBg = adaptive(light: UIColor(red: 0xFD/255, green: 0xE8/255, blue: 0xE4/255, alpha: 1), dark: UIColor(red: 0.24, green: 0.16, blue: 0.16, alpha: 1))
    static let dHeart    = Color(red: 0xED/255, green: 0x70/255, blue: 0x64/255)
    // 血氧 · 青蓝
    static let dOxygenBg = adaptive(light: UIColor(red: 0xE5/255, green: 0xF6/255, blue: 0xF8/255, alpha: 1), dark: UIColor(red: 0.12, green: 0.18, blue: 0.20, alpha: 1))
    static let dOxygen    = Color(red: 0x55/255, green: 0xAF/255, blue: 0xC0/255)
    // 体温 · 蜜桃
    static let dTempBg = adaptive(light: UIColor(red: 0xFF/255, green: 0xEB/255, blue: 0xDD/255, alpha: 1), dark: UIColor(red: 0.22, green: 0.17, blue: 0.13, alpha: 1))
    static let dTemp      = Color(red: 0xEE/255, green: 0x97/255, blue: 0x62/255)
    // 摄氧量 · 灰紫
    static let dVo2Bg = adaptive(light: UIColor(red: 0xED/255, green: 0xEC/255, blue: 0xF9/255, alpha: 1), dark: UIColor(red: 0.17, green: 0.15, blue: 0.22, alpha: 1))
    static let dVo2       = Color(red: 0x88/255, green: 0x82/255, blue: 0xCC/255)
    // 睡眠心率 · 粉红
    static let dSleepHeartBg = adaptive(light: UIColor(red: 0xFB/255, green: 0xE8/255, blue: 0xEF/255, alpha: 1), dark: UIColor(red: 0.23, green: 0.16, blue: 0.18, alpha: 1))
    static let dSleepHeart   = Color(red: 0xD8/255, green: 0x75/255, blue: 0x98/255)
    // 运动 · 绿
    static let dMoveBg = adaptive(light: UIColor(red: 0xEA/255, green: 0xF5/255, blue: 0xE3/255, alpha: 1), dark: UIColor(red: 0.14, green: 0.19, blue: 0.14, alpha: 1))
    static let dMove     = Color(red: 0x70/255, green: 0xB9/255, blue: 0x6D/255)
    // 能量 · 温橙
    static let dEnergyBg = adaptive(light: UIColor(red: 0xFF/255, green: 0xE9/255, blue: 0xDB/255, alpha: 1), dark: UIColor(red: 0.23, green: 0.16, blue: 0.14, alpha: 1))
    static let dEnergy   = Color(red: 0xF0/255, green: 0x8C/255, blue: 0x53/255)
    // 习惯 · 黄
    static let dHabitBg = adaptive(light: UIColor(red: 0xEA/255, green: 0xF5/255, blue: 0xE3/255, alpha: 1), dark: UIColor(red: 0.15, green: 0.19, blue: 0.14, alpha: 1))
    static let dHabit    = Color(red: 0x70/255, green: 0xB9/255, blue: 0x6D/255)
    // 咖啡 · 棕金
    static let dCoffeeBg = adaptive(light: UIColor(red: 0xF4/255, green: 0xE9/255, blue: 0xDC/255, alpha: 1), dark: UIColor(red: 0.20, green: 0.16, blue: 0.13, alpha: 1))
    static let dCoffee   = Color(red: 0xB9/255, green: 0x82/255, blue: 0x50/255)
    // 灵感 · 淡薰衣草
    static let dIdeaBg = adaptive(light: UIColor(red: 0xFD/255, green: 0xF3/255, blue: 0xD7/255, alpha: 1), dark: UIColor(red: 0.22, green: 0.19, blue: 0.13, alpha: 1))
    static let dIdea     = Color(red: 0xD7/255, green: 0xAB/255, blue: 0x4E/255)
    // AI 陪伴 / 同步 · 薰衣草
    static let dAiBg     = gSelectedBg
    static let dAi       = Color(red: 0xF2/255, green: 0x8C/255, blue: 0x53/255)
    // 分贝 / 声音 · 灰蓝
    static let dSoundBg = adaptive(light: UIColor(red: 0xE8/255, green: 0xF2/255, blue: 0xEA/255, alpha: 1), dark: UIColor(red: 0.16, green: 0.17, blue: 0.14, alpha: 1))
    static let dSound    = Color(red: 0x6D/255, green: 0x9B/255, blue: 0x77/255)

    // MARK: 状态色
    static let gSuccess  = Color(red: 0x34/255, green: 0xC7/255, blue: 0x59/255)
    static let gWarning  = Color(red: 0xFF/255, green: 0x9F/255, blue: 0x0A/255)
    static let gError    = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x30/255)

    // MARK: 兼容旧名 — 重构期间老视图引用不报错, 逐个改完删掉
    static let gRose = dMood
    static let gSage = dSleep
    static let gClay = dHrv
}

// MARK: - 数据类型 → 语义色 映射
enum DataType {
    case mood, sleep, hrv, heart, move, energy, floors, oxygen, temperature, vo2, sleepHeart, sound, habit, coffee, idea, ai, period

    var main: Color {
        switch self {
        case .mood:    return .dMood
        case .sleep:   return .dSleep
        case .hrv:     return .dHrv
        case .heart:   return .dHeart
        case .move:    return .dMove
        case .energy:  return .dEnergy
        case .floors:  return .dMove
        case .oxygen:  return .dOxygen
        case .temperature: return .dTemp
        case .vo2:     return .dVo2
        case .sleepHeart: return .dSleepHeart
        case .sound:   return .dSound
        case .habit:   return .dHabit
        case .coffee:  return .dCoffee
        case .idea:    return .dIdea
        case .ai:      return .dAi
        case .period:  return .dMood
        }
    }
    var bg: Color {
        switch self {
        case .mood:    return .dMoodBg
        case .sleep:   return .dSleepBg
        case .hrv:     return .dHrvBg
        case .heart:   return .dHeartBg
        case .move:    return .dMoveBg
        case .energy:  return .dEnergyBg
        case .floors:  return .dMoveBg
        case .oxygen:  return .dOxygenBg
        case .temperature: return .dTempBg
        case .vo2:     return .dVo2Bg
        case .sleepHeart: return .dSleepHeartBg
        case .sound:   return .dSoundBg
        case .habit:   return .dHabitBg
        case .coffee:  return .dCoffeeBg
        case .idea:    return .dIdeaBg
        case .ai:      return .dAiBg
        case .period:  return .dMoodBg
        }
    }
    /// SF Symbol 名称 (线性图标)
    var icon: String {
        switch self {
        case .mood:    return "heart"
        case .sleep:   return "moon"
        case .hrv:     return "heart.text.square"
        case .heart:   return "heart.fill"
        case .move:    return "figure.walk"
        case .energy:  return "flame"
        case .floors:  return "stairs"
        case .oxygen:  return "lungs"
        case .temperature: return "thermometer.medium"
        case .vo2:     return "waveform.path.ecg"
        case .sleepHeart: return "bed.double.fill"
        case .sound:   return "speaker.wave.2"
        case .habit:   return "checkmark.circle"
        case .coffee:  return "cup.and.saucer.fill"
        case .idea:    return "lightbulb"
        case .ai:      return "sparkles"
        case .period:  return "drop.fill"
        }
    }
    var label: String {
        switch self {
        case .mood:    return "心情"
        case .sleep:   return "睡眠"
        case .hrv:     return "HRV"
        case .heart:   return "心率"
        case .move:    return "运动"
        case .energy:  return "活动"
        case .floors:  return "楼层"
        case .oxygen:  return "血氧"
        case .temperature: return "体温"
        case .vo2:     return "摄氧量"
        case .sleepHeart: return "睡眠心率"
        case .sound:   return "分贝"
        case .habit:   return "习惯"
        case .coffee:  return "咖啡"
        case .idea:    return "灵感"
        case .ai:      return "AI"
        case .period:  return "经期"
        }
    }
}

// MARK: - 字号 token
extension Font {
    static let gH1     = Font.system(size: 28, weight: .semibold)
    static let gH2     = Font.system(size: 20, weight: .semibold)
    static let gH3     = Font.system(size: 16, weight: .medium)
    static let gBody   = Font.system(size: 14, weight: .regular)
    static let gCaption = Font.system(size: 12, weight: .regular)
    static let gNumber = Font.system(size: 24, weight: .semibold)
}

// MARK: - 统一卡片
// 明亮实色卡片：靠背景明度差和极弱环境阴影分层。
struct GleanCard: ViewModifier {
    var cornerRadius: CGFloat = 18
    var padding: CGFloat? = 16

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background(SeenCardSurface(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.055), radius: 12, x: 0, y: 5)
    }
}

extension View {
    func gleanCard(cornerRadius: CGFloat = 18, padding: CGFloat? = 16) -> some View {
        modifier(GleanCard(cornerRadius: cornerRadius, padding: padding))
    }

    /// iOS inset-grouped 风格：用于表单页，不做悬浮阴影或夸张卡片感。
    func nativeGroup(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(SeenCardSurface(cornerRadius: 18))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.gHairline.opacity(0.35), lineWidth: 0.5)
            )
    }

    func seenCardElevation() -> some View {
        shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 5)
    }
}

/// 中性页面底；品牌色不再参与大面积背景装饰。
struct SeenBackground: View {
    var body: some View {
        Color.gBg.ignoresSafeArea()
    }
}

/// 内容卡使用稳定实色；Liquid Glass 只留给系统 Tab Bar 与浮层。
struct SeenCardSurface: View {
    var cornerRadius: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.gSurface)
    }
}

// MARK: - 主按钮 / 次按钮
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.gH3)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.dAi)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.gH3)
            .foregroundColor(.gTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.gSurface)
            .overlay(Capsule().stroke(Color.gHairline, lineWidth: 1))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - 状态标签 pill
struct StatusPill: View {
    let text: String
    let kind: Kind

    enum Kind {
        case success, warning, error, neutral, ai
        var color: Color {
            switch self {
            case .success: return .gSuccess
            case .warning: return .gWarning
            case .error:   return .gError
            case .neutral: return .gTextSecondary
            case .ai:      return .dAi
            }
        }
        var bg: Color {
            switch self {
            case .success: return .gSuccess.opacity(0.10)
            case .warning: return .gWarning.opacity(0.12)
            case .error:   return .gError.opacity(0.10)
            case .neutral: return .gHairline.opacity(0.50)
            case .ai:      return .dAiBg
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.gCaption)
            .foregroundColor(kind.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(kind.bg)
            .clipShape(Capsule())
    }
}

// MARK: - 数据 icon 小底 (浅色圆角底 + 线性图标)
struct DataIcon: View {
    let type: DataType
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: type.icon)
            .font(.system(size: size * 0.45, weight: .regular))
            .foregroundColor(type.main)
            .frame(width: size, height: size)
            .background(type.bg)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}
