import Foundation

/// 深度范围控制：static / stream / fromResource 三类的公共调节参数。
///
/// 归一化深度值从 [0, 1] 线性重映射到 [min, max]（不裁剪），再乘 intensity。
/// 实际重映射由渲染层执行（核心层只携带参数）。
public struct DepthRange: Equatable, Sendable, Codable {
    /// 映射目标下界 [0, 1]
    public var min: Float
    /// 映射目标上界 [0, 1]
    public var max: Float
    /// 强度（重映射后的整体增益）
    public var intensity: Float

    public init(min: Float = 0, max: Float = 1, intensity: Float = 1) {
        precondition(min <= max, "DepthRange: min must be <= max")
        self.min = min.clamped(to: 0...1)
        self.max = max.clamped(to: 0...1)
        self.intensity = intensity
    }

    /// 把归一化深度值从 [0, 1] 线性重映射到 [min, max]（渲染层参考实现；不裁剪）
    public func remap(_ value: Float) -> Float {
        (value * (max - self.min) + self.min) * intensity
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
