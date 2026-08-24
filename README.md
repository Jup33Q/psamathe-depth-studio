# RayDepthStudio

基于深度的重光照图像编辑器 —— 由 RayRelightNDI（NDI → DA3Mono 深度 → Metal 重打光）扩展而来。
本仓库是**核心模型库**（纯值类型、无渲染）；UI 与渲染绑定层在
`../RayDepthStudioUI`（SwiftPM package，path 依赖本库）。

当前里程碑 **M3.3 已完成**（项目文档体系 + MCP 基座 + Metal FX 实时编辑；此前 M1–M3.5 已交付：
真图进真图出、Phokos 历史导入、深度重光照、undo/redo 与工程持久化、视口与快捷键、
near=high 深度契约统一、图块 chrome 降噪、光源 gizmo 显隐/锁定/跟随）。
下一阶段 M3.4（检查器控件），M4（实时源与性能）在其后。
完整路线图与进度日志：`docs/image-editor-roadmap.md`（固化 plan，唯一事实源）。

## 构建与验证

```bash
swift build                 # 核心库
swift run raydepth-checks   # 断言检查器（环境无 XCTest 时的兜底验证，40 项）
Scripts/verify.sh           # 一键验证：40 项 checks + UI 45 项 harness 串联，任一失败非零退出

# UI 与渲染链验证（在 ../RayDepthStudioUI）
swift run RayDepthStudioUI              # 运行编辑器
swift run -c release relight-harness    # 渲染链 harness 45 项（A–H 区，含 FX 深度方向守门）
Scripts/build-app.sh                    # 构建带版本戳的 .app 并部署到桌面
Scripts/mcp-smoke.sh                    # MCP 无头冒烟（10 步全链路断言）
```

## 结构

```
Sources/RayDepthStudio/
├── Core/Frame.swift              # TextureRef / Frame：与图形 API 解耦的帧抽象
├── Depth/
│   ├── DepthKind.swift           # noDepth / staticDepth / streamDepth / fromResource
│   ├── DepthProcessing.swift     # DepthProcessing 协议 + 4 个策略 struct
│   └── DepthRange.swift          # [0,1]→[min,max] 线性重映射 + 强度（零裁剪）
├── Inputs/
│   ├── InputSource.swift         # InputSource 协议 / InputKind / StreamCapability
│   └── Sources.swift             # NDI / Syphon / FileIn / MetalFX(plane·particle3D) / Camera
├── Canvas/
│   ├── SquareTile.swift          # 方形图块（edge × scale，中心定位，zIndex）
│   └── Canvas.swift              # 移动 / 等比缩放 / 边对边吸附拼接 / arrangeGrid / hitTest
├── Studio/
│   ├── StudioProject.swift       # 顶层工程模型：画布 + 源注册表 + 光源装备 + 法线管线
│   ├── Light.swift               # LightSource / LightingRig（isLocked/followsMouse，M3.5）
│   ├── NormalPipeline.swift      # 深度混合策略（zOrderTop / max / weightedMean）+ 法线参数
│   ├── LayerPolicy.swift         # 图层数量上限（noDepth 1 / streamDepth 8 / 其余不限）
│   └── ProjectCodable.swift      # M3 工程持久化：Codable 化 + 源引用相对路径约定
└── Matrix/DepthSupportMatrix.swift  # 输入×深度支持矩阵（单一事实来源）
Scripts/verify.sh                 # M3.3 一键验证（checks + UI harness 串联）
```

绑定层（UI 包的 `RayDepthRelight` target：CoreImage 渲染链、DA3Mono CoreML 估计器、
sidecar 深度解码、**M3.3 起 MetalFXEngine**）通过实现 `InputSource.nextFrame()` 与
`DepthEstimating` 注入，核心层不依赖它们。NDI / Syphon / AVFoundation 的实际接入在 M4。

**深度契约 near=high（值大=近）**：所有深度生产者入口（sidecar 解码、DA3 估计器、
MetalFX shader）必须显式遵守；MetalFX 侧见 `MetalFXSource.PlaneFX.generatesDepth` 与
UI 包 FX 模板注释，引擎不做隐式反转，harness H 区有守门断言。

## MCP 与 FX（M3.3）

- 编辑器 GUI 内置 MCP 服务（Streamable HTTP，`http://127.0.0.1:8377/mcp`，仅 loopback）：
  工程/图块/光源/深度范围/导出/FX 共 13 个工具，文档见 `docs/mcp/`（每工具一页 +
  `00-overview.md` 总览）；agent 侧总览 skill：`raydepth-mcp`
- Metal FX：一个 `.metal` 文件 = 一个 FX（库目录 `~/Library/Application Support/RayDepthStudio/FX/`，
  文件名 ↔ `MetalFXSource.PlaneFX.shaderName`，本库该字段已 Codable 零变更）；
  实时编辑、热编译失败保留上一可用版；内置示例 gradient / checker / wave-heightfield

## 文档

- `docs/image-editor-roadmap.md` — 固化 plan（唯一事实源）：阶段总览、任务、验收、进度日志
- `docs/README.md` — docs 全量索引（激活提示词、MCP 文档、审查记录）
- `docs/mcp/` — MCP 工具文档（`00-overview.md` + 每工具一页；M5 算子将扩展 `ops-*.md`）
- `docs/documentation-review-2026-08-24.md` — 文档注释系统审查（失配清单已修复）
- 各阶段自包含激活提示词 `docs/m*.md`；`docs/ui-optimization-plan.md`（M0 历史快照）
