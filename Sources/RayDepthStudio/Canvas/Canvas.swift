import Foundation
import CoreGraphics

/// 画布：方形图块的集合，提供 移动 / 缩放 / 拼接 三类核心操作。
///
/// 纯值类型模型，不含渲染；渲染层按 `tiles`（zIndex 升序）依次合成。
public struct Canvas: Equatable, Sendable, Codable {

    /// 拼接吸附配置
    public struct Snap: Equatable, Sendable, Codable {
        public var isEnabled: Bool
        /// 边对边 / 中线对齐的吸附容差（画布单位）
        public var tolerance: CGFloat
        public init(isEnabled: Bool = true, tolerance: CGFloat = 8) {
            self.isEnabled = isEnabled
            self.tolerance = tolerance
        }
    }

    public var tiles: [SquareTile]
    public var snap: Snap

    public init(tiles: [SquareTile] = [], snap: Snap = Snap()) {
        self.tiles = tiles
        self.snap = snap
    }

    // MARK: - 增删

    /// 放置新图块；`at` 为 nil 时自动找第一个不与现有图块重叠的位置。
    /// `depthKind` 决定所属图层；static/stream/fromResource 自动附带默认 DepthRange。
    @discardableResult
    public mutating func place(sourceID: UUID, edge: CGFloat, at center: CGPoint? = nil,
                               depthKind: DepthKind = .noDepth) -> SquareTile {
        let position = center ?? firstFreeCenter(edge: edge)
        let range: DepthRange? = LayerPolicy.hasDepthRangeControl(depthKind) ? DepthRange() : nil
        let tile = SquareTile(sourceID: sourceID, edge: edge,
                              depthKind: depthKind, depthRange: range,
                              center: position, zIndex: (tiles.map(\.zIndex).max() ?? -1) + 1)
        tiles.append(tile)
        return tile
    }

    public mutating func remove(id: UUID) {
        tiles.removeAll { $0.id == id }
    }

    // MARK: - 移动

    /// 移动图块到指定中心点；开启吸附时自动与邻近图块对齐（拼接）。
    public mutating func move(id: UUID, to proposed: CGPoint) {
        guard let i = tiles.firstIndex(where: { $0.id == id }) else { return }
        tiles[i].center = snap.isEnabled ? snappedCenter(for: tiles[i], proposed: proposed) : proposed
    }

    public mutating func translate(id: UUID, by delta: CGVector) {
        guard let i = tiles.firstIndex(where: { $0.id == id }) else { return }
        let proposed = CGPoint(x: tiles[i].center.x + delta.dx,
                               y: tiles[i].center.y + delta.dy)
        move(id: id, to: proposed)
    }

    // MARK: - 缩放

    /// 以图块中心为锚点缩放（等比，保持方形）。
    public mutating func scale(id: UUID, to newScale: CGFloat) {
        guard let i = tiles.firstIndex(where: { $0.id == id }) else { return }
        tiles[i].scale = max(0.01, newScale)
    }

    public mutating func scale(id: UUID, by factor: CGFloat) {
        guard let i = tiles.firstIndex(where: { $0.id == id }) else { return }
        scale(id: id, to: tiles[i].scale * factor)
    }

    // MARK: - 拼接

    /// 计算吸附后的中心点：对每块其他图块，检查四条边与两条中线的对齐。
    /// 命中多个候选时取修正量最小者。
    public func snappedCenter(for tile: SquareTile, proposed: CGPoint) -> CGPoint {
        var best = proposed
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for other in tiles where other.id != tile.id {
            let proposedFrame = frameFor(center: proposed, edge: tile.renderedEdge)
            let otherFrame = other.frame

            // x 候选：我的左/右贴它的右/左，或中线对齐
            let xCandidates: [CGFloat] = [
                otherFrame.maxX + proposedFrame.width / 2,  // 我贴它右边
                otherFrame.minX - proposedFrame.width / 2,  // 我贴它左边
                otherFrame.midX                              // 垂直中线对齐
            ]
            // y 候选：我的上/下贴它的下/上，或中线对齐（y 向下为正）
            let yCandidates: [CGFloat] = [
                otherFrame.maxY + proposedFrame.height / 2,
                otherFrame.minY - proposedFrame.height / 2,
                otherFrame.midY
            ]

            let snappedX = xCandidates
                .map { ($0, abs($0 - proposed.x)) }
                .filter { $0.1 <= snap.tolerance }
                .min(by: { $0.1 < $1.1 })?.0
            let snappedY = yCandidates
                .map { ($0, abs($0 - proposed.y)) }
                .filter { $0.1 <= snap.tolerance }
                .min(by: { $0.1 < $1.1 })?.0

            let candidate = CGPoint(x: snappedX ?? proposed.x, y: snappedY ?? proposed.y)
            let distance = hypot(candidate.x - proposed.x, candidate.y - proposed.y)
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best
    }

    /// 一键拼接：把指定图块按行优先排成共享边的方阵（等边长，忽略各自 scale 差异时按渲染边长）。
    /// - Parameters:
    ///   - ids: 参与拼接的图块（顺序即行优先顺序）；nil = 全部
    ///   - edge: 统一渲染边长；nil = 取最大渲染边长
    ///   - origin: 方阵左上角第一块的中心
    public mutating func arrangeGrid(ids: [UUID]? = nil, edge: CGFloat? = nil,
                                     origin: CGPoint = .zero) {
        let selected = (ids.map { set in tiles.filter { set.contains($0.id) } } ?? tiles)
        guard !selected.isEmpty else { return }
        let gridEdge = edge ?? selected.map(\.renderedEdge).max()!
        let columns = Int(ceil(sqrt(CGFloat(selected.count))))

        for (index, tile) in selected.enumerated() {
            guard let i = tiles.firstIndex(where: { $0.id == tile.id }) else { continue }
            tiles[i].scale = gridEdge / tiles[i].edge
            let row = index / columns
            let col = index % columns
            tiles[i].center = CGPoint(x: origin.x + gridEdge * (CGFloat(col) + 0.5),
                                      y: origin.y + gridEdge * (CGFloat(row) + 0.5))
        }
    }

    // MARK: - 查询

    /// 命中测试（zIndex 高者优先），供拖拽拾取。
    public func hitTest(_ point: CGPoint) -> SquareTile? {
        tiles.filter { $0.frame.contains(point) }
             .max(by: { $0.zIndex < $1.zIndex })
    }

    public func tile(id: UUID) -> SquareTile? {
        tiles.first { $0.id == id }
    }

    // MARK: - 私有

    private func frameFor(center: CGPoint, edge: CGFloat) -> CGRect {
        CGRect(x: center.x - edge / 2, y: center.y - edge / 2, width: edge, height: edge)
    }

    /// 简单行排布局：从原点起依次向右排，换行下挪，找到不重叠的位置。
    private func firstFreeCenter(edge: CGFloat) -> CGPoint {
        var candidate = CGPoint(x: edge / 2, y: edge / 2)
        let rowHeight = edge
        while tiles.contains(where: { $0.frame.intersects(frameFor(center: candidate, edge: edge)) }) {
            candidate.x += edge
            if candidate.x > 4096 { // 画布单位上限保护，换行
                candidate.x = edge / 2
                candidate.y += rowHeight
            }
        }
        return candidate
    }
}
