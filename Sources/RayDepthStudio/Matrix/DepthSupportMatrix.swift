import Foundation

/// 输入类型 × 深度处理方式的支持矩阵 —— 单一事实来源。
///
/// Obsidian 项目文档中的 support matrix 与本表保持一致；
/// `MatrixTests` 守住「每个 InputSource 的 supportedDepthKinds ⊆ 矩阵允许集」。
public enum DepthSupportMatrix {

    public enum Level: String, Sendable {
        case yes = "✅"
        case no = "❌"
        case planned = "🔜"
        case notApplicable = "➖"
    }

    /// 矩阵条目。MetalFX 按子类拆行（平面特效 / 3D 粒子），行键命名 `<inputKind>:<variant>`。
    public static let entries: [Row: [DepthKind: Level]] = [
        .init(input: .ndi): [
            .noDepth: .yes,
            .staticDepth: .notApplicable,   // 流不可「只估计一次」
            .streamDepth: .yes,             // DA3Mono CoreML 逐帧（RayRelightNDI 管线）
            .fromResource: .no
        ],
        .init(input: .syphon): [
            .noDepth: .yes,
            .staticDepth: .notApplicable,
            .streamDepth: .yes,
            .fromResource: .planned         // 双纹理约定：上游发布同名 _depth 服务
        ],
        .init(input: .fileIn): [
            .noDepth: .yes,
            .staticDepth: .yes,             // 入画布时估计一次并缓存
            .streamDepth: .no,              // 静态素材逐帧推理无意义
            .fromResource: .yes             // sidecar `*_depth.png` / EXR
        ],
        .init(input: .metalFX, variant: "plane"): [
            .noDepth: .yes,
            .staticDepth: .notApplicable,
            .streamDepth: .no,              // shader 内可解析出深度，无需模型
            .fromResource: .yes             // 程序化高度场
        ],
        .init(input: .metalFX, variant: "particle3D"): [
            .noDepth: .yes,                 // 退化为平面公告牌渲染
            .staticDepth: .no,
            .streamDepth: .no,              // 几何本身三维，无需单目估计
            .fromResource: .yes             // 原生深度缓冲
        ],
        .init(input: .camera): [
            .noDepth: .yes,
            .staticDepth: .notApplicable,
            .streamDepth: .yes,
            .fromResource: .planned         // TrueDepth / LiDAR 原生深度
        ]
    ]

    public struct Row: Hashable, Sendable {
        public var input: InputKind
        public var variant: String?
        public init(input: InputKind, variant: String? = nil) {
            self.input = input
            self.variant = variant
        }
        public var label: String {
            variant.map { "\(input.rawValue) · \($0)" } ?? input.rawValue
        }
    }

    public static func level(input: InputKind, variant: String? = nil, depth: DepthKind) -> Level? {
        entries[Row(input: input, variant: variant)]?[depth]
    }

    /// 生成 Markdown 表格（Obsidian 文档与代码共用同一数据源渲染）。
    public static func markdownTable() -> String {
        let kinds = DepthKind.allCases
        var lines = [
            "| 输入源 | " + kinds.map(\.rawValue).joined(separator: " | ") + " |",
            "|" + Array(repeating: "---", count: kinds.count + 1).joined(separator: "|") + "|"
        ]
        for (row, cols) in entries.sorted(by: { $0.key.label < $1.key.label }) {
            let cells = kinds.map { (cols[$0] ?? .no).rawValue }
            lines.append("| \(row.label) | " + cells.joined(separator: " | ") + " |")
        }
        return lines.joined(separator: "\n")
    }
}
