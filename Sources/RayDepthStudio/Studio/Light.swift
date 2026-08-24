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
    /// M3.5：锁定（隐藏 gizmo 圆点、不可选中/拖动）
    public var isLocked: Bool
    /// M3.5：锁定时随鼠标移动（全装备最多一个，见 LightingRig.setFollowsMouse）
    public var followsMouse: Bool

    public init(id: UUID = UUID(), name: String, kind: Kind = .point,
                position: CGPoint = .zero, intensity: Float = 1, radius: Float = 200,
                colorRGB: SIMD3<Float> = .one, glowingFX: Bool = false,
                isLocked: Bool = false, followsMouse: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.position = position
        self.intensity = intensity
        self.radius = radius
        self.colorRGB = colorRGB
        self.glowingFX = glowingFX
        self.isLocked = isLocked
        self.followsMouse = followsMouse
    }

    /// M3.5 additive 字段向后兼容：旧 project.json 无 isLocked/followsMouse 键，
    /// 解码回退默认 false（编码仍走合成实现，始终写出全量键）。
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(Kind.self, forKey: .kind)
        position = try c.decode(CGPoint.self, forKey: .position)
        intensity = try c.decode(Float.self, forKey: .intensity)
        radius = try c.decode(Float.self, forKey: .radius)
        colorRGB = try c.decode(SIMD3<Float>.self, forKey: .colorRGB)
        glowingFX = try c.decode(Bool.self, forKey: .glowingFX)
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        followsMouse = try c.decodeIfPresent(Bool.self, forKey: .followsMouse) ?? false
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

    /// M3.5：随鼠标移动开关。开启时清除其他灯的 followsMouse——
    /// 「最多一个光源跟随」的约束收敛在核心层，UI 不做重复判断。
    public mutating func setFollowsMouse(_ id: UUID, _ on: Bool) {
        for i in lights.indices {
            if lights[i].id == id {
                lights[i].followsMouse = on
            } else if on {
                lights[i].followsMouse = false
            }
        }
    }
}
