# RayDepthStudio

基于深度的重光照图像编辑器 —— 由 RayRelightNDI（NDI → DA3Mono 深度 → Metal 重打光）扩展而来。
本仓库是**核心模型库**（纯值类型、无渲染）；UI 与渲染绑定层在
`../RayDepthStudioUI`（SwiftPM package，path 依赖本库）。

当前里程碑 **M3 已完成**（编辑器完备性：深度融合、undo/redo、`.raydepth` 工程持久化、
视口缩放平移、快捷键、网格/吸附开关），下一阶段 M4（实时源与性能）。
完整路线图与进度日志：`docs/image-editor-roadmap.md`（固化 plan，唯一事实源）。

已交付：M1 真图进真图出（打开图片 → 摆版 → 导出 PNG）、M1.5 Phokos 历史批量导入
（raySet 带 depth16 sidecar 进 Source 层）、M2 深度重光照（sidecar/DA3 深度 +
拖灯实时重着色 + 同渲染链导出）。

## 构建与验证

```bash
swift build                 # 核心库
swift run raydepth-checks   # 断言检查器（环境无 XCTest 时的兜底验证，36 项）

# UI 与渲染链验证（在 ../RayDepthStudioUI）
swift run RayDepthStudioUI              # 运行编辑器
swift run -c release relight-harness    # 渲染链 harness（sidecar/DA3/导出计时/深度融合/持久化往返）
```

## 结构

```
Sources/RayDepthStudio/
├── Core/Frame.swift              # TextureRef / Frame：与图形 API 解耦的帧抽象
├── Depth/
│   ├── DepthKind.swift           # noDepth / staticDepth / streamDepth / fromResource
│   ├── DepthProcessing.swift     # DepthProcessing 协议 + 4 个策略 struct
│   └── DepthRange.swift          # 深度 min/max 窗口 + 强度（渲染层执行重映射）
├── Inputs/
│   ├── InputSource.swift         # InputSource 协议 / InputKind / StreamCapability
│   └── Sources.swift             # NDI / Syphon / FileIn / MetalFX(plane·particle3D) / Camera
├── Canvas/
│   ├── SquareTile.swift          # 方形图块（edge × scale，中心定位，zIndex）
│   └── Canvas.swift              # 移动 / 等比缩放 / 边对边吸附拼接 / arrangeGrid / hitTest
├── Studio/
│   ├── StudioProject.swift       # 顶层工程模型：画布 + 源注册表 + 光源装备 + 法线管线
│   ├── Light.swift               # LightSource / LightingRig（多光源，主光源跟随鼠标）
│   ├── NormalPipeline.swift      # 深度混合策略（zOrderTop / max / weightedMean）+ 法线参数
│   ├── LayerPolicy.swift         # 图层数量上限（noDepth 1 / streamDepth 8 / 其余不限）
│   └── ProjectCodable.swift      # M3 工程持久化：Codable 化 + 源引用相对路径约定
└── Matrix/DepthSupportMatrix.swift  # 输入×深度支持矩阵（单一事实来源）
```

绑定层（UI 包的 `RayDepthRelight` target：CoreImage 渲染链、DA3Mono CoreML 估计器、
sidecar 深度解码）通过实现 `InputSource.nextFrame()` 与 `DepthEstimating` 注入，
核心层不依赖它们。NDI / Syphon / AVFoundation / MetalFX 的实际接入在 M4。

## 文档

- `docs/image-editor-roadmap.md` — 固化 plan（唯一事实源）：阶段总览、任务、验收、进度日志
- `docs/m2-relighting-activation-prompt.md` / `docs/m3-completeness-activation-prompt.md` — 各阶段自包含激活提示词
- `docs/ui-optimization-plan.md` — M0 交互定型方案（历史快照）
- `docs/documentation-review-2026-08-24.md` — 文档注释系统审查（失配清单已修复）
