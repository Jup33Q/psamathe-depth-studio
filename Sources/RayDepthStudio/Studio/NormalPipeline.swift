import Foundation

/// 法线管线：normal 基于「深度混合 + 拼接后的整幅结果」实时计算，
/// 而不是每层各自出法线再合成。
///
/// 数据流（渲染层实现，核心层只携带参数）：
///   各图块深度（已过 DepthRange 重映射）
///     → 按 zIndex 顺序混合成整幅 composite depth（mix 策略）
///     → 中央差分求梯度 → normal（strength 控制强度，blurRadius 平滑）
///     → 与 LightingRig 的光源做光照合成
public struct NormalPipeline: Equatable, Sendable, Codable {
    public enum DepthMix: String, Sendable, Codable {
        /// 按叠放次序取最上层有效深度（默认：拼接后谁在上用谁）
        case zOrderTop
        /// 各层取最大（近处优先）
        case max
        /// 加权平均（柔和过渡）
        case weightedMean
    }

    public var mix: DepthMix
    /// 法线强度（中央差分增益，RayRelightNDI 曾固定 0.5）
    public var normalStrength: Float
    /// 法线图平滑核半径（box blur 两遍）
    public var blurRadius: Float

    public init(mix: DepthMix = .zOrderTop, normalStrength: Float = 0.5, blurRadius: Float = 2) {
        self.mix = mix
        self.normalStrength = normalStrength
        self.blurRadius = blurRadius
    }
}
