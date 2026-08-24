import Foundation
import CoreGraphics

/// 光源：MetalFX 驱动的发光体，不限数量。
/// 位置用画布坐标表示，由鼠标拖动控制（见 LightingRig.moveLight）。
public struct LightSource: Identifiable, Equatable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        case point
        case spot
    }

    public let id: UUID
    public var name: String
    public var kind: Kind
    /// 画布坐标
    public var position: CGPoint
    public var intensity: Float
    /// 影响半径（画布单位）
    public var radius: Float
    /// RGB 0...1
    public var colorRGB: SIMD3<Float>
    /// 额外叠加 glowing fx 层（泛光后处理）
    public var glowingFX: Bool

    public init(id: UUID = UUID(), name: String, kind: Kind = .point,
                position: CGPoint = .zero, intensity: Float = 1, radius: Float = 200,
                colorRGB: SIMD3<Float> = .one, glowingFX: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.position = position
        self.intensity = intensity
        self.radius = radius
        self.colorRGB = colorRGB
        self.glowingFX = glowingFX
    }
}

/// 光源装备：不限数量；主光源跟随鼠标。
public struct LightingRig: Equatable, Sendable, Codable {
    public var lights: [LightSource]
    /// 鼠标控制的目标（默认第一个）
    public var primaryLightID: UUID?

    public init(lights: [LightSource] = [], primaryLightID: UUID? = nil) {
        self.lights = lights
        self.primaryLightID = primaryLightID ?? lights.first?.id
    }

    /// 添加光源，无数量上限。返回新光源 id。
    @discardableResult
    public mutating func addLight(_ light: LightSource) -> UUID {
        lights.append(light)
        if primaryLightID == nil { primaryLightID = light.id }
        return light.id
    }

    public mutating func removeLight(id: UUID) {
        lights.removeAll { $0.id == id }
        if primaryLightID == id { primaryLightID = lights.first?.id }
    }

    /// 鼠标拖动 → 移动主光源（或指定光源）
    public mutating func moveLight(id: UUID? = nil, to position: CGPoint) {
        let target = id ?? primaryLightID
        guard let target, let i = lights.firstIndex(where: { $0.id == target }) else { return }
        lights[i].position = position
    }

    public func light(id: UUID) -> LightSource? {
        lights.first { $0.id == id }
    }
}
