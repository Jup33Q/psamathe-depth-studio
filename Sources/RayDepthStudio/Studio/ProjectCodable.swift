import Foundation

/// 工程持久化（M3，plan 批准的 Codable 化）。
///
/// - 输入源以「类别 + 载荷」信封编码（existential 注册表 → 类型安全数组）。
/// - 深度处理以 kind 信封编码：运行时状态不持久化——`StaticDepth` 的缓存、
///   `ResourceDepth.resource`（绑定层纹理仓库的运行时句柄）一律丢弃，
///   加载后由绑定层按 `sidecarDepthURL` 惰性重注册。
/// - 源引用相对路径：编码端在 `userInfo[.raydepthAssetMap]` 提供
///   [绝对路径: 包内相对路径] 映射，命中的 fileURL / sidecarDepthURL 编码为
///   相对引用（"assets/..."）；解码端在 `userInfo[.raydepthDocumentBase]`
///   提供文档包基地址，相对引用解析回绝对路径。不带 userInfo 时按绝对路径原样编解码。
public extension CodingUserInfoKey {
    /// 编码端资产映射：[文件绝对路径: 包内相对路径（"assets/..."）]
    static let raydepthAssetMap = CodingUserInfoKey(rawValue: "raydepthAssetMap")!
    /// 解码端文档包基地址（相对引用解析为绝对路径）
    static let raydepthDocumentBase = CodingUserInfoKey(rawValue: "raydepthDocumentBase")!
}

// MARK: - URL 相对引用工具

/// 编码：命中资产映射则改写为相对引用（percent-encoded，容忍空格与非 ASCII 文件名）
private func persistableURL(_ url: URL, encoder: Encoder) -> URL {
    guard let map = encoder.userInfo[.raydepthAssetMap] as? [String: String],
          let relative = map[url.path],
          let encoded = relative.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
          let url = URL(string: encoded) else { return url }
    return url
}

/// 解码：无 scheme 的相对引用按文档包基地址解析回绝对路径
private func resolvedURL(_ url: URL, decoder: Decoder) -> URL {
    guard url.scheme == nil,
          let base = decoder.userInfo[.raydepthDocumentBase] as? URL else { return url }
    return base.appendingPathComponent(url.path)
}

// MARK: - 深度处理信封（kind + 持久化参数；运行时状态不持久化）

enum DepthProcessingSnapshot: Codable {
    case noDepth
    case staticDepth
    case streamDepth(stride: Int)
    case resourceDepth

    init(_ processing: any DepthProcessing) {
        switch processing {
        case is NoDepth: self = .noDepth
        case is StaticDepth: self = .staticDepth
        case let stream as StreamDepth: self = .streamDepth(stride: stream.stride)
        case is ResourceDepth: self = .resourceDepth
        default: self = .noDepth // 核心类型已全覆盖；未知绑定层类型兜底为 noDepth
        }
    }

    func make() -> any DepthProcessing {
        switch self {
        case .noDepth: return NoDepth()
        case .staticDepth: return StaticDepth()
        case .streamDepth(let stride): return StreamDepth(stride: stride)
        case .resourceDepth: return ResourceDepth()
        }
    }
}

// MARK: - 输入源 Codable（depthProcessing 走信封，其余字段直编码）

extension NDISource: Codable {
    private enum CodingKeys: String, CodingKey { case id, name, endpoint, depthProcessing }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(UUID.self, forKey: .id),
                  name: try c.decode(String.self, forKey: .name),
                  endpoint: try c.decode(String.self, forKey: .endpoint),
                  depthProcessing: try c.decode(DepthProcessingSnapshot.self, forKey: .depthProcessing).make())
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(endpoint, forKey: .endpoint)
        try c.encode(DepthProcessingSnapshot(depthProcessing), forKey: .depthProcessing)
    }
}

extension SyphonSource: Codable {
    private enum CodingKeys: String, CodingKey { case id, name, serverName, appName, depthProcessing }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(UUID.self, forKey: .id),
                  name: try c.decode(String.self, forKey: .name),
                  serverName: try c.decode(String.self, forKey: .serverName),
                  appName: try c.decodeIfPresent(String.self, forKey: .appName),
                  depthProcessing: try c.decode(DepthProcessingSnapshot.self, forKey: .depthProcessing).make())
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(serverName, forKey: .serverName)
        try c.encodeIfPresent(appName, forKey: .appName)
        try c.encode(DepthProcessingSnapshot(depthProcessing), forKey: .depthProcessing)
    }
}

extension FileInSource: Codable {
    private enum CodingKeys: String, CodingKey { case id, name, fileURL, sidecarDepthURL, depthProcessing }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let sidecar = try c.decodeIfPresent(URL.self, forKey: .sidecarDepthURL)
        self.init(id: try c.decode(UUID.self, forKey: .id),
                  name: try c.decode(String.self, forKey: .name),
                  fileURL: resolvedURL(try c.decode(URL.self, forKey: .fileURL), decoder: decoder),
                  sidecarDepthURL: sidecar.map { resolvedURL($0, decoder: decoder) },
                  depthProcessing: try c.decode(DepthProcessingSnapshot.self, forKey: .depthProcessing).make())
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(persistableURL(fileURL, encoder: encoder), forKey: .fileURL)
        try c.encodeIfPresent(sidecarDepthURL.map { persistableURL($0, encoder: encoder) },
                              forKey: .sidecarDepthURL)
        try c.encode(DepthProcessingSnapshot(depthProcessing), forKey: .depthProcessing)
    }
}

extension MetalFXSource: Codable {
    private enum CodingKeys: String, CodingKey { case id, name, effect, depthProcessing }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(UUID.self, forKey: .id),
                  name: try c.decode(String.self, forKey: .name),
                  effect: try c.decode(Effect.self, forKey: .effect),
                  depthProcessing: try c.decode(DepthProcessingSnapshot.self, forKey: .depthProcessing).make())
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(effect, forKey: .effect)
        try c.encode(DepthProcessingSnapshot(depthProcessing), forKey: .depthProcessing)
    }
}

extension CameraSource: Codable {
    private enum CodingKeys: String, CodingKey { case id, name, deviceID, depthProcessing }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(UUID.self, forKey: .id),
                  name: try c.decode(String.self, forKey: .name),
                  deviceID: try c.decodeIfPresent(String.self, forKey: .deviceID),
                  depthProcessing: try c.decode(DepthProcessingSnapshot.self, forKey: .depthProcessing).make())
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(deviceID, forKey: .deviceID)
        try c.encode(DepthProcessingSnapshot(depthProcessing), forKey: .depthProcessing)
    }
}

// MARK: - StudioProject Codable（existential 注册表 → 类别信封数组）

extension StudioProject: Codable {

    /// 输入源信封：kind 判别 + 对应类型载荷
    private struct SourceEnvelope: Codable {
        let source: any InputSource

        private enum CodingKeys: String, CodingKey { case kind, payload }

        init(_ source: any InputSource) { self.source = source }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            switch try c.decode(InputKind.self, forKey: .kind) {
            case .ndi: source = try c.decode(NDISource.self, forKey: .payload)
            case .syphon: source = try c.decode(SyphonSource.self, forKey: .payload)
            case .fileIn: source = try c.decode(FileInSource.self, forKey: .payload)
            case .metalFX: source = try c.decode(MetalFXSource.self, forKey: .payload)
            case .camera: source = try c.decode(CameraSource.self, forKey: .payload)
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(source.kind, forKey: .kind)
            switch source {
            case let s as NDISource: try c.encode(s, forKey: .payload)
            case let s as SyphonSource: try c.encode(s, forKey: .payload)
            case let s as FileInSource: try c.encode(s, forKey: .payload)
            case let s as MetalFXSource: try c.encode(s, forKey: .payload)
            case let s as CameraSource: try c.encode(s, forKey: .payload)
            default: break // 核心类型已全覆盖；未知绑定层类型跳过
            }
        }
    }

    private enum CodingKeys: String, CodingKey { case canvas, lights, normalPipeline, sources }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(canvas: try c.decode(Canvas.self, forKey: .canvas),
                  lights: try c.decode(LightingRig.self, forKey: .lights),
                  normalPipeline: try c.decode(NormalPipeline.self, forKey: .normalPipeline))
        let envelopes = try c.decode([SourceEnvelope].self, forKey: .sources)
        sources = Dictionary(uniqueKeysWithValues: envelopes.map { ($0.source.id, $0.source) })
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(canvas, forKey: .canvas)
        try c.encode(lights, forKey: .lights)
        try c.encode(normalPipeline, forKey: .normalPipeline)
        // 按 id 排序保证输出确定性（文档包可 diff）
        let envelopes = sources.values.map(SourceEnvelope.init)
            .sorted { $0.source.id.uuidString < $1.source.id.uuidString }
        try c.encode(envelopes, forKey: .sources)
    }
}
