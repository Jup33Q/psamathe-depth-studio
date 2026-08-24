import Foundation

/// 深度处理方式：按「深度模型需求」对输入图像分类。
///
/// 每个输入源（NDI / Syphon / file-in / MetalFX / camera）挂上其中一种，
/// 决定这一路的深度从哪来、是否调用深度模型、调用频率。
public enum DepthKind: String, CaseIterable, Codable, Sendable {
    /// 不处理深度：纯 2D 合成，深度模型完全旁路。
    case noDepth
    /// 静态深度：素材稳定时估计一次并缓存（典型：file-in 图片入画布时跑一次 DA3Mono）。
    case staticDepth
    /// 流式深度：逐帧深度推理（典型：NDI / camera 接 DA3Mono CoreML，RayRelightNDI 的既有管线）。
    case streamDepth
    /// 深度来自资源：随源附带或预烘焙的深度（sidecar 深度图 / 3D 粒子的原生深度缓冲 / 程序化高度场）。
    case fromResource
}
