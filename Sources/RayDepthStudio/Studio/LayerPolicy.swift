import Foundation

/// 图层数量策略：depth 种类即图层/通道。
///
/// - noDepth：限 1 张，作为背景层（沉底）
/// - streamDepth：限 8 张（可实例化，受深度模型逐帧推理算力约束）
/// - staticDepth / fromResource：不限
/// - MetalFX 光源不受此表约束（见 LightingRig，不限数量）
public enum LayerPolicy {

    /// 该图层的输入源数量上限；nil = 不限
    public static func maxSources(for kind: DepthKind) -> Int? {
        switch kind {
        case .noDepth: return 1
        case .streamDepth: return 8
        case .staticDepth, .fromResource: return nil
        }
    }

    /// 是否背景层（zIndex 恒沉底）
    public static func isBackground(_ kind: DepthKind) -> Bool {
        kind == .noDepth
    }

    /// 该图层是否暴露深度 min/max 范围调节（noDepth 无深度可调）
    public static func hasDepthRangeControl(_ kind: DepthKind) -> Bool {
        kind != .noDepth
    }

    /// 图层数量显示用："0/1"、"3/8"、"∞"
    public static func occupancyLabel(current: Int, kind: DepthKind) -> String {
        if let limit = maxSources(for: kind) {
            return "\(current)/\(limit)"
        }
        return "\(current)/∞"
    }
}
