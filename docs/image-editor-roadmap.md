# RayDepthStudio 转正路线图：UI 示例 → 可用图像编辑器（固化 plan）

> 日期：2026-08-24 · 状态：**M3.4 已完成（检查器数值控件与颜色选择增强）· 下一阶段 M3.7（图块重命名 + 跟随保持热修）→ M4（实时源与性能）**
> 项目：核心库 `~/Documents/kimi/workspace/RayDepthStudio`（SwiftPM 库）+ UI `~/Documents/kimi/workspace/RayDepthStudioUI`（SwiftPM executable，`swift run RayDepthStudioUI`）
> 执行入口：skill `raydepth-editor-roadmap`（激活后按本文当前阶段执行）
> 产品定位：基于深度的重光照图像编辑器（RayRelight 血统：depth → normal → 多光源着色）

## 现状盘点（M0 已交付）

- 五页签（Light / Static / Source / RealTime / No Depth）+ 图层隔离命中
- 单 `SwiftUI.Canvas` immediate-mode 渲染；拖拽期模型零发布，松手一次性提交（吸附生效）
- 图块两段式交互：hover 高亮 + 触觉反馈 → 点击选中 → 选中后才可拖动
- 光源一等公民：选中/拖动/主光源/锁；检查器数值随拖拽实时跟随（DragPreview 通道）
- **缺**：图块是纯色占位（无真实图片）、无深度数据、无重光照着色、无导出、无撤销、无工程持久化

## 阶段总览

| 阶段 | 目标一句话 | 产出 |
|------|-----------|------|
| **M1 MVP** | 真图进、真图出 | 打开图片 → 摆版 → 导出 PNG |
| **M1.5** | Phokos 历史批量导入 | 生成历史树 → 按类型入层、按层级布局，raySet 带 depth16 |
| **M2** | 深度重光照（核心价值） | sidecar/DA3 深度 + 拖灯实时重着色 + 导出 |
| **M3** | 编辑器完备性 | undo/redo、工程保存加载、视口缩放平移、快捷键 |
| **M3.1** | 热修（优先于 M4） | 深度约定统一 near=high + 拖拽实时融合预览 |
| **M3.2** | 图块 chrome 降噪 | 常态无框无文字；hover/选中/拖拽才显示描边与信息 |
| **M3.3** | 文档 + MCP + Metal FX（优先于 M4） | 文档体系化；MCP 基座（HTTP，skills 文档）；Metal FX 导入 + 实时编辑显示 |
| **M3.4** | 检查器数值与颜色控件 | depth 滑杆扩域 + 每滑杆 reset；颜色 RGB/HSV/吸管/调色板 |
| **M3.5** | 光源 gizmo 显隐与锁定/跟随 | 全局 gizmo 隐藏；单灯锁定（藏圆点）；锁定灯随鼠标（唯一） |
| **M3.6** | 界面文案与本地化（排于 M3.3 后、M4 前） | 术语表 + xcstrings 基座（zh-Hans/en）+ 全文案收敛 + 双语验证 |
| **M3.7** | 图块重命名 + 跟随保持热修（排于 M4 前） | 图片可重命名；灯光跟随跨页签/跨选中不丢 |
| **M4** | 实时源与性能 | camera/NDI/Syphon 帧流、stream depth、Metal 化 |
| **M5** | AI 算子经 MCP 开放 | SAM3 分割 / BiRefNet 抠图 / DA 深度重绘 + 算子 skills 文档 |
| **M6** | 架构重构与社区插件化 | 插件协议/包格式/加载器 + 社区开发文档 |

原则：**每阶段结束都是一个能用的东西**，不留半截工程；M1 刻意砍到最小，先跑通「文件 → 画布 → 文件」全链路。

---

## M1 · MVP：真图进、真图出

**目标**：用户能打开真实图片放进图层、移动缩放摆版、把合成结果导出为 PNG。不做任何深度/光照。

任务（按序）：

1. **图片加载与缓存**
   - 左面板加「打开图片…」按钮（`NSOpenPanel`，`allowedContentTypes: [.image]`），选中后按当前激活图层创建 `FileInSource`（`fileURL` 指向真实文件）
   - 新增 UI 层 `ImageStore`（`ObservableObject`）：按 `sourceID` 缓存解码后的 `CGImage`，首次访问异步解码，淘汰策略从简（全量保留即可）
   - 支持拖拽图片文件到画布直接入层（`onDrop`，`fileURL` provider）
2. **位图渲染**
   - `CanvasRenderer.drawTiles` 中，图块有图时画位图（方形 center-crop 裁切，遵循 `center`/`renderedEdge`），无图保留现有纯色占位
   - 名称/徽标/描边/hover/选中态逻辑不变，叠加在位图之上
3. **导出**
   - 顶栏「导出 PNG」：按 `zIndex` 升序把全部图块合成到固定尺寸（默认 2048×2048，可改）的 `CGContext`，`NSSavePanel` 存 PNG
   - 导出用独立合成函数，与画布渲染解耦（导出分辨率 ≠ 屏幕分辨率）
4. **去演示数据**：`seedDemo()` 改为空工程 + 两盏默认灯；`/tmp/*.png` 假路径全部清除

验收：

1. `cd ~/Documents/kimi/workspace/RayDepthStudio && swift run raydepth-checks` 36 项全过（核心库零改动）
2. 打开 ≥3 张真实照片（含大图 >20MP 不卡死），跨图层摆版，移动/缩放/删除正常
3. 导出 PNG 像素正确：尺寸符合设置，图块位置/缩放/叠放次序与画布一致
4. 冷启动 8 秒无崩溃；hover/选中/拖动交互回归无退化

不做：深度、重光照、撤销、工程保存、视口缩放。

---

## M1.5 · Phokos 历史导入（批量真图进、层级保留）

**目标**：一键读取 Phokos（flux-klein-studio）的生成历史，按节点类型导入对应图层，画布上按树的层级布局；ray-relightable 节点带 depth16 sidecar 进 Source 层，为 M2 深度重光照备好数据。全部改动在 UI 层，核心库零改动。

**数据源（已探明，只读、永不回写——Phokos app 与 MCP 进程会并发修剪该文件）**：

- 历史元数据：`~/Documents/kimi/workspace/flux-klein-studio/outputs/.history_tree.json`
  - v2：`parents`（child→parent 边表）+ `sets`（raySet 字典）+ 可选 `ai`（可能整个缺失）
  - v1 兜底：整个文件就是一张纯 `{"child": "parent"}` 字典
- 节点两类：
  - **image**：`outputs/` 下真实文件，nodeName = 文件名（`flux_<ts>_s<seed>.png` / `edit_<engine>_<ts>_s<seed>.png` / `mcp_` 前缀 = AI 生成 / 其他）
  - **raySet（ray-relightable）**：`set:<id>` 虚拟节点，`sets[id]` 含 `original` / `depth`（8bit 可视化）/ `normal` / `depth16`（**16bit 灰度原始深度，重光照要用的就是它**）
- `original` 解析：先按文件名 join outputsDir，不存在再按绝对路径处理
- 悬空 parent 边 → 该节点当根；orphan set（original 丢失）→ 丢弃
- 未被 `sets` 认领的 `depth_*` / `mcp_depth_*` 三元组（`_depth`/`_normal`/`_depth16` 后缀）按共同前缀归组兜底（对齐 Phokos 自己的 migrateLooseDepthFiles 启发式）
- 无持久化选中状态；「最新」按文件 mtime 推断

任务（按序）：

1. **解析器 `PhokosImporter.swift`（UI 层新文件，纯 Foundation，便于独立 harness 验证）**
   - 模型：`PhokosNode`（name / kind: image|raySet / fileURL / depth16URL / normalURL / parentName / mtime / isAI）
   - 扫描 `outputs/*.png|jpg|jpeg` 得节点全集（带 mtime），合并 `parents`/`sets` 建树（childrenMap 自 parents 反推）
   - 全部容错：v1 字典、字段缺失、`ai` 缺失、悬空边、orphan set、绝对路径 original、三元组归组兜底
   - 输出森林（根按 mtime 升序、兄弟按 mtime 升序），供面板展示与画布布局共用同一份
2. **解析 harness 验证（先于 UI）**
   - `swiftc` 把 `PhokosImporter.swift` + scratch main 单独编成 CLI，对真实 `.history_tree.json` 跑，打印解析后的树与计数，与 Phokos app 历史页目视一致
   - 覆盖：v1 字典、悬空边、orphan set、绝对路径 original、`ai` 缺失；通过后删 scratch
3. **导入面板 `PhokosImportView.swift`（sheet）**
   - 顶栏加「Phokos」按钮开 sheet；outputsDir 默认上述硬编码路径，面板内可改（内存态即可）
   - `OutlineGroup` 树形展示：缩进层级 + 缩略图（惰性加载）+ 徽标（★ ray-relightable / AI 生成）
   - 多选 +「包含选中项的子树」开关（默认开）；底部实时显示导入分布（Static n 张 / Source n 组）
4. **落画布 `StudioViewModel.importFromPhokos(_ nodes:)`**
   - 类型→图层映射：raySet → Source 层，`FileInSource(fileURL: original, sidecarDepthURL: depth16URL, depthProcessing: ResourceDepth())`；普通图 → Static 层，`FileInSource(depthProcessing: StaticDepth())`；name = 节点名去扩展名
   - 层级→布局：对选中森林 DFS，x = 140 + depth×260，y = 120 + row×260；zIndex 按导入顺序递增
   - 去重：fileURL 已在 `project.sources` 里的跳过
   - 层级关系不落模型（核心库无父子字段，不为它改 API）；层级靠画布布局 + 面板缩进表达
5. **回归**：36 项 checks、UI build、冷启动 8s、M1 功能（打开图片 / 拖拽 / 导出）不受影响

验收：

1. 对真实 Phokos 历史导入：画布布局层级与面板缩进一致；raySet 全部进 Source 层且 sidecar 指向 `*_depth16.png`（16bit 灰度）；普通图进 Static 层；AI 节点有标记
2. 解析 harness：上述容错用例全过
3. 36 项 checks 全过（核心库零改动）；冷启动 8s 无崩溃；M1 回归无退化
4. 导入 ≥20 节点不卡（缩略图惰性加载）

不做：双向同步（Phokos 侧新增不回灌）、层级关系持久化进工程（M3 工程保存时再议）、depth8/normal 资产入画布（M2 需要时再加）。

---

## M2 · 深度重光照（核心价值）

> 执行入口：`docs/m2-relighting-activation-prompt.md`（自包含激活提示词，2026-08-24 固化）

**目标**：静态图 + 深度 → 拖动光源实时看到重光照，导出重光照结果。这是产品存在的理由。

任务（按序）：

1. **绑定层渲染管线**（新 target/目录，不污染核心库）
   - CoreImage 实现渲染链：各图块深度经 `DepthRange` 重映射 → 按 `NormalPipeline.mix` 混合整幅深度 → 中央差分出 normal（`normalStrength`/`blurRadius` 生效）→ 与 `LightingRig` 多光源着色 → glowing 后处理
   - 自定义 `CIKernel` 两个：depth→normal、normal+lights→shading；失败降级方案：Metal compute（则 M4 的 Metal 化提前）
2. **sidecar 深度**：Source 层加载 `*_depth.png`（16bit 灰度），接到 `ResourceDepth.resource`
3. **DA3 静态深度**：Static 层接入 DA3Mono CoreML 估计器（复用 RayRelightNDI 的模型文件与 `DepthEstimator` 封装），实现核心库 `DepthEstimating` 协议注入；首帧估计后缓存（`StaticDepth` 自带缓存语义），换图 `invalidate()`
4. **实时预览**：光源拖动/参数编辑走 DragPreview 通驱动着色刷新，不发布 `@Published project`；depth min/max/intensity 滑杆实时重着色
5. **导出升级**：导出走同一渲染链全分辨率输出

验收：

1. Static 层放一张人像：估计深度 → 拖 Key 灯，明暗随灯位实时变化；滑杆调 depth range 立即可见
2. Source 层 sidecar 深度图与 `ResourceDepth` 结果一致；深度缺失时报 `resourceDepthMissing` 不崩溃
3. 导出 2048×2048 重光照 PNG < 3 秒；拖灯预览主观流畅（≥30fps）
4. 36 项 checks 全过；M1 功能回归

不做：流式源、逐帧推理调度、undo。

---

## M3 · 编辑器完备性

> 执行入口：`docs/m3-completeness-activation-prompt.md`（自包含激活提示词，2026-08-24 固化）

**目标**：日常可用，不怕误操作，工程可保存。

任务：

1. **深度融合修正**（M2 用户验收发现的遗留，2026-08-24 截图反馈）：两张 fromResource 图块重叠时深度未真正融合——当前默认 `mix=zOrderTop` 是画家算法（谁在上谁显示），且 max 模式下颜色不随深度胜者（只混合了几何）。修正：max 模式逐像素取深度最大值、**颜色跟随深度胜者**（等深 |Δd|≤ε 处取并列图块 RGB 平均，在 M2 等深机制上扩展）；顶栏 mix 可循环切换（zOrderTop / max / weightedMean），UI 默认改为 max；harness 更新 E 区断言并新增真实双 raySet 重叠融合用例
2. **Undo/redo**：模型是纯值类型 → 快照栈（每次 `project` 提交压栈，拖拽仍只算一次），Cmd+Z / Shift+Cmd+Z，栈深 50
3. **工程持久化**：`StudioProject` Codable 化（核心库加 `Codable` 约束，属允许的核心变更）+ 源引用存相对路径，`.raydepth` 文档包（project.json + assets/）；Cmd+S / Cmd+O
4. **视口**：滚轮/触控板缩放 + 空格拖拽平移；坐标变换集中在画布层一处
5. **快捷键**：Delete 删选中、Cmd+D 复制图块、方向键微移（1pt，Shift 10pt）
6. 网格显示与吸附开关进顶栏
7. **文档修复**（`docs/documentation-review-2026-08-24.md` 失配 5 项，过程中或收尾时完成）：核心库 README 重写至 M2 现状（里程碑/36 项/完整结构树/UI·绑定层·harness 指针）、UI 包补 README（三 target 结构/运行验证命令）、3 处头注释与 M2 行为对齐（ProjectExporter 兜底定位、CanvasRenderer 合成底图、StudioCanvasView 重光照触发链）、两份历史文档加路径迁移注记、拆除 `[instrument]` 临时插桩

验收：两张 fromResource raySet 重叠时 max 融合颜色随深度胜者、等深处 RGB 平均；20 步混合操作可逐步撤销重做到底；保存→退出→重开工程状态完全恢复（含灯光与深度参数）；文档审查失配 5 项全部修复。

---

## M3.1 · 热修：深度约定统一 + 拖拽实时融合预览（优先于 M4）

> 执行入口：`docs/m3.1-depth-fusion-hotfix-activation-prompt.md`（自包含激活提示词，2026-08-24 固化）

**背景**（2026-08-24 用户 M3 验收反馈两问题）：

1. **depth cut 方向反了**：本该在前面的被 cut 掉，在后面的反而出现。
2. **拖动图块时看不到 depth 混合的实时效果**（M2 架构把拖拽中的图块从合成排除，松手才回归）。

**确诊**（Swift scratch 实测，已删）：两路深度数据都是**值大=远**，与核心库
`NormalPipeline.DepthMix.max`「各层取最大（近处优先）」的 near=high 约定相反——
max 融合实际选中了远表面：

| 数据 | 主体区均值 | 背景区均值 | 结论 |
|------|-----------|-----------|------|
| sidecar depth16（girl 1787481979） | 0.113 | 0.590 | 值大=远 |
| sidecar depth16（room 1787480336） | 0.002 | 0.338 | 值大=远 |
| DA3 估计器输出（girl 原图） | 0.126 | 0.570 | 值大=远 |
| DA3 估计器输出（room 原图） | 0.002 | 0.356 | 值大=远 |

注意法线也受此影响（当前表面实为「凹陷」着色）；统一反转后法线方向同步翻转，
预期更接近正确观感，验收时需目视确认 shading 无劣化。

任务（按序）：

1. **深度约定统一为 near=high**（绑定层两个生产者入口各一处反转，下游零改动）
   - `ImageDecoding.decodeDepth16`：归一化后 `v = 1 − v`（sidecar 一路）
   - `DA3MonoDepthEstimator.estimateDepth`：百分位稳健归一化后同样 `v = 1 − v`（DA3 一路；
     可在 `vDSP_vsmsa` 直接用 scale=−1/(hi−lo)、shift=hi/(hi−lo) 合并实现）
   - 文档对齐：`DepthTextureStore` 注释写明契约「深度统一 near=high（值大=近）」；
     E 区 harness 不受影响（合成 ramp 自定义语义）；F 区 PNG 必须重新目视——
     少女/苹果（近）应正确压过房间墙面（远）
2. **拖拽实时融合预览**（保持拖拽热路径零 `@Published project` 发布）
   - `RelightBridge`：新增 `liveTileOverride: (id, center)?` + `previewTileMove(_:center:)` /
     `clearTileOverride()`；`makeScene` 应用覆盖（图块中心替换为实时位置）且覆盖期间
     不再排除该图块；`sync()` 清除覆盖（模型提交为权威）
   - `StudioCanvasView`：移除图块拖拽的 `relight.setExcludedTile` 两处调用；
     `publishPreview` 的 `.tile`（canDrag）分支加 `relight.previewTileMove`；
     `onEnded` 调 `clearTileOverride()`（随后的 project 提交走正常 sync 全量重渲）
   - 效果：拖拽中合成以 latest-drop 全量渲染跟随（约一帧延迟，与拖灯重着色同体感），
     描边/徽标仍即时跟随；松开落点即最终融合结果
   - 性能兜底：预览尺寸全量渲染 ~10–20ms（2048² 全链 20ms 实测），latest-drop 不积压；
     深度缩放缓存（tileDepthCache）不受位移影响

验收：

1. 36 项 checks + 33 项 harness 全过（A–G；F 区胜者计数与 diff 断言不应受符号影响）
2. F 区 `/tmp/relight_harness_F_max_twoset.png` 目视：近处主体互相穿插、远背景不再穿透主体
3. 画布目视：两张 raySet 重叠拖灯 shading 无劣化；拖动其中一张时重叠区融合实时跟随
4. M1–M3 回归无退化（含 undo、工程存取、视口、快捷键）；冷启动 8 秒无崩溃

不做：DepthRange 语义变更（滑杆仍是同一窗口重映射，仅物理含义随 near=high 翻转）、
法线强度/模型重训、多路流。

---

## M3.2 · 图块 chrome 降噪（常态无框）

> 执行入口：`docs/m3.2-tile-chrome-declutter-activation-prompt.md`（自包含激活提示词，2026-08-24 固化）

**背景**（2026-08-24 用户 M3.1 验收反馈）：图块的描边、名称、depth 徽标、depth range
行在**任何状态下**都叠加在图像上（`CanvasRenderer.drawTiles` 常态也画 0.35 白描边 +
三行文字），看图时视觉噪音大。要求：图像边缘在没有选中、没有鼠标悬浮时**没有框**，
除非有特殊需求。

**现状**（`RayDepthStudioUI/Sources/RayDepthStudioUI/CanvasRenderer.swift` drawTiles 内）：

- 描边：常画（选中白 2.5 / hover 0.85×1.5 / 常态 0.35×1）
- 名称 + depthKind 徽标（黑 capsule 底）+ depth range 行：常画，垂直居中三行
- hover 反馈：淡白 0.12 叠加（有图与合成内图块均有）+ 触觉反馈（StudioCanvasView）

任务（按序）：

1. **常态（未选中且未 hover）**：不画描边、不画名称/徽标/depth range 行，图像干净显示
2. **hover**：细描边（沿用 0.85×1.5）+ 淡白高亮（现状保留）；是否同时显示名称/徽标
   取最小改动——只恢复描边即可，文字仍只在选中态出现
3. **选中 / 拖拽中**：粗描边（白 2.5）+ 名称 + 徽标 + depth range 行（现状全量信息）
4. **特殊需求例外**：无图占位图块（纯色块）常态保留名称 + 徽标——无图像可辨时
   文字是唯一身份信息；有图图块不适用任何例外
5. 图层隔离命中、两段式交互（hover → 点击选中 → 选中后才可拖动）、重光照合成底图
   均不受影响（合成里本来就没有 chrome）

验收：

1. 36 项 checks + 33 项 harness 全过（纯 UI 绘制改动，预期零影响）
2. 画布目视三态：常态图像无框无文字；hover 出细框；选中出粗框 + 全量信息；
   无图占位块常态仍可见名称/徽标
3. M1–M3.1 回归无退化（含拖拽实时融合预览、undo、视口、快捷键）；冷启动 8 秒无崩溃

不做：光源 gizmo 降噪（另行评估）、检查器/顶栏布局改动、chrome 配色主题化。

---

## M3.3 · 项目文档体系 + MCP 基座 + Metal FX 实时编辑（优先于 M4）

> 执行入口：`docs/m3.3-docs-mcp-metalfx-activation-prompt.md`（自包含激活提示词，2026-08-24 固化）

**背景**（2026-08-24 用户 M3.2 验收后指令）：下一步 = 项目文档优化 + MCP 支持 +
Metal FX 导入与 Metal 代码实时编辑+显示。要求与 M4 及以后融洽，并把
「深度 cut 方向反」类低级退化的防线制度化（M3.2 验收期曾发生旧二进制误判事故：
桌面 0.3.0-m3 包无 M3.1 修复被当成新构建验收）。M3.5 交付后用户指示：MCP 适配
尽快上，本阶段任务 3（MCP 基座）优先。

任务（按序）：

1. **防退化基座**（小改动，先行）
   - 一键验证脚本（核心库 `Scripts/verify.sh`）：40 项 checks + 35 项 harness 串联，任一失败即非零退出
   - 版本戳：app 窗口标题带版本号与构建日期（如 `RayDepthStudio · 0.3.3-m3.3 (2026-08-25)`），
     构建脚本自动写入 Info.plist——杜绝「拿旧包验收」误判
   - 验收纪律补进贯穿约束：只验收当次构建的包；深度数据任何新生产者入口必须显式
     处理 near=high 方向并在 harness 加守门断言
2. **项目文档优化**
   - 核心库 README 更新到 M3.3 现状（里程碑、40 checks、结构树、MCP/FX 指针）
   - `docs/README.md` 索引：roadmap、全部激活提示词、文档审查记录、MCP 文档（任务 3 产出）
   - 两个 repo 补 `AGENTS.md`：构建/验证命令、架构红线（拖拽热路径零发布、单 Canvas、
     两段式交互、near=high 契约）、目录导览——任何 agent 进场可读
   - 文档失配审查例行化：每里程碑收尾按 `documentation-review-2026-08-24.md` 格式复查一次
3. **MCP 基座**（UI 包新 target `RayDepthMCP`，零第三方依赖，Apple 框架手写）
   - 传输：Streamable HTTP（`NWListener`，localhost，默认端口 8377 可配，仅绑 127.0.0.1）；
     GUI 进程不嵌 stdio。协议：MCP JSON-RPC 2.0 最小实现（initialize / tools/list / tools/call）
   - 首波 tools：**只读优先**；写操作一律经 `StudioViewModel` 既有通道提交（自动入 undo、
     触发 relight sync），禁止旁路直改模型
     - `project.get` / `project.open` / `project.save`（.raydepth 往返）
     - `canvas.listTiles` / `tile.select` / `tile.move`（走 undo 栈的单次提交）
     - `source.importImage`（fileURL → 指定图层，含 sidecar 探测）
     - `relight.setLight` / `relight.setMix` / `relight.setDepthRange`
     - `export.png`（同渲染链全分辨率）
     - `fx.list` / `fx.reload`（任务 4 落地后启用）
   - skills 文档：核心库 `docs/mcp/` 每 tool 一页（参数契约、返回结构、失败模式）+
     总览 skill `raydepth-mcp`（连接方式、调用示例、排障）；M5 算子文档同目录扩展
4. **Metal FX 导入 + 实时编辑显示**
   - 绑定层 `MetalFXEngine`（新 target 或并入 `RayDepthRelight`，取最小改动）：plane FX
     shader 渲染到离屏 MTLTexture → albedo `CGImage`（`generatesDepth` 时同时出深度）→
     接 `ImageStore` / `DepthTextureStore`，帧更新走 DragPreview 式独立通道，零 `@Published project` 发布
   - FX 库目录（用户目录 `~/Library/Application Support/RayDepthStudio/FX/` + 内置示例）：
     一个 `.metal` 文件 = 一个 FX，文件名 ↔ `MetalFXSource.PlaneFX.shaderName`
     （核心库该字段已存在且 Codable，零 API 变更）；「添加输入源」菜单启用 MetalFX 项
   - 实时编辑器：FX 面板（NSTextView 代码编辑，保存/防抖自动重编译
     `MTLDevice.makeLibrary(source:)`）；编译成功热替换，失败保留上一可用版本 +
     行号错误横幅；编辑器不阻塞画布渲染
   - 深度契约：FX 深度输出一律 near=high（值大=近），内置模板 shader 注释写明，
     引擎**不做**隐式反转；harness 新增 FX 深度方向守门断言
   - 内置示例 FX ×3：gradient、checker、wave-heightfield（最后一个 generatesDepth，
     验证 FX 深度参与 max 融合）

验收：

1. `Scripts/verify.sh` 一键 40+35 全过；窗口标题可见版本戳
2. MCP 无头冒烟脚本全过：initialize → tools/list → importImage → listTiles 可见 →
   setMix/setDepthRange → export.png 出图像素正确 → project.save/open 往返
3. Metal FX：wave-heightfield 入画布参与重光照与 max 深度融合（方向正确）；
   编辑器改代码保存 ≤1s 热更；注入语法错误出行号提示且画面不崩（保留上一可用版）
4. 文档：docs/README 索引完整、双 README 与现状一致、两 repo AGENTS.md 齐备
5. M1–M3.2 + M3.5 回归无退化（含拖拽实时融合预览、undo、工程存取、视口、快捷键、
   光源 gizmo 显隐/锁定/跟随）；冷启动 8 秒无崩溃

不做：stdio MCP、MCP resources/prompts、particle3D FX（核心字段已备，实现留 M5 后）、
AI 算子（M5）、合成主链 Metal 化（M4 任务 4，与 MetalFXEngine 共用设备/队列时统一设计）。

---

## M3.4 · 检查器数值控件与颜色选择增强

> 执行入口：`docs/m3.4-inspector-controls-activation-prompt.md`（自包含激活提示词，2026-08-24 固化）

**背景**（2026-08-24 用户指令，附检查器截图）：①depth 的 min/max 滑杆取值范围太窄
（0...1），M3.1 后 remap 不裁剪、超出 [0,1] 有物理意义但拖不到；每个 slider 旁要
value reset 按钮。②颜色格式支持仿 Xcode asset 颜色选项：经典 HSV、点击铅笔（吸管）
选颜色、调色板，可切换。现状（M3.6 并入后实况）：`InspectorView.swift` depth 区
（`depthSection` :176，Min/Max `0...1`、强度 `0...3`、窗口可视化胶囊按 [0,1] 域计算）
与光源 Color 区（:304，R/G/B `0...1` 三滑杆 + 预览条）。
**M3.6 本地化基座已并入**：新增用户可见文案一律 `String(localized:)` 禁拼接、
xcstrings 同步 en、术语表 `docs/ui-copy-glossary.md` 白名单不译。
**版本戳**：`BuildStamp.swift` 改 `0.3.4-m3.4` 后跑 `Scripts/build-app.sh`；
桌面现存 0.3.6-m3.6 包为 M3.6 会话先行部署（里程碑乱序），覆盖前向用户确认。

任务（按序）：

1. **Depth Range 滑杆扩域 + 全部滑杆 value reset**
   - Min/Max 滑杆域 `0...1` → **`-1...2`**（超出 [0,1] = 整体推拉深度窗口，与
     [0,1]→[min,max] 线性 remap 语义一致）；强度维持 `0...3`
   - `SliderRow` 组件增加可选 reset：行右侧小按钮（`arrow.counterclockwise`），点击
     重置为该参数默认值（min→0、max→1、depth 强度→1；光源强度/半径/RGB 同机制，
     默认值取核心库模型默认）——一处组件改动全检查器生效，reset 走既有 onChange
     提交通道（单次提交入 undo 栈）
   - 窗口可视化胶囊条：显示域随滑杆域改按 [-1,2] 线性映射（原按 [0,1] 算
     offset/width，扩域后会画错）
2. **颜色选择增强**（光源 Color 区，仿 Xcode asset 颜色选项）
   - 模式切换 segmented：**RGB**（现状 0–1 三滑杆）/ **HSV**（H `0...360`、S `0...1`、
     V `0...1`）；HSV↔RGB 换算在 UI 层，存储仍 `LightSource.colorRGB`（核心零改动）；
     切换模式为视图本地 @State
   - 吸管取色：`NSColorSampler` 按钮（铅笔/吸管图标），取屏幕任意颜色回写
   - 调色板：预览条改可点击色块（NSColorWell 桥接或 Button + `NSColorPanel`），
     系统调色板/swatches 选择回写
   - 三入口共用既有 onRed/onGreen/onBlue 提交通道

验收：

1. `Scripts/verify.sh` 一键 40 项 checks + 45 项 harness 全过（纯 UI 改动，预期零影响）
2. 目视：min 拖到 −0.5 / max 拖到 1.5 深度窗口推拉正确、可视化胶囊不画错；每个
   reset 一键回默认；HSV↔RGB 切换数值互洽；吸管取屏色生效；调色板选择生效
3. 双语抽查：en 环境下新增文案（reset/HSV/吸管/调色板）无白名单外中文残留
4. M1–M3.5 + M3.3 + M3.6 回归无退化（含 undo——reset/取色均可撤销）；冷启动 8 秒无崩溃

不做：色域（sRGB/Display P3）管理、图块占位色选择、检查器布局重构。

---

## M3.5 · 光源 gizmo 显隐与锁定/跟随

> 执行入口：`docs/m3.5-light-gizmo-visibility-lock-follow-activation-prompt.md`（自包含激活提示词，2026-08-24 固化）

**背景**（2026-08-24 用户指令）：光源 debug 圆点需要可以隐藏；单独的光源需要两种
额外设置——①锁定（隐藏 debug 圆点）②锁定时随鼠标移动（随鼠标移动的最多只有一个
光源）。现状：全局 `lightsLocked`（ViewModel @Published 视图态，顶栏锁按钮，仅门控
depth 页签光源交互）；`LightSource` 无锁定/跟随字段（合成 Codable）；gizmo 常画
（`CanvasRenderer.drawLights`：圆点 + 半径环 + 预览光晕 + 选中 halo）；空白处拖拽 =
移动主光源；checks 有「鼠标控制主光源位置」项。

任务（按序）：

1. **核心库 additive 字段**（用户直接指令视为获批；纯增量不改既有行为）
   - `LightSource` += `isLocked: Bool = false`、`followsMouse: Bool = false`
   - Codable 向后兼容：自定义 `init(from:)` 用 `decodeIfPresent ?? false`（旧
     project.json 无此键必须能加载）；harness G 区加两字段往返断言
   - `LightingRig` += `mutating func setFollowsMouse(_ id: UUID, _ on: Bool)`：
     开启时清除其他灯的 followsMouse（**最多一个**的约束放核心，checks 加断言）
2. **全局 gizmo 显隐**：顶栏眼睛开关 `lightsGizmosHidden`（视图态，同 lightsLocked
   一级）；隐藏时 `drawLights` 全部 gizmo 不画且光源不可命中（看不见的可点区域是陷阱）；
   合成光照效果不受影响（gizmo 是纯 chrome）
3. **单灯锁定**：锁定的灯 gizmo（圆点/环/预览光晕/选中 halo）不画、`hitTestLight`
   跳过、不可选中/拖动；检查器 Light 区加「锁定（隐藏圆点）」toggle；
   既有选中态若被锁定则清除选中
4. **锁定灯随鼠标移动**：检查器加「随鼠标移动」toggle，仅 `isLocked` 时可开
   （未锁定时 disabled）；开启走 `setFollowsMouse`（核心保证唯一）。鼠标在画布移动
   （无拖拽）时该灯位置实时跟随：mouseMoved（现有 hover 监视链路）换算画布坐标 →
   **DragPreview 式预览通道**驱动实时重着色，跟随期间零 `@Published project` 提交；
   结束跟随（toggle 关 / 选中他灯 / 切页签）时一次性提交最终位置入 undo 栈

验收：

1. 36 项 checks（含 setFollowsMouse 唯一性新断言）+ 33 项 harness（含 G 区新字段往返）全过
2. 目视：眼睛开关全局藏/显 gizmo；单灯锁定后圆点消失且拖不到；锁定灯开跟随后鼠标
   划过画布光照实时跟随、全程无 gizmo；关跟随一键提交可 undo；两灯不能同时跟随
   （开第二个自动关第一个）
3. M1–M3.4 回归无退化（含拖拽实时融合预览、undo、工程存取——旧工程无新字段可开）；
   冷启动 8 秒无崩溃

不做：gizmo 配色主题化、非锁定灯跟随、跟随路径记录/动画。

---

## M3.6 · 界面文案与本地化（排于 M3.3 后、M4 前）

> 执行入口：`docs/m3.6-ui-copy-localization-activation-prompt.md`（自包含激活提示词，2026-08-24 固化，含全文案清单）

**背景**（2026-08-24 用户指令）：界面文案全是硬编码中文、中英混排无规则、零本地化基础。要求文案制度化并做 zh-Hans / en 双语，为 M5 社区开放与公开 repo 形象打底。

任务（按序）：

1. **文案盘点与术语表**：全量盘点用户可见字符串（激活提示词附现状清单）；术语表落 `docs/ui-copy-glossary.md`；不译白名单（页签五名、depth/normal/gizmo/MetalFX/raySet/Phokos/DA3/sidecar/NDI/Syphon）
2. **本地化基座**：`Package.swift` 加 `defaultLocalization: "zh-Hans"` + target resources；`Localizable.xcstrings`（source zh-Hans，目标 en）；全部用户可见字符串收敛，插值一律显式 `String(localized:)`（禁止字符串拼接，en 语序必错）
3. **文案统一**：错误信息统一「<动作>失败：<原因>」；同一概念唯一译法
4. **双语运行验证**：en 环境五屏 + 错误态白名单外零中文；zh-Hans 与现状逐屏一致
5. **部署**：`Scripts/build-app.sh` 出 `0.3.6-m3.6` 版本戳包，重建桌面失效的 .app

验收：40 项 checks + 35 项 harness 全过；en/zh-Hans 双环境核对通过；术语一致、插值语序正确；M1–M3.5 回归无退化；冷启动 8 秒无崩溃。

不做：其他语言、系统级菜单、动态语言切换设置页、MCP/FX 编辑器 UI 文案（M3.3 沿用本基座）。

---

## M3.7 · 图块重命名 + 灯光跟随状态保持热修（排于 M4 前）

> 执行入口：`docs/m3.7-tile-rename-follow-persist-activation-prompt.md`（自包含激活提示词，2026-08-24 固化）

**背景**（2026-08-24 用户 M3.4 验收后指令，两条）：

1. **图片需要可重命名**。现状：图块名称 = 输入源 `InputSource.name`（导入时取文件名去扩展名），检查器 header（`InspectorView.swift` `TileInspectorContent.header`）与左面板行（`LayerPanelView.swift:52`）均只读显示。核心 `InputSource.name` 是 `var { get set }`，但 `StudioProject.sources` 为 `public internal(set)`（existential 字典），UI 无改名通道。
2. **bug：灯光跟随鼠标时，点击其他页签或其他光源会丢失跟随状态**。确诊（M3.5 两处有意设计的自动结束点，用户现认定为 bug）：`StudioViewModel.selectedLightID.didSet`（:81-83，选中他灯 → `endLightFollow`）与 `selectTab`（:199，切页签 → `endLightFollow`）。`updateLightFollow` 本身不限页签（hover 链路全页签触发，`StudioCanvasView.swift:127`），移除这两个自动结束点后行为自洽：跟随跨页签、跨选中持续。

任务（按序）：

1. **核心 additive `renameSource`**（用户直接指令视为获批；纯增量不改既有行为）
   - `StudioProject` += `mutating func renameSource(_ id: UUID, to name: String)`：源存在且名称有变化才改；checks 加断言（改名生效 / 不存在 id 空操作 / 图块关联不受影响）
   - Codable 零改动（`name` 已在源信封内，工程存取天然保留）；undo 走既有快照栈天然兼容
2. **ViewModel 通道 + 检查器改名 UI**
   - `StudioViewModel.renameSource(ofTile tileID: UUID, to name: String)`：经 `project` 提交自动入 undo；守卫——trim 后为空不改、未变化不压栈
   - 检查器图块 header 名称点击可编辑：点名称 → TextField（回车提交 / Esc 取消放弃），提交走上述通道；左面板行与画布 chrome 读同一 `sourceName`，随模型自动刷新，零额外改动
   - 新文案走本地化基座（`String(localized:)` 禁拼接、xcstrings 补 en、白名单不译）
3. **跟随状态保持热修**
   - 移除两处自动结束：`selectedLightID.didSet` 的「选中他灯结束跟随」（:81-83）与 `selectTab` 的「切页签结束跟随」（:199）
   - 保留的结束条件不变：检查器 toggle 关、解锁、删除灯、开第二盏跟随（核心唯一性 + `setLightFollowsMouse` :755 先提交第一盏最终位置）、MCP `updateLightParams` 显式关/解锁
   - 效果：跟随跨页签、跨选中持续，鼠标划过任意页签画布均实时跟随（hover 链路现状即全页签触发）；最终位置提交推迟到显式结束点，仍一格 undo
   - 决策点（最小改动）：切 Light 页签的自动选中逻辑（跳过锁定灯）不变；选中他灯后检查器操作他灯与跟随互不干扰
4. **收尾例行**：roadmap 状态行/进度日志 + skill 当前阶段；`BuildStamp.swift` 改 `0.3.7-m3.7` 后跑 `Scripts/build-app.sh`（桌面现存 0.3.4-m3.4，版本号递增，直接覆盖）

验收：

1. `Scripts/verify.sh` 一键（40+新增 checks + 45 harness）全过
2. 目视：检查器点名称改名，回车生效、Esc 取消；左面板与画布 chrome 名称同步刷新；改名可 undo；工程保存→重开名称保留
3. 目视：开跟随后切页签、点选其他灯/图块，跟随不丢、光照实时跟随；toggle 关/解锁仍正常结束并提交最终位置（可 undo）；两灯跟随唯一性不变（开第二盏自动结束第一盏）
4. en 环境新文案无白名单外中文残留；M1–M3.6 回归无退化；冷启动 8 秒无崩溃

不做：光源重命名 UI（MCP `updateLightParams` 已有 name 通道，UI 入口另议）、左面板行内改名、MCP rename tool、批量改名。

---

## M4 · 实时源与性能

> 执行入口：`docs/m4-realtime-performance-activation-prompt.md`（自包含激活提示词，2026-08-24 固化）

**目标**：活源接入 + 大工程流畅。

任务：

1. Camera 输入（AVFoundation 绑定层实现 `nextFrame()`）
2. NDI / Syphon 帧流（复用 RayRelightNDI 接收代码；NDI SDK 是唯一允许的新外部依赖）
3. `StreamDepth` stride 调度 + 估计器内 EMA 平滑落地
4. 合成渲染 Metal 化（MTKView 替换 SwiftUI Canvas 合成层；交互层保留 SwiftUI）

验收：一路 camera + stream depth 稳定 30fps；记录 CPU/GPU/内存基线写进 docs。

> M3.3 衔接：camera/NDI/Syphon 源接入后，对应控制面（源增删、stride 参数）补进 MCP tools；
> 合成主链 Metal 化与 M3.3 `MetalFXEngine` 统一共用 MTLDevice/队列设计，避免两套 Metal 栈。

---

## M5 · AI 算子经 MCP 开放（SAM3 / BiRefNet / DA 深度重绘）

**目标**：把本机已有 AI 能力封装成绑定层算子，经 MCP 对 agent 开放，每个算子配 skill 文档。

任务：

1. 绑定层新 target `RayDepthOps`（CoreML，模型资产复用本机已有：flux-klein MCP 的
   SAM3 / BiRefNet、da3_bench 的 DA3 系列；离线加载，算子无状态化便于并发与测试）
2. 三个首波算子 + MCP tools：
   - `ops.segment`：SAM3 文本提示分割 → mask → 选区/新图块（mask 可作深度约束输入）
   - `ops.matte`：BiRefNet 显著主体抠图 → 透明 PNG 入层（接 `source.importImage` 通道）
   - `ops.depthRepaint`：DA 模型深度重绘/修复 → 替换/生成 sidecar depth16（16bit 灰度）
3. 深度契约守门：所有深度类算子输出一律 near=high，算子出口统一校验方向
   （主体/背景统计启发式 + harness 守门断言），不合格即报错不落地——
   M3.1/M3.2 教训的制度化处理
4. 算子 skills 文档：`docs/mcp/ops-*.md` 每算子一页（参数契约、输入尺寸限制、
   失败模式、耗时基线）+ 总览 skill 登记

验收：三算子端到端（MCP 调用 → 画布可见结果）；harness 新增算子 smoke（小图离线推理 +
深度方向断言）；36+33 回归全过。

不做：模型训练/微调、在线模型下载、算子批处理管线。

---

## M6 · 架构重构与社区插件化（distant）

**目标**：代码结构可复用性重构 + 社区插件支持，文档先行。

任务：

1. 绑定层协议化整理：`DepthEstimating` / FX 引擎 / AI 算子统一为插件协议（发现、
   生命周期、能力声明）；核心库保持纯值语义不动
2. 插件包格式 `.raydepthplugin`（manifest.json + .metal / .mlmodelc / 资源）+ 加载器 +
   信任策略（默认仅用户显式启用目录）
3. 社区文档：插件开发指南（含 near=high 契约、独立通道刷新规约）、API 稳定性承诺、
   示例插件仓库模板
4. 重构伴随：RayDepthRelight / RayDepthMCP / RayDepthOps 边界梳理，重复工具下沉

验收：第三方视角仅按文档能写出可加载插件（示例插件实测）；全部历史验收项回归。

不做：插件市场/分发平台、签名公证体系（社区有需求再议）。

---

## 贯穿约束（每阶段硬门槛）

- `swift run raydepth-checks` 40 项全过；核心库 API 变更须先停下报告，获批才动
- macOS 13+、Swift 5.9、不用 macOS 14 才有的 API；无第三方依赖（M4 NDI SDK 除外）
- 拖拽热路径零 `@Published` 发布的架构不许回退（新功能刷新走 DragPreview 式独立通道）
- 深度数据契约 **near=high（值大=近）**：任何新生产者入口（sidecar / 估计器 / FX / AI 算子）
  必须显式处理方向并在 harness 加守门断言——M3.1 方向事故、M3.2 验收期旧包误判的制度化防线
- 每次交付部署带版本戳的新构建包（窗口标题可见版本）；验收只认当次构建的包，不验收残留旧包
- 每阶段结束：更新本文「状态」行 + skill 里的当前阶段，再交付

## 进度日志

- 2026-08-23 · M0 完成：UI 示例交互定型（hover 高亮 + 触觉反馈 + 选中后才可拖动；五页签；光源一等公民）
- 2026-08-23 · M1 完成：真图进、真图出。UI 层新增 `ImageStore`（按 sourceID 缓存、4096px 上限异步缩略解码）与 `ProjectExporter`（独立合成，zIndex 升序 → CGContext → PNG）；左面板「打开图片…」（NSOpenPanel 多选）+ 画布 onDrop（fileURL）；Source 层导入自动探测 `*_depth.png` sidecar；顶栏「导出 PNG」+ 尺寸输入（默认 2048，256–8192）；`seedDemo()` 改空工程 + 两盏默认灯，/tmp 假路径全清。核心库零改动。
  - 验收：36 项 checks 全过；UI build 通过零告警；冷启动 8s+ 无崩溃；截图确认空工程 + 双灯 + 新按钮渲染正常；导出合成方向经独立 harness 像素级验证（图块位置/内容方向均正确）
  - 遗留：人工抽查一次——打开 ≥3 张真实照片（含 >20MP 大图）跨图层摆版 + 实际存出一张 PNG 目视比对
- 2026-08-23 · M1.5 规划（Phokos 历史导入）：数据源格式已探明（`outputs/.history_tree.json` v2/v1、image/raySet 两类节点、depth16 = 16bit 灰度深度），施工方案见 M1.5 节，待激活
- 2026-08-23 · M1.5 完成：Phokos 历史批量导入。UI 层新增 `PhokosImporter.swift`（纯 Foundation 解析器：v2/v1 元数据、散兵 depth 三元组归组兜底对齐 migrateLooseDepthFiles、orphan set 丢弃、悬空边当根、绝对路径 original、ai 缺失时 mcp_ 前缀兜底）与 `PhokosImportView.swift`（sheet：OutlineGroup 树 + 惰性缩略图 + ★/AI 徽标 + 多选 + 包含子树开关 + Static/Source 分布实时统计；⌘↩ 导入 / Esc 取消）；顶栏加 Phokos 按钮；`StudioViewModel.importFromPhokos` 按 DFS 前序落画布（x=140+depth×260，y=120+row×260，zIndex 递增）。核心库零改动。
  - 验收：解析 harness（swiftc 独立编译，24 项断言：真实数据 + v1/悬空边/orphan set/绝对路径 original/ai 缺失/三元组归组/空目录）全过，通过后 scratch 已删；36 项 checks 全过；UI build 零告警；冷启动 8s+ 无崩溃；真实导入 37 节点（Static 31 张 / Source 6 组）秒级完成，raySet 全部带 `*_depth16.png` sidecar 进 Source 层（fromResource），布局坐标抽查与公式一致；二次导入 37 项全部去重跳过
  - 实现期偏差（已修）：初版去重只按 fileURL，raySet 的 original 与其 image 节点撞键导致 6 个 raySet 全被跳过 → 改为 fileURL+目标图层+sidecar 组合键；面板按钮补 ⌘↩/Esc 快捷键（sheet 内合成鼠标事件不可达时的标准替代，也是常规 UX）
  - 遗留：「与 Phokos app 历史页目视一致」未经人工比对（树结构已与 .history_tree.json 原始数据逐项核对）；M1 人工回归项（打开图片/拖拽/导出）未重跑——M1.5 未触碰这些代码路径
- 2026-08-24 · M1.5 交付物落地：新二进制打包进 `~/Desktop/RayDepthStudioUI.app`（版本号 0.1.0-m1.5），冒烟通过（.app 冷启动正常，用户实测选中+子树导入路径可用）；M2 激活提示词固化到 `docs/m2-relighting-activation-prompt.md` 并在 M2 节登记入口
- 2026-08-24 · M2 完成：深度重光照（核心价值）落地。UI 包新增 library target `RayDepthRelight`（绑定层，核心库零改动）：`DepthTextureStore`（TextureRef.id → 像素，sidecar 16bit 惰性解码换缓存）、`ImageDecoding`（缩略图 + 16bit 灰度→归一化浮点）、`DA3MonoDepthEstimator`（DepthEstimating 协议实现，预处理/后处理移植自 RayRelightNDI DepthEstimator，与 NDI 帧解耦改从纹理仓库取 CGImage；模型按 DA3MonoLarge.mlmodelc → _int8 → .mlpackage 候选加载）、`RelightKernels`（CIKL 自定义内核 ×2：depth→normal 中央差分、normal+lights→Blinn-Phong 着色，光源参数打 8×3 RGBAf 纹理，衰减/ACES/gamma 与 RayRelight 一致）、`RelightCompositor`（各图块深度 DepthRange 重映射 → mix 混合整幅深度 → CIBoxBlur×2 → normal → 着色 → CIRadialGradient+CIAdditionCompositing glowing 后处理；shade-only 通道复用 artifacts 供拖灯实时）。常驻验证 target `relight-harness`（23 项断言）。UI 层新增 `RelightBridge`（独立通道：全量渲染串行后台 latest-drop，拖灯仅重着色，图块拖拽期从合成排除、松手回归；DA3 后台惰性加载完成自动重渲）；`CanvasRenderer` 画重光照合成底图（1:1 不拉伸）+ 拖拽图块未重光照跟随位图；导入路径把 sidecar 接到 `ResourceDepth.resource`；导出走同渲染链全分辨率（后台渲染 + NSSavePanel，CoreImage 不可用时回退 M1 合成）。
  - 等深轮廓颜色处理（用户指令，默认启用）：max / weightedMean 混合时深度胜者与 zOrder 颜色胜者可能不一致，等深轮廓（|Δd| ≤ ε=0.015）颜色打架——这些像素改取并列图块 RGB 平均（zOrderTop 同胜者，不触发，M1 视觉行为不变）
  - 验收：36 项 checks 全过（核心库零改动）；harness 23 项全过——sidecar 经 ResourceDepth 出图无错误、灯位 A/B 平均像素差 27.97、depth range 差 12.69、sidecar 缺失报 resourceDepthMissing 不崩溃、DA3 估计出图（推理 41ms release）+ StaticDepth 缓存/invalidate 语义、**2048×2048 全链渲染 20ms（release，要求 <3s）**、max/weightedMean 等深混合 1536/65536 像素、zOrderTop 零触发；输出 PNG 目视确认（方向、光位、轮廓混合缝正确）；UI build 零告警（CIKL `CIKernel(source:)` 弃用告警 ×2 除外——plan 指定 CoreImage 首选，实测可用未触发 Metal 降级）；冷启动 12s 无崩溃、离屏截图确认重光照合成（glow）在画布生效
  - 实现期偏差（已修）：①合成底图曾按视图矩形拉伸（视图非方形、合成是方形）→ 改 1:1 绘制；②onResult 同值重复赋值 lastError 会经 objectWillChange 触发重渲死循环 → 加变更守卫；③StaticDepth 首帧估计有缓存语义，颜色图未解码时跳过本轮（解码完成触发重渲），防止占位图深度固化进缓存
  - 已知限制：单 pass 上限 8 盏灯（超出报 droppedLights）；预览按 1× point 渲染（Retina 下略软，换流畅度）；weightedMean 的颜色平均覆盖整个重叠区（等值语义的自然延伸）
  - 遗留（人工）：Static 层人像拖灯实时性（≥30fps 主观）与滑杆跟手度实测；M1（打开图片/拖拽/导出 PNG 目视）与 M1.5（Phokos 导入）人工回归——本次未改动这些交互路径，harness 已覆盖导出合成
- 2026-08-24 · M2 交付物落地：新二进制打包进 `~/Desktop/RayDepthStudioUI.app`（版本号 0.2.0-m2），冒烟通过（.app 冷启动窗口正常）；同日应用户要求把 UI 工程从 `~/Desktop` 迁入主工作目录 `~/Documents/kimi/workspace/RayDepthStudioUI` 防误删（path 依赖改为 `../RayDepthStudio`，全量重建 + harness 23 项复跑全过），roadmap 与 skill 路径引用已同步
- 2026-08-24 · M2 用户验收反馈：两张 fromResource 图块重叠时深度未真正融合（zOrderTop 画家算法 + max 模式颜色不随深度胜者）→ 修正方案移入 M3 任务 1；M3 激活提示词固化到 `docs/m3-completeness-activation-prompt.md` 并在 M3 节登记入口
- 2026-08-24 · M3 完成：编辑器完备性落地。
  - **任务 1 深度融合修正**（`RelightCompositor`）：max 模式逐像素深度最大值，**颜色跟随深度胜者**——重叠区单胜者像素（tieMask 恰 1 位且贡献者数 >1）用胜者图块颜色改写画家算法底色（`winnerPixels` 计数），等深并列维持 RGB 平均（M2 tieMask 机制上扩展）；counts 由覆盖标记改为真实贡献者计数；zOrderTop 零改动（M1 视觉回归）；顶栏 normal 状态改按钮循环切换 mix（zOrderTop→max→weightedMean），`seedDemo` 默认 `.max`。harness E 区扩至 8 项（胜者改写覆盖重叠区 32000px、左蓝右红采样断言、zOrderTop 双零触发）+ 新增 F 区真实双 raySet（depth_1787480336 × depth_1787481979）重叠用例：胜者改写 160724px、等深平均、max vs zOrderTop 像素差 2.83，PNG 目视确认互相穿插
  - **任务 2 undo/redo**：`StudioViewModel` 快照栈（`project` didSet 压栈，纯值类型 COW 近零成本），栈深 50，`withSingleUndo` 合并多连写（Cmd+D 四连写一格），seedDemo/工程加载不入栈，撤销重做后清理悬空选中；Cmd+Z / Shift+Cmd+Z（App `.commands` 替换 undoRedo 组）
  - **任务 3 工程持久化**：核心库 plan 批准的 Codable 化——新文件 `Studio/ProjectCodable.swift`（5 源信封 + DepthProcessing 信封 + userInfo 相对路径约定；运行时句柄不持久化），值类型声明加 Codable（Canvas/SquareTile/LightSource/LightingRig/NormalPipeline/MetalFXSource.Effect 等），`sources` setter 放宽 internal（公开 API 不变）；UI 新增 `ProjectDocument.swift`（.raydepth 文档包 = project.json + assets/，资产拷包、相对引用、同名加序号）；Cmd+S / Cmd+Shift+S / Cmd+O（saveItem 组）；`RelightCompositor` 侧 sidecar 自愈（resource 未恢复时按 sidecarDepthURL 惰性重注册 + 按路径去重）
  - **任务 4 视口**：`ViewportTransform`（画布层唯一坐标转换点，CanvasRenderer 入口统一 translate+scale）；滚轮/触控板捏合缩放（`ViewportEventCatcher`：NSView + 局部监视器，光标锚点，0.1–8×）；空格拖拽平移（keyCode 49 监视器，文本编辑不劫持）；拖拽位移按 viewScale 换算画布坐标、光源热区按缩放换算——纯本地 @State，零模型发布、不触发重渲
  - **任务 5 快捷键**：局部 keyDown 监视器（非按钮 key equivalent，文本框编辑不劫持）：Delete/前向 Delete 删选中（图块优先）、Cmd+D 复制图块（源按值复制新 id、副本偏移 24pt 置顶选中）、方向键微移 1pt / Shift 10pt
  - **任务 6 网格/吸附开关进顶栏**：grid 图标切 `vm.showGrid`（100pt 网格，CanvasRenderer 画布坐标绘制、线宽随缩放换算），magnet 图标切 `project.canvas.snap.isEnabled`
  - **任务 7 文档修复**（documentation-review-2026-08-24 失配 5 项）：核心 README 重写至 M2 现状（36 checks、完整结构树、绑定层/harness/docs 索引）；UI 包补 README（三 target、命令、与核心库关系）；3 处头注释对齐 M2（ProjectExporter 兜底定位、CanvasRenderer 合成底图+视口、StudioCanvasView 重光照触发链）；ui-optimization-plan 与 m2 激活提示词加路径迁移注记；`[instrument]` 插桩拆除
  - 验收：36 项 checks 全过；harness 33 项全过（A–G 区，G 区 = 持久化往返 7 项：相对路径编码/画布/灯光管线/注册表/绝对解析/kind 保留/类别信封）；ProjectDocument 真实落盘往返 scratch CLI 8 项全过（.raydepth 结构 + 状态完全恢复，含 mix=max、glowing、zIndex、深度范围）；**undo 无头实测 14 项全过**（20 步混合操作逐步撤销回基线、逐步重做精确恢复、栈深 50 截断正确、拖拽一格、seedDemo 不入栈、新提交清重做栈）——scratch 为 UI 全量源（除 App 入口）+ 核心 + RayDepthRelight 模块直编 CLI，通过后已删；UI release build 通过；.app（0.3.0-m3）冷启动 8s 无崩溃、窗口创建确认（CGWindowList）
  - 实现期偏差（已修）：①seedDemo 在 init 内修改 project 会触发 didSet 压栈（init 完成后调用的方法内赋值触发观察者）→ init 内 isRestoringHistory 守卫；②duplicate 四连写产生 4 格 undo → withSingleUndo 合并；③G1 断言漏算 Foundation JSONEncoder 把 `/` 转义为 `\/`
  - 遗留（人工，本环境无屏幕录制/AX 权限无法驱动 GUI）：视口缩放/平移手感、网格与吸附切换目视、顶栏 mix 按钮点击、NSSavePanel/NSOpenPanel 实际存取、Delete/Cmd+D/方向键真实按键流（逻辑已无头验证）、M1（打开图片/拖拽/导出 PNG 目视）与 M1.5（Phokos 导入）人工回归——未改动这些交互路径；M2 拖灯主观流畅度沿袭 M2 遗留
  - 已知小怪癖：tie 像素 blendedPixels 按贡献者循环计数会双计（M2 既有，仅报告值）；缩放后重光照合成仍按 1× point 渲染（放大略软，M2 既定取舍）；窗口标题仍为「UI 示例」（未动）
- 2026-08-24 · M3 交付物落地：新二进制打包进 `~/Desktop/RayDepthStudioUI.app`（版本号 0.3.0-m3），冒烟通过（窗口正常）；M4 激活提示词固化到 `docs/m4-realtime-performance-activation-prompt.md` 并在 M4 节登记入口
- 2026-08-24 · M3 用户验收反馈两问题 → **M3.1 热修立项（优先于 M4）**：①depth cut 方向反（Swift scratch 实测确诊：sidecar depth16 与 DA3 输出两路都是值大=远，与核心 max=近处优先约定相反；法线同反）②拖动图块看不到 depth 混合实时效果（M2 拖拽排除合成架构所致）。修复方案见 M3.1 节；激活提示词固化到 `docs/m3.1-depth-fusion-hotfix-activation-prompt.md` 并登记入口；状态行与 skill 当前阶段已同步指向 M3.1
- 2026-08-24 · M3.1 完成：深度约定统一 near=high + 拖拽实时融合预览 + 两项验收回归修复 + 无边画布。核心库零改动。
  - **任务 1 深度约定统一**：`ImageDecoding.decodeDepth16` 归一化后 `vDSP_vsmsa` 反转（scale=−1, shift=1）；`DA3MonoDepthEstimator.estimateDepth` 百分位归一化合并反转（scale=−1/(hi−lo)、shift=hi/(hi−lo)）；`DepthTextureStore` 头注释写明「near=high（值大=近）」契约。下游零改动
  - **任务 2 拖拽实时融合预览**：`RelightBridge` 新增 `liveTileOverride` + `previewTileMove(_:center:)` / `clearTileOverride()`；`makeScene` 应用覆盖且覆盖期间不排除该图块；`sync()` 清除覆盖（模型提交为权威）。`StudioCanvasView` 移除两处 `setExcludedTile`，`publishPreview` 的 `.tile`(canDrag) 分支加 `previewTileMove`，`onEnded` 调 `clearTileOverride()`。零 `@Published project` 发布不变
  - **回归修 1 图像不显示**（用户验收发现，M3.1 移除拖拽排除后暴露）：`imageStore.image(for:)` 唯一触发点是 `CanvasRenderer.tileImage`，只对不在合成内的图块调用——排除机制移除后解码永不触发（此前靠拖一次图偶然触发）。修复：`pushFullRender` 主动对全部图块触发解码，完成经 `onChange(images.count)` 带真图重渲；同时根治了 M2 起「首次导入须拖一次才显示」的潜伏怪癖
  - **回归修 2 光源被方形 cut + 无边画布**（用户验收发现，M3 视口 × M2 合成既有缝隙，被正确着色后的高亮度放大暴露）：合成原固定在画布 (0,0)-(s,s)，视口平移/缩放后硬边切进画面。初版 128pt margin 仍被用户划出边 → 按「要无边画布」指令升级为：合成区域 = 可视区 3 倍（每方向 1 视图余量），渲染分辨率 = 区域 × 视口缩放（恒定 ≈3×视图宽，成本与缩放无关），4096 上限只降采样不露边。`RelightScene` 加 `origin`/`canvasSide`（默认 .zero/size，harness 与导出零改动），`RelightBridge` 发布 `renderedOrigin`/`renderedSide`，`CanvasRenderer` 按区域绘制，`onChange(viewport)` 触发跟随
  - 验收：36 项 checks 全过；harness 33 项全过（F 区胜者改写 160724px 不变，max vs zOrderTop 像素差 2.83→17.14——近处胜者取代顶层，差异放大属预期）；F 区 PNG 目视苹果/少女近处主体互相穿插、远背景不穿透；bridge 无头 scratch 10 项全过（previewTileMove 合成跟随/不排除/sync 清除/clear 回归，通过后已删）；冷启动冒烟窗口正常；GUI 实测两 raySet 图像正常显示、缩小后无合成硬边
  - 实现期偏差（已修）：初版 origin+128pt margin 方案在快速平移/深度缩放下仍露边 → 升级 3× 区域 + 分辨率随缩放（无边画布）；debug 包拖动合成更新慢 → 交付 release 二进制（2048² 全链 19ms）
  - 已知限制：合成区域边界处部分进入的图块深度会被压缩到裁剪矩形（M2 既有 quirk，现边界距可视区 1 个视图宽，仅快速甩动时短暂可见）；深度缩放缓存 tileDepthCache 不受位移影响的结论在 origin 方案下依然成立（缓存键含缩放后尺寸）
  - 遗留（人工）：拖图融合跟手度与拖灯 shading 最终目视确认（release 包已部署 `/tmp/RayDepthStudioUI-m31.app` 供验收）；M1（打开图片/导出 PNG 目视）与 M1.5（Phokos 导入）人工回归沿袭——本次改动未触碰这些路径
- 2026-08-24 · M3.1 追加：DepthRange 语义变更（用户指令，覆盖 M3.1 节「不做 DepthRange 语义变更」）：从「[min,max] 窗口裁剪 + clamp 到 [0,1]」改为「[0,1] → [min,max] 线性重映射、零裁剪」，`v' = (v × (max−min) + min) × intensity`。核心 `DepthRange.remap`（行为变更，用户直接指令视为获批）+ 合成器 `scaledDepth`（去掉 vclip 与 span≤0 清零分支）+ checks 断言同步更新（36 项全过：remap(0.1)=0.39 / remap(0.9)=1.11 / 端点 0→0.2、1→0.8 不裁剪）；默认 DepthRange(0,1,1) 为恒等映射，harness 33 项全过无回归
- 2026-08-24 · M3.1 验收反馈 → **M3.2 立项（优先于 M4）**：图块描边与名称/徽标/depth range 行常态也叠加在图像上，视觉噪音大。要求常态无框无文字、hover/选中/拖拽才显示、无图占位块例外保留身份信息。修复方案见 M3.2 节；激活提示词固化到 `docs/m3.2-tile-chrome-declutter-activation-prompt.md` 并登记入口；状态行与 skill 当前阶段已同步指向 M3.2
- 2026-08-24 · 文档注释系统审查归档 `docs/documentation-review-2026-08-24.md`：代码内注释规范度高；失配 5 项（核心库 README 停在 M0、UI 包无 README、M2 后头注释 3 处、历史文档旧路径、临时插桩未拆）→ 修复建议待执行（可并入 M3 或单独小改）
- 2026-08-24 · M3.2 完成：图块 chrome 降噪。改动集中在 `CanvasRenderer.drawTiles`（+文件头注释同步）：常态（未选中且未 hover）不画描边与任何文字；hover 仅细描边（0.85×1.5）+ 既有淡白 0.12 高亮，文字仍只在选中态出现；选中/拖拽中（拖拽必先选中）粗描边白 2.5 + 名称 + 徽标 + depth range 行（现状全量）；例外——无图占位块（画布层 `tileImage(tile) == nil` 判定，合成内无图同样命中）常态保留名称 + 徽标（无 depth range 行）。实现细节：`tileImage` 每图块取一次复用（缓存命中仅字典查询，解码仍由 `pushFullRender` 主动触发）；rangeText 只在 isSelected 时 resolve；选中/拖拽态绘制逻辑零改动。核心库零改动，渲染链/合成/命中/手势零改动。
  - 验收：36 项 checks 全过；harness 33 项全过（F 区胜者改写 160724px、max vs zOrderTop 差 17.14 与 M3.1 验收一致）；UI build 零告警；用户目视验收三态通过（常态无框无文字 / hover 细框 / 选中粗框+全量信息 / 占位块保留名称徽标），拖拽融合与回归项用户实测无退化；冷启动 8s 无崩溃
  - 事故与防线：验收期用户曾拿桌面旧包（0.3.0-m3，无 M3.1 修复）误判「depth cut 方向退化」——判据 = 截图中未选中图块带文字 chrome（新构建不可能产生）。已替换桌面全部旧构建为 0.3.2-m3.2（`RayDepthStudioUI 2.app` 0.2.0-m2 进废纸篓）；「版本戳 + 只验收当次构建」「near=high 守门断言」两条纪律已写入贯穿约束
  - 遗留：hover 态未经自动化验证（CU 截图链路被用户停用，由用户目视确认）；M1（打开图片/导出 PNG 目视）与 M1.5（Phokos 导入）人工回归沿袭
- 2026-08-24 · M3.2 验收通过 → **M3.3 立项（优先于 M4）**：项目文档体系 + MCP 基座 + Metal FX 实时编辑（用户指令）；M5（SAM3/BiRefNet/DA 深度重绘经 MCP 开放）、M6（架构重构与社区插件化）同步登记。修复方案见 M3.3 节；激活提示词固化到 `docs/m3.3-docs-mcp-metalfx-activation-prompt.md` 并登记入口；状态行与 skill 当前阶段已同步指向 M3.3
- 2026-08-24 · **M3.4 立项**（排于 M3.3 后、M4 前）：检查器数值控件与颜色选择增强——depth min/max 滑杆扩域 −1...2 + 全部滑杆 value reset 按钮；光源颜色 RGB/HSV 可切换 + NSColorSampler 吸管 + 系统调色板（用户指令，附截图）。修复方案见 M3.4 节；激活提示词固化到 `docs/m3.4-inspector-controls-activation-prompt.md` 并登记入口。同日项目同步 GitHub（public，Psamathe 系列）：`psamathe-depth-studio`（核心库）+ `psamathe-depth-studio-ui`（UI）；agent 工作文档（docs/ 下各激活提示词等）gitignore，仅保留 roadmap 作为公开预期开发计划
- 2026-08-24 · **M3.5 立项**（排于 M3.4 后、M4 前）：光源 gizmo 显隐与锁定/跟随（用户指令）——全局 gizmo 眼睛开关（隐藏即不可命中）；`LightSource` additive `isLocked`/`followsMouse`（Codable decodeIfPresent 向后兼容）；单灯锁定藏 gizmo 禁交互；锁定灯随鼠标移动（核心 `setFollowsMouse` 保证唯一，跟随期零提交走预览通道、结束单次提交入 undo）。修复方案见 M3.5 节；激活提示词固化到 `docs/m3.5-light-gizmo-visibility-lock-follow-activation-prompt.md` 并登记入口
- 2026-08-24 · M3.5 完成：光源 gizmo 显隐与锁定/跟随。核心 additive：`LightSource += isLocked/followsMouse`（默认 false；自定义 `init(from:)` decodeIfPresent 回退，旧工程零迁移可开，编码仍全量写出）+ `LightingRig.setFollowsMouse`（唯一性约束收敛核心）。UI：顶栏眼睛开关 `lightsGizmosHidden`（视图态，与 lightsLocked 同级；隐藏时 drawLights 整体早退 + hitTestLight 返回 nil，合成光照不受影响）；锁定灯 gizmo 全不画、hitTest 跳过、空白拖主光源跳过锁定主灯、Light 页签自动选中跳过锁定灯、undo/redo pruneSelection 清锁定灯选中；检查器 Light 区加「锁定（隐藏圆点）」「随鼠标移动」（未锁定 disabled）两 toggle。跟随走 hover 链路（onContinuousHover → viewToCanvas → DragPreview + relight.previewLights 预览通道），跟随期零 @Published project 提交；结束（toggle 关/选中他灯/切页签/解锁）经 `withSingleUndo` 一次性提交最终位置 + followsMouse=false（一格 undo）；开第二盏跟随先提交第一盏最终位置（核心再清标志，双保险）。
  - 决策点记录：「锁定时清除既有选中」与「锁定后才能开跟随」在检查器流程上互斥（清选中即检查器消失、跟随无从开启）——取最小冲突解：锁定 toggle 保留当前选中（gizmo/命中/拖动已被锁定态门控，点他处后不可再选），undo 回放产生的锁定态选中由 pruneSelection 清除。
  - 验收：40 项 checks 全过（+4：默认关闭/开启跟随/唯一性/可关闭）；35 项 harness 全过（+G8 新字段往返、G9 旧工程无新键解码回退）；桌面 .app 更新为 0.3.5-m3.5（窗口标题版本戳），冷启动 8s 无崩溃；CU 实测：眼睛开关全局藏/显 gizmo、锁定灯圆点消失、锁定+跟随后鼠标划过画布光照实时跟随全程无 gizmo、检查器数值经 DragPreview 实时跟随；旧格式工程（无新字段）实机打开正常。跟随实时跟随与关跟随 undo 由用户目视确认通过
  - 下一步：用户指示 MCP 适配尽快上 → M3.3（激活入口 `docs/m3.3-docs-mcp-metalfx-activation-prompt.md`）
- 2026-08-24 · **M3.6 立项**（排于 M3.3 后、M4 前；用户指令）：界面文案制度化 + zh-Hans/en 本地化——全量文案盘点与术语表（`docs/ui-copy-glossary.md`）、xcstrings 基座（`defaultLocalization: zh-Hans` + target resources）、插值显式 `String(localized:)` 禁拼接、双环境运行验证、`0.3.6-m3.6` 版本戳包重建桌面失效 .app。修复方案见 M3.6 节；激活提示词固化到 `docs/m3.6-ui-copy-localization-activation-prompt.md`（含全文案清单）并登记入口。M3.3 待激活状态不变（MCP 优先）
- 2026-08-24 · **M3.3 完成**：项目文档体系 + MCP 基座 + Metal FX 实时编辑。核心库 `Sources/` 零改动。
  - **任务 1 防退化基座**：核心库 `Scripts/verify.sh`（checks + harness 串联，任一失败非零退出）；UI `Scripts/build-app.sh`（版本号唯一来源 `BuildStamp.swift` → sed 提取 → 与构建日期一起写入 .app Info.plist，部署 ~/Desktop；窗口标题运行时优先读 bundle、开发态回退常量）；UI `Sources/RayDepthStudioUI/BuildStamp.swift` 为全仓唯一版本硬编码点
  - **任务 3 MCP 基座**：UI 新 target `RayDepthMCP`（零第三方依赖）——`MCPServer`（NWListener 经 `requiredLocalEndpoint` 仅绑 127.0.0.1:8377，`RAYDEPTH_MCP_PORT` 可配、`RAYDEPTH_MCP_DISABLED=1` 关闭；HTTP/1.1 手写解析、keep-alive、通知 202）+ 最小 JSON-RPC 2.0（initialize/ping/tools/list/tools/call，batch 支持）；`MCPBridge`（App 侧 @MainActor 桥）注册 11 首波工具 + FX 落地后 fx.list/fx.reload 共 13 件；ViewModel 追加程序化通道（openProject(at:)/saveProject(to:)/importImage(from:layer:)/exportPNG(to:size:)/setDepthMix/setTileDepthRange/updateLightParams），写操作全走既有提交通道（入 undo、触发 relight sync），零旁路
  - **任务 4 Metal FX**：`RayDepthRelight/MetalFXEngine.swift`（共享 MTLDevice+专属队列，init 留 M4 注入点；`makeLibrary(source:)` 后台编译、成功原子热替换、失败保留上一可用版并透出带行号错误；双 pass 离屏渲染 RGBA8 albedo→CGImage + R32Float depth→[Float]）；`DepthTextureStore` 加 `update(_:depthFloat:size:)` 原地更新 + 每 ref 版本号，`RelightCompositor` 深度缓存键纳入版本号（缓存陷阱守门）；`FXController`（库目录 `~/Library/Application Support/RayDepthStudio/FX/` 播种 gradient/checker/wave-heightfield 三内置示例、30fps 帧流走独立通道零 project 发布、无 FX 源停表零开销、加载自愈走 `RelightBridge.fxHealedSources` 场景层覆盖——核心 sources internal(set) 不可写，不改核心取场景层方案）；`FXPanelView`（NSTextView 编辑器 + 0.5s 防抖自动保存重编译 + 失败行号横幅）；「添加输入源」MetalFX 子菜单按库文件建真源；wave-heightfield generatesDepth，深度 near=high 引擎不隐式反转
  - **任务 2 文档**：核心 README 重写至 M3.3；UI README 更新四 target + MCP/FX；`docs/README.md` 全量索引新建；两 repo `AGENTS.md` 新建（构建命令/架构红线/目录导览）；`docs/mcp/` 14 页（总览 + 13 工具页）；总览 skill `raydepth-mcp` 新建；M3.3 期文档复查 `docs/documentation-review-2026-08-24-m33.md`（贯穿约束计数 36→40 已修）
  - 验收：`Scripts/verify.sh` 一键 **40 checks + 45 harness 全过**（H 区新增 H1–H10：引擎可用/wave 编译探测/albedo 非纯色/**不隐式反转守门**（恒定 0.75 透传）/wave near=high 方向/语法错误带行号/失败保留上一版/FX 深度参与 max 融合波峰波谷胜者断言×2/store.update 缓存失效守门）；`mcp-smoke.sh` 10 步全过（initialize→202→tools/list 13 件→importImage+sidecar→listTiles→setMix/setDepthRange 回读→export 512px 且 depthRange 改动后像素级差异→save/open 往返→fx.list→fx.reload）；MCP 仅绑 loopback 经 lsof 实测；build-app.sh 端到端产出带版本戳桌面包
  - **偏差记录**：①验收节文本「40+35」实际为 40+45（H 区新增 10 项，语义不变）②版本戳：并行 M3.6 会话先将 BuildStamp 升为 0.3.6-m3.6 并部署桌面；经用户指示两会话成果合并交付，M3.3 内容随 0.3.6-m3.6 包落地（plan 示例 0.3.3-m3.3 未实际使用）③施工期与 M3.6 会话同仓并行，曾遇构建竞态与端口残留进程，均已清理；最终 verify/smoke 在合并树上复跑全绿
  - 遗留：FX GUI 目视三项（wave 图块画布内重光照+max 融合观感、编辑器热更 ≤1s、语法错误横幅）待用户切到 app 窗口后 CU 驱动确认（无头 H 区已覆盖等价断言）；M1/M1.5 人工回归沿袭（未触碰这些路径）；桌面旧进程（0.3.5-m3.5 内存实例）待用户关闭
- 2026-08-24 · **M3.4 完成**：检查器数值控件与颜色选择增强。核心库零改动；改动集中在 UI 层 `InspectorView.swift` / `StudioViewModel.swift` / 本地化资源。
  - **任务 1 滑杆扩域 + reset**：depth Min/Max 域 `0...1` → `-1...2`（强度维持 `0...3`）；窗口可视化胶囊同步改按 [-1,2] 线性映射（显示分数 clamp 到 [0,1] 防脏数据画错）。`SliderRow` 加可选 `defaultValue`——行右 `arrow.counterclockwise` reset 按钮一处改动全检查器生效（depth min→0/max→1/强度→1、光源强度→1/半径→200/RGB→1、HSV H→0/S→0/V→1，默认值取核心库模型默认）；reset 走既有 onChange 通道单次提交入 undo，当前值已是默认时禁用（防空提交污染 undo 栈）
  - **决策点记录**：核心 `DepthRange.init` 仍将 min/max clamp 到 [0,1]（M3.1 remap 零裁剪语义改了行为、构造期 clamp 未动），与「核心库零改动」约束冲突——取最小改动解：`StudioViewModel.setDepthMin/setDepthMax` 由构造新值改为直改公有 var（绕开构造期 clamp），保序语义（min 超 max 时推齐对方）与改前一致；Codable 合成实现本就不经 init，越界值工程存取往返无损；MCP `setTileDepthRange` 既有 [0,1] clamp 维持不动（契约不受影响）
  - **任务 2 颜色选择增强**：Color 区 segmented 切换 RGB（三滑杆）/HSV（H 0...360、S/V 0...1），切换态为视图本地 @State；HSV↔RGB 换算在 UI 层纯函数（`rgbToHsv`/`hsvToRgb`），存储仍 `LightSource.colorRGB`；`hueCache` 解决 S=0/V=0 色相无定义时 H 滑杆回弹。吸管 `NSColorSampler`（eyedropper 按钮取屏色，sRGB 归一）；调色板为 `NSColorWell` 桥接（`ColorWellView`，替代原不可交互预览条，系统调色板/swatches 回写，updateNSView 有 sRGB 分量变更守卫防闭环）。三入口共用既有 onRed/onGreen/onBlue 通道 + 逐通道变更守卫（未变化分量不提交）
  - **本地化**：新增文案全部 `String(localized:)`——「重置为默认值」Reset to Default、「从屏幕取色」Sample a color from the screen；RGB/HSV/H/S/V 按双语同形标识符入 xcstrings；`Scripts/xcstrings-to-strings.py` 重新生成 en.lproj/Localizable.strings（114 条）
  - 验收：`Scripts/verify.sh` 一键 40 checks + 45 harness 全过；`swift build` 零新增告警；核心库 `Sources/` 零改动
  - 遗留（人工）：目视项——min −0.5 / max 1.5 窗口推拉与胶囊显示、各 reset 回默认且可 undo、HSV↔RGB 互洽、吸管/调色板实机生效、en 环境新文案核对、冷启动 8s——待 build-app.sh 交付包上机确认
- 2026-08-24 · M3.4 用户验收通过（「效果不错」）→ **M3.7 立项**（排于 M4 前）：①图块重命名（用户指令）——核心 additive `StudioProject.renameSource` + ViewModel 通道 + 检查器 header 点击编辑；②跟随保持热修（用户报告 bug）——灯光跟随鼠标时切页签/选中他灯丢失跟随，确诊为 M3.5 两处有意设计的自动结束点（`selectedLightID.didSet` :81、`selectTab` :199），移除后跟随跨页签/跨选中持续（`updateLightFollow` 本就不限页签），显式结束条件（toggle 关/解锁/删除/开第二盏/MCP）不变。修复方案见 M3.7 节；激活提示词固化到 `docs/m3.7-tile-rename-follow-persist-activation-prompt.md` 并登记入口；状态行与 skill 当前阶段已同步指向 M3.7。同日两会话成果（M3.3+M3.6+M3.4）提交 GitHub
