# AGENTS.md — RayDepthStudio（核心库）

基于深度的重光照图像编辑器的**核心库**：纯值语义 SwiftPM 库，无 UI、无第三方依赖。

## 构建与验证

```bash
swift build
swift run raydepth-checks        # 44 项核心断言（Sources/RayDepthStudioChecks）
Scripts/verify.sh                # 一键：44 项 checks + UI 45 项 harness（串联，任一失败非零退出）
```

UI 包在同级目录 `../RayDepthStudioUI`（path 依赖本库）。

## 架构红线

- **纯值语义**：模型全是 struct + 值语义；API 变更须先停下报告，获批才动（用户直接指令视为获批）
- **深度契约 near=high（值大=近）**：任何新深度生产者入口（sidecar / 估计器 / FX / AI 算子）必须显式处理方向并在 UI harness 加守门断言——M3.1「深度 cut 方向反」事故的制度化防线
- `StudioProject.sources` 是 `[UUID: any InputSource]`（existential 字典，非枚举信封）；Codable 信封在 `Studio/ProjectCodable.swift`
- `DepthRange.remap`：[0,1]→[min,max] 线性重映射、零裁剪（M3.1 追加变更）
- `LightSource.isLocked/followsMouse`（M3.5）：Codable 用 `decodeIfPresent ?? false` 向后兼容；`LightingRig.setFollowsMouse` 在核心层保证跟随唯一
- macOS 13+ / Swift 5.9 / 零第三方依赖 / 不用 macOS 14 才有的 API

## 目录导览

- `Sources/RayDepthStudio/Canvas/` — Canvas / SquareTile（图块：center/edge/scale/zIndex/depthRange）
- `Sources/RayDepthStudio/Core/` — Frame / TextureRef
- `Sources/RayDepthStudio/Depth/` — DepthKind、DepthProcessing 四策略（NoDepth/StaticDepth/StreamDepth/ResourceDepth）、DepthRange、DepthEstimating 协议
- `Sources/RayDepthStudio/Inputs/` — InputSource 协议 + 五类源（NDI/Syphon/FileIn/MetalFX/Camera）；MetalFXSource.PlaneFX（shaderName/generatesDepth）供 UI 绑定层 FX 引擎使用
- `Sources/RayDepthStudio/Matrix/` — DepthSupportMatrix
- `Sources/RayDepthStudio/Studio/` — StudioProject / LightingRig / NormalPipeline / LayerPolicy / ProjectCodable
- `Sources/RayDepthStudioChecks/` — 44 项轻量断言 CLI（无 XCTest 环境）
- `icon/` — 项目 logo（`logo-1024.png` 为正式版；UI 包构建时取 `RayDepthStudioUI/icon/AppIcon-1024.png` 嵌入 .app）
- `docs/` — roadmap（固化 plan）、各里程碑激活提示词、文档审查记录、`mcp/`（MCP 工具文档）
- `Scripts/verify.sh` — 一键验证

## 交付纪律

- 每次交付部署带版本戳的新构建包；验收只认当次构建的包，不验收残留旧包
- 每里程碑收尾：更新 `docs/image-editor-roadmap.md` 状态行 + 进度日志，同步 skill `raydepth-editor-roadmap` 当前阶段，按 `docs/documentation-review-2026-08-24.md` 格式复查文档失配
