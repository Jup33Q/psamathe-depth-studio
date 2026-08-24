import Foundation

// MARK: - NDI

/// NDI 网络视频流（复用 RayRelightNDI 的 dlopen NDI 绑定）。
/// 深度路线：逐帧 DA3Mono（streamDepth）或纯 2D 直通（noDepth）。
public struct NDISource: InputSource {
    public let id: UUID
    public var name: String
    /// NDI 源地址，如 "MACBOOK (Camera 1)"
    public var endpoint: String
    public var depthProcessing: any DepthProcessing

    public let kind = InputKind.ndi
    public let streamCapability = StreamCapability.liveStream
    public var supportedDepthKinds: [DepthKind] { [.noDepth, .streamDepth] }

    public init(id: UUID = UUID(), name: String, endpoint: String,
                depthProcessing: any DepthProcessing = StreamDepth()) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
        self.depthProcessing = depthProcessing
    }

    public func nextFrame() async throws -> Frame? { nil } // 绑定层注入
}

// MARK: - Syphon

/// Syphon 本机 GPU 纹理共享（IOSurface）。
/// 深度路线同 NDI；额外预留 fromResource：与上游约定双纹理（color + depth 同名 `_depth` 服务）。
public struct SyphonSource: InputSource {
    public let id: UUID
    public var name: String
    /// Syphon server 名
    public var serverName: String
    public var appName: String?
    public var depthProcessing: any DepthProcessing

    public let kind = InputKind.syphon
    public let streamCapability = StreamCapability.liveStream
    public var supportedDepthKinds: [DepthKind] { [.noDepth, .streamDepth, .fromResource] }

    public init(id: UUID = UUID(), name: String, serverName: String, appName: String? = nil,
                depthProcessing: any DepthProcessing = StreamDepth()) {
        self.id = id
        self.name = name
        self.serverName = serverName
        self.appName = appName
        self.depthProcessing = depthProcessing
    }

    public func nextFrame() async throws -> Frame? { nil } // 绑定层注入
}

// MARK: - File-in

/// 文件输入：静态图片（绑定层负责解码 + center-crop 成方形）。
/// 深度路线：入画布时估计一次并缓存（staticDepth）、读取 sidecar 深度（fromResource），或纯 2D。
public struct FileInSource: InputSource {
    public let id: UUID
    public var name: String
    public var fileURL: URL
    /// sidecar 深度图（约定 `*_depth.png` / `.exr`），fromResource 时使用
    public var sidecarDepthURL: URL?
    public var depthProcessing: any DepthProcessing

    public let kind = InputKind.fileIn
    public let streamCapability = StreamCapability.static
    public var supportedDepthKinds: [DepthKind] { [.noDepth, .staticDepth, .fromResource] }

    public init(id: UUID = UUID(), name: String, fileURL: URL, sidecarDepthURL: URL? = nil,
                depthProcessing: any DepthProcessing = StaticDepth()) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.sidecarDepthURL = sidecarDepthURL
        self.depthProcessing = depthProcessing
    }

    public func nextFrame() async throws -> Frame? { nil } // 绑定层注入
}

// MARK: - MetalFX

/// MetalFX 程序化特效源：GPU 实时生成，无外部输入。
///
/// - plane：平面特效（波形 / 高度场 / 程序化图案）。深度可在 shader 内解析生成 → fromResource。
/// - particle3D：3D 粒子特效（MetalFX 3D 管线）。几何本身三维，渲染时自带深度缓冲 → fromResource。
public struct MetalFXSource: InputSource {

    public struct PlaneFX: Equatable, Sendable, Codable {
        /// 平面特效标识（如 "wave", "heightfield", "stripe"）
        public var shaderName: String
        /// shader 是否输出程序化深度（高度场类为 true）
        public var generatesDepth: Bool
        public init(shaderName: String, generatesDepth: Bool) {
            self.shaderName = shaderName
            self.generatesDepth = generatesDepth
        }
    }

    public struct ParticleFX: Equatable, Sendable, Codable {
        public var particleCount: Int
        /// 粒子系统渲染时输出原生深度缓冲（3D 特效恒为 true）
        public var emitsDepthBuffer: Bool
        public init(particleCount: Int, emitsDepthBuffer: Bool = true) {
            self.particleCount = particleCount
            self.emitsDepthBuffer = emitsDepthBuffer
        }
    }

    public enum Effect: Equatable, Sendable, Codable {
        case plane(PlaneFX)
        case particle3D(ParticleFX)
    }

    public let id: UUID
    public var name: String
    public var effect: Effect
    public var depthProcessing: any DepthProcessing

    public let kind = InputKind.metalFX
    public let streamCapability = StreamCapability.generated

    public var supportedDepthKinds: [DepthKind] {
        switch effect {
        case .plane(let fx):
            // 高度场类平面特效可解析产出深度；否则纯 2D
            return fx.generatesDepth ? [.noDepth, .fromResource] : [.noDepth]
        case .particle3D(let fx):
            // 3D 粒子几何即三维，深度缓冲即深度；禁深度时退化为平面公告牌渲染
            return fx.emitsDepthBuffer ? [.fromResource, .noDepth] : [.noDepth]
        }
    }

    public init(id: UUID = UUID(), name: String, effect: Effect,
                depthProcessing: any DepthProcessing = NoDepth()) {
        self.id = id
        self.name = name
        self.effect = effect
        self.depthProcessing = depthProcessing
    }

    public func nextFrame() async throws -> Frame? { nil } // 绑定层注入
}

// MARK: - Camera

/// 相机输入（AVFoundation）。
/// 深度路线：逐帧 DA3Mono（streamDepth）或纯 2D；
/// TrueDepth / LiDAR 原生深度（fromResource）列入路线图，暂不开放。
public struct CameraSource: InputSource {
    public let id: UUID
    public var name: String
    /// AVCaptureDevice.uniqueID；nil = 系统默认相机
    public var deviceID: String?
    public var depthProcessing: any DepthProcessing

    public let kind = InputKind.camera
    public let streamCapability = StreamCapability.liveStream
    public var supportedDepthKinds: [DepthKind] { [.noDepth, .streamDepth] }

    public init(id: UUID = UUID(), name: String, deviceID: String? = nil,
                depthProcessing: any DepthProcessing = StreamDepth()) {
        self.id = id
        self.name = name
        self.deviceID = deviceID
        self.depthProcessing = depthProcessing
    }

    public func nextFrame() async throws -> Frame? { nil } // 绑定层注入
}
