import Foundation
import CoreGraphics

public enum StudioError: Error, Equatable {
    /// 图层已达数量上限（noDepth 1 张 / streamDepth 8 张）
    case layerFull(kind: DepthKind, limit: Int)
    /// 该输入源的深度处理方式与目标图层不符
    case depthKindMismatch(source: DepthKind, layer: DepthKind)
}

/// 顶层工程模型：画布 + 源注册表 + 光源装备 + 法线管线。
///
/// 图层 = DepthKind（UI 顶层菜单的四个页签）。添加/删除输入源、
/// 图层数量上限、背景层沉底，都在这里收口。
public struct StudioProject {

    public var canvas: Canvas
    public var lights: LightingRig
    public var normalPipeline: NormalPipeline
    /// 输入源注册表：sourceID → source（existential 存储，不参与 Equatable）
    /// setter 放宽到 internal 仅供模块内 Codable 解码重建（见 ProjectCodable.swift），公开 API 不变
    public internal(set) var sources: [UUID: any InputSource]

    public init(canvas: Canvas = Canvas(),
                lights: LightingRig = LightingRig(),
                normalPipeline: NormalPipeline = NormalPipeline()) {
        self.canvas = canvas
        self.lights = lights
        self.normalPipeline = normalPipeline
        self.sources = [:]
    }

    // MARK: - 输入源增删

    /// 添加输入源：按源当前的 depthKind 进入对应图层，强制执行数量上限。
    /// 背景层（noDepth）图块 zIndex 沉底。
    @discardableResult
    public mutating func addSource(_ source: any InputSource, edge: CGFloat = 256) throws -> SquareTile {
        let kind = source.depthKind
        let current = tiles(in: kind).count
        if let limit = LayerPolicy.maxSources(for: kind), current >= limit {
            throw StudioError.layerFull(kind: kind, limit: limit)
        }
        sources[source.id] = source
        var tile = canvas.place(sourceID: source.id, edge: edge, depthKind: kind)
        if LayerPolicy.isBackground(kind) {
            let bottom = (canvas.tiles.map(\.zIndex).min() ?? 1) - 1
            setZIndex(of: tile.id, to: bottom)
            tile.zIndex = bottom
        }
        return tile
    }

    /// 删除输入源：图块 + 注册表一并移除。
    public mutating func removeSource(tileID: UUID) {
        guard let tile = canvas.tile(id: tileID) else { return }
        sources.removeValue(forKey: tile.sourceID)
        canvas.remove(id: tileID)
    }

    // MARK: - 图层查询

    public func tiles(in kind: DepthKind) -> [SquareTile] {
        canvas.tiles.filter { $0.depthKind == kind }
    }

    public func sources(in kind: DepthKind) -> [any InputSource] {
        tiles(in: kind).compactMap { sources[$0.sourceID] }
    }

    /// 剩余名额；nil = 不限
    public func remainingSlots(for kind: DepthKind) -> Int? {
        guard let limit = LayerPolicy.maxSources(for: kind) else { return nil }
        return max(0, limit - tiles(in: kind).count)
    }

    public func occupancyLabel(for kind: DepthKind) -> String {
        LayerPolicy.occupancyLabel(current: tiles(in: kind).count, kind: kind)
    }

    // MARK: - 图块编辑（移动 / 缩放 / 深度范围）

    public mutating func moveTile(id: UUID, to position: CGPoint) {
        canvas.move(id: id, to: position)
    }

    public mutating func scaleTile(id: UUID, to scale: CGFloat) {
        canvas.scale(id: id, to: scale)
    }

    /// 调节深度 min/max 范围（仅 static / stream / fromResource；noDepth 调用无效）
    public mutating func setDepthRange(of tileID: UUID, _ range: DepthRange) {
        guard let i = canvas.tiles.firstIndex(where: { $0.id == tileID }),
              LayerPolicy.hasDepthRangeControl(canvas.tiles[i].depthKind) else { return }
        canvas.tiles[i].depthRange = range
    }

    // MARK: - 光源（不限数量，鼠标控制）

    @discardableResult
    public mutating func addLight(_ light: LightSource) -> UUID {
        lights.addLight(light)
    }

    /// 鼠标拖动 → 移动主光源
    public mutating func movePrimaryLight(to position: CGPoint) {
        lights.moveLight(to: position)
    }

    // MARK: - 私有

    private mutating func setZIndex(of tileID: UUID, to zIndex: Int) {
        guard let i = canvas.tiles.firstIndex(where: { $0.id == tileID }) else { return }
        canvas.tiles[i].zIndex = zIndex
    }
}
