import Foundation

/// 输入源类别：提升到一等公民的五类来源。
public enum InputKind: String, CaseIterable, Codable, Sendable {
    case ndi
    case syphon
    case fileIn
    case metalFX
    case camera
}

/// 帧供给节奏。
public enum StreamCapability: String, Sendable {
    case `static`    // 单帧 / 离散素材（file-in）
    case liveStream  // 持续帧流（NDI / Syphon / camera）
    case generated   // GPU 程序化生成（MetalFX）
}

/// 输入源协议：所有来源统一抽象，画布层只面向此协议。
///
/// 约定：
/// - 以 struct 实现，值语义、可拷贝、可放进集合；
/// - `depthProcessing` 是运行时可换的策略值（见 DepthProcessing）；
/// - `supportedDepthKinds` 声明该源合法的深度处理方式全集，
///   与 `DepthSupportMatrix` 保持一致（有单元测试守住一致性）。
public protocol InputSource: Identifiable, Sendable {
    var id: UUID { get }
    var name: String { get set }
    var kind: InputKind { get }
    var streamCapability: StreamCapability { get }
    /// 当前选用的深度处理方式
    var depthProcessing: any DepthProcessing { get set }
    /// 该源支持的深度处理方式全集
    var supportedDepthKinds: [DepthKind] { get }

    /// 绑定真实 backend 后产出下一帧；核心层不实现，由绑定层扩展提供。
    /// - Returns: `nil` 表示暂无新帧（流断开时画布保留末帧）。
    func nextFrame() async throws -> Frame?
}

public extension InputSource {
    var depthKind: DepthKind { depthProcessing.kind }

    func supports(_ kind: DepthKind) -> Bool {
        supportedDepthKinds.contains(kind)
    }

    /// 切换深度处理方式；不受支持时抛错，防止把流式源错配成静态深度。
    mutating func setDepthProcessing(_ processing: any DepthProcessing) throws {
        guard supports(processing.kind) else {
            throw SourceError.unsupportedDepthKind(kind: kind, depthKind: processing.kind)
        }
        depthProcessing = processing
    }
}

public enum SourceError: Error, Equatable {
    case unsupportedDepthKind(kind: InputKind, depthKind: DepthKind)
}
