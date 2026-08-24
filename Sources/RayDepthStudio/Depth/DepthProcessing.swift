import Foundation

/// 深度估计器抽象 —— RayRelightNDI 的 DA3Mono CoreML `DepthEstimator` 的接入点。
public protocol DepthEstimating: Sendable {
    func estimateDepth(for frame: Frame) throws -> TextureRef
}

public enum DepthError: Error, Equatable {
    /// 该处理方式要求估计器，但未注入
    case estimatorMissing
    /// 声明了 fromResource 但帧/源均未提供深度资源
    case resourceDepthMissing
}

/// 深度处理协议：一种 DepthKind 的运行时策略。
///
/// 以 struct 实现、按值挂在 InputSource 上；需要状态（缓存）时
/// 在 struct 内部持引用类型 box，对外仍保持值语义接口。
public protocol DepthProcessing: Sendable {
    var kind: DepthKind { get }
    /// 是否需要逐帧调用深度模型（决定调度优先级与功耗预算）
    var requiresPerFrameInference: Bool { get }
    /// 给定一帧，产出深度纹理；`nil` 表示该路不使用深度。
    func depth(for frame: Frame, estimator: (any DepthEstimating)?) throws -> TextureRef?
}

// MARK: - noDepth

/// 纯 2D：不产出深度，模型完全旁路。
public struct NoDepth: DepthProcessing {
    public let kind = DepthKind.noDepth
    public let requiresPerFrameInference = false
    public init() {}
    public func depth(for frame: Frame, estimator: (any DepthEstimating)?) throws -> TextureRef? {
        nil
    }
}

// MARK: - staticDepth

/// 静态深度：首次估计后缓存复用，素材变化（换图）时调用 `invalidate()`。
public struct StaticDepth: DepthProcessing {
    public let kind = DepthKind.staticDepth
    public let requiresPerFrameInference = false

    private final class Cache: @unchecked Sendable {
        var depth: TextureRef?
    }
    private let cache = Cache()

    public init() {}

    public func depth(for frame: Frame, estimator: (any DepthEstimating)?) throws -> TextureRef? {
        if let cached = cache.depth { return cached }
        guard let estimator else { throw DepthError.estimatorMissing }
        let estimated = try estimator.estimateDepth(for: frame)
        cache.depth = estimated
        return estimated
    }

    public func invalidate() {
        cache.depth = nil
    }
}

// MARK: - streamDepth

/// 流式深度：每帧实时推理。NDI / Syphon / camera 的默认深度路线。
/// 性能预算参考 RayRelightNDI：DA3Mono-LARGE int8 约 33 ms/帧（504×504）。
public struct StreamDepth: DepthProcessing {
    public let kind = DepthKind.streamDepth
    public let requiresPerFrameInference = true

    /// 推理降频：每 n 帧估计一次，中间帧复用上一次结果（EMA 平滑在估计器内做）。
    public var stride: Int

    private final class Cache: @unchecked Sendable {
        var lastDepth: TextureRef?
    }
    private let cache = Cache()

    public init(stride: Int = 1) {
        self.stride = max(1, stride)
    }

    public func depth(for frame: Frame, estimator: (any DepthEstimating)?) throws -> TextureRef? {
        if frame.sequence % UInt64(stride) != 0, let last = cache.lastDepth {
            return last
        }
        guard let estimator else { throw DepthError.estimatorMissing }
        let estimated = try estimator.estimateDepth(for: frame)
        cache.lastDepth = estimated
        return estimated
    }
}

// MARK: - fromResource

/// 深度来自资源：优先取帧内嵌深度，其次取源级 sidecar / 预烘焙资源。
/// 不调用深度模型。
public struct ResourceDepth: DepthProcessing {
    public let kind = DepthKind.fromResource
    public let requiresPerFrameInference = false

    /// 源级深度资源（file-in 的 sidecar `*_depth.png`、MetalFX 平面特效的程序化高度场等）
    public var resource: TextureRef?

    public init(resource: TextureRef? = nil) {
        self.resource = resource
    }

    public func depth(for frame: Frame, estimator: (any DepthEstimating)?) throws -> TextureRef? {
        if let embedded = frame.embeddedDepth { return embedded }
        if let resource { return resource }
        throw DepthError.resourceDepthMissing
    }
}
