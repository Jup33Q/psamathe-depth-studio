import Foundation
import CoreGraphics

/// 纹理句柄：与具体图形 API 解耦的像素载体描述。
///
/// 核心模型层不直接引用 Metal / IOSurface，绑定层（NDI / Syphon / MetalFX backend）
/// 在注入实现时把 `TextureRef.id` 映射到真实的 MTLTexture / CVPixelBuffer / IOSurface。
public struct TextureRef: Equatable, Sendable {
    public enum Backing: String, Sendable {
        case metal        // MTLTexture
        case pixelBuffer  // CVPixelBuffer
        case ioSurface    // IOSurface（Syphon）
        case cpuMemory    // CPU 侧位图（file-in 解码、占位帧）
    }

    public var id: UInt64
    public var size: CGSize
    public var backing: Backing

    public init(id: UInt64, size: CGSize, backing: Backing) {
        self.id = id
        self.size = size
        self.backing = backing
    }
}

/// 一帧输入：颜色 + 可选的随帧附带深度（fromResource 的直接来源）。
public struct Frame: Equatable, Sendable {
    public var sequence: UInt64
    public var timestamp: TimeInterval
    public var color: TextureRef
    /// 随源附带的深度（Syphon 双纹理约定 / 3D 粒子深度缓冲 / sidecar 深度图）
    public var embeddedDepth: TextureRef?

    public init(
        sequence: UInt64,
        timestamp: TimeInterval,
        color: TextureRef,
        embeddedDepth: TextureRef? = nil
    ) {
        self.sequence = sequence
        self.timestamp = timestamp
        self.color = color
        self.embeddedDepth = embeddedDepth
    }

    /// 画布只接收方形素材；非方形输入在绑定层做 center-crop。
    public var isSquare: Bool {
        color.size.width == color.size.height
    }
}
