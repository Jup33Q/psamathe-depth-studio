import Foundation
import CoreGraphics

/// 画布上的方形图块：绑一个输入源，携带 2D 变换（平移 + 等比缩放）。
/// 仅支持方形——`edge` 为 scale = 1 时的边长，渲染边长 = edge × scale。
public struct SquareTile: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    /// 绑定的输入源
    public var sourceID: UUID
    /// 所属图层（depth 种类即图层/通道）
    public var depthKind: DepthKind
    /// 深度 min/max 范围控制（仅 static / stream / fromResource 生效）
    public var depthRange: DepthRange?
    /// 基准边长（画布单位，scale = 1）
    public var edge: CGFloat
    /// 中心点（画布坐标）
    public var center: CGPoint
    /// 等比缩放（> 0）
    public var scale: CGFloat
    /// 叠放次序
    public var zIndex: Int

    public init(id: UUID = UUID(), sourceID: UUID, edge: CGFloat,
                depthKind: DepthKind = .noDepth, depthRange: DepthRange? = nil,
                center: CGPoint = .zero, scale: CGFloat = 1, zIndex: Int = 0) {
        precondition(edge > 0, "SquareTile.edge must be positive")
        precondition(scale > 0, "SquareTile.scale must be positive")
        self.id = id
        self.sourceID = sourceID
        self.depthKind = depthKind
        self.depthRange = depthRange
        self.edge = edge
        self.center = center
        self.scale = scale
        self.zIndex = zIndex
    }

    /// 实际渲染边长
    public var renderedEdge: CGFloat { edge * scale }

    /// 实际占用的方形区域
    public var frame: CGRect {
        let half = renderedEdge / 2
        return CGRect(x: center.x - half, y: center.y - half,
                      width: renderedEdge, height: renderedEdge)
    }
}
