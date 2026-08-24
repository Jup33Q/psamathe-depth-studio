import Foundation
import CoreGraphics
import RayDepthStudio

// 轻量断言检查器：环境无 XCTest 时兜底验证核心模型。
// 运行：swift run raydepth-checks；全部通过时退出码 0。

var failures = 0
func check(_ condition: Bool, _ name: String) {
    if condition { print("  ✅ \(name)") } else { failures += 1; print("  ❌ \(name)") }
}

// MARK: - 画布：移动 / 缩放 / 拼接

print("Canvas")
do {
    var canvas = Canvas(snap: .init(isEnabled: false))
    let a = canvas.place(sourceID: UUID(), edge: 100, at: CGPoint(x: 50, y: 50))
    canvas.move(id: a.id, to: CGPoint(x: 300, y: 220))
    check(canvas.tile(id: a.id)?.center == CGPoint(x: 300, y: 220), "移动到指定中心")

    canvas.translate(id: a.id, by: CGVector(dx: 10, dy: -5))
    check(canvas.tile(id: a.id)?.center == CGPoint(x: 310, y: 215), "平移增量")

    canvas.scale(id: a.id, by: 2.5)
    let t = canvas.tile(id: a.id)!
    check(abs(t.renderedEdge - 250) < 1e-9 && t.frame.width == t.frame.height, "等比缩放保持方形")

    canvas.scale(id: a.id, to: -3)
    check(canvas.tile(id: a.id)!.scale > 0, "缩放下限钳制")
}

do {
    var canvas = Canvas(snap: .init(isEnabled: true, tolerance: 10))
    let a = canvas.place(sourceID: UUID(), edge: 100, at: CGPoint(x: 50, y: 50))
    let b = canvas.place(sourceID: UUID(), edge: 100, at: CGPoint(x: 500, y: 500))
    canvas.move(id: b.id, to: CGPoint(x: 156, y: 53))
    let snapped = canvas.tile(id: b.id)!
    check(abs(snapped.center.x - 150) < 1e-9 && abs(snapped.center.y - 50) < 1e-9, "边对边吸附 + 中线对齐")
    check(abs(snapped.frame.minX - canvas.tile(id: a.id)!.frame.maxX) < 1e-9, "拼接后共享边")

    var loose = Canvas(snap: .init(isEnabled: true, tolerance: 5))
    let x = loose.place(sourceID: UUID(), edge: 100, at: CGPoint(x: 50, y: 50))
    _ = x
    let y = loose.place(sourceID: UUID(), edge: 100, at: CGPoint(x: 500, y: 500))
    loose.move(id: y.id, to: CGPoint(x: 180, y: 400))
    check(loose.tile(id: y.id)?.center == CGPoint(x: 180, y: 400), "超容差不吸附")

    var grid = Canvas(snap: .init(isEnabled: false))
    let src = UUID()
    let ids = (0..<4).map { _ in grid.place(sourceID: src, edge: 100, at: CGPoint(x: 1000, y: 1000)).id }
    grid.arrangeGrid(edge: 100, origin: .zero)
    let frames = ids.map { grid.tile(id: $0)!.frame }
    check(abs(frames[0].maxX - frames[1].minX) < 1e-9 && abs(frames[0].maxY - frames[2].minY) < 1e-9,
          "arrangeGrid 2×2 共享边")

    let top = canvas.hitTest(CGPoint(x: 151, y: 51))
    check(top?.id == b.id, "命中测试取 zIndex 高者")
}

// MARK: - 深度处理

print("DepthProcessing")

final class StubEstimator: DepthEstimating, @unchecked Sendable {
    var calls = 0
    func estimateDepth(for frame: Frame) throws -> TextureRef {
        calls += 1
        return TextureRef(id: UInt64(calls), size: frame.color.size, backing: .metal)
    }
}

do {
    let estimator = StubEstimator()
    let static_ = StaticDepth()
    let frame = Frame(sequence: 0, timestamp: 0,
                      color: TextureRef(id: 1, size: .init(width: 512, height: 512), backing: .cpuMemory))
    let first = try static_.depth(for: frame, estimator: estimator)
    let second = try static_.depth(for: frame, estimator: estimator)
    check(first == second && estimator.calls == 1, "staticDepth 估计一次并缓存")
    static_.invalidate()
    _ = try static_.depth(for: frame, estimator: estimator)
    check(estimator.calls == 2, "invalidate 后重新估计")

    let stream = StreamDepth(stride: 2)
    let est2 = StubEstimator()
    let tex = TextureRef(id: 1, size: .init(width: 512, height: 512), backing: .metal)
    let f0 = try stream.depth(for: Frame(sequence: 0, timestamp: 0, color: tex), estimator: est2)
    let f1 = try stream.depth(for: Frame(sequence: 1, timestamp: 0, color: tex), estimator: est2)
    let f2 = try stream.depth(for: Frame(sequence: 2, timestamp: 0, color: tex), estimator: est2)
    check(est2.calls == 2 && f0 == f1 && f1 != f2, "streamDepth stride 降频复用")

    do {
        _ = try stream.depth(for: Frame(sequence: 0, timestamp: 0, color: tex), estimator: nil)
        check(false, "streamDepth 缺估计器应抛错")
    } catch DepthError.estimatorMissing {
        check(true, "streamDepth 缺估计器抛 estimatorMissing")
    }

    let embedded = TextureRef(id: 7, size: .init(width: 64, height: 64), backing: .metal)
    let sidecar = TextureRef(id: 8, size: .init(width: 64, height: 64), backing: .cpuMemory)
    let color = TextureRef(id: 1, size: .init(width: 64, height: 64), backing: .metal)
    let res = ResourceDepth(resource: sidecar)
    check(try res.depth(for: Frame(sequence: 0, timestamp: 0, color: color, embeddedDepth: embedded),
                        estimator: nil) == embedded, "fromResource 优先帧内嵌深度")
    check(try res.depth(for: Frame(sequence: 1, timestamp: 0, color: color),
                        estimator: nil) == sidecar, "fromResource 回退源级资源")
    do {
        _ = try ResourceDepth().depth(for: Frame(sequence: 2, timestamp: 0, color: color), estimator: nil)
        check(false, "fromResource 无资源应抛错")
    } catch DepthError.resourceDepthMissing {
        check(true, "fromResource 无资源抛 resourceDepthMissing")
    }
} catch {
    failures += 1
    print("  ❌ 深度处理检查意外抛错: \(error)")
}

// MARK: - 输入源与支持矩阵一致性

print("SupportMatrix")
do {
    let sources: [any InputSource] = [
        NDISource(name: "ndi", endpoint: "HOST (src)"),
        SyphonSource(name: "sy", serverName: "Server"),
        FileInSource(name: "file", fileURL: URL(fileURLWithPath: "/tmp/a.png")),
        MetalFXSource(name: "plane", effect: .plane(.init(shaderName: "wave", generatesDepth: true))),
        MetalFXSource(name: "p3d", effect: .particle3D(.init(particleCount: 10_000))),
        CameraSource(name: "cam")
    ]
    var consistent = true
    for source in sources {
        let variant: String? = (source as? MetalFXSource).flatMap {
            switch $0.effect { case .plane: return "plane"; case .particle3D: return "particle3D" }
        }
        for kind in source.supportedDepthKinds {
            let level = DepthSupportMatrix.level(input: source.kind, variant: variant, depth: kind)
            if level != .yes && level != .planned {
                consistent = false
                print("    ⚠️ \(source.kind)\(variant.map { "·\($0)" } ?? "") 声明 \(kind) 但矩阵为 \(level?.rawValue ?? "nil")")
            }
        }
    }
    check(consistent, "每个源 supportedDepthKinds ⊆ 矩阵允许集")

    let covered = Set(DepthSupportMatrix.entries.keys.map(\.input))
    check(covered == Set(InputKind.allCases), "矩阵覆盖全部五种输入")

    var file = FileInSource(name: "f", fileURL: URL(fileURLWithPath: "/tmp/a.png"))
    do {
        try file.setDepthProcessing(StreamDepth())
        check(false, "fileIn 切 streamDepth 应抛错")
    } catch SourceError.unsupportedDepthKind {
        check(true, "不支持的深度处理方式切换抛错")
    }
    try? file.setDepthProcessing(NoDepth())
    check(file.depthKind == .noDepth, "支持的方式可切换")
}

// MARK: - 图层策略 / 光源 / 深度范围 / StudioProject

print("StudioProject & LayerPolicy")
do {
    var project = StudioProject()

    // noDepth 限 1 张（背景层沉底）
    _ = try project.addSource(MetalFXSource(name: "bg", effect: .plane(.init(shaderName: "grad", generatesDepth: false)),
                                            depthProcessing: NoDepth()))
    do {
        _ = try project.addSource(FileInSource(name: "bg2", fileURL: URL(fileURLWithPath: "/tmp/b.png"),
                                               depthProcessing: NoDepth()))
        check(false, "noDepth 第二张应抛 layerFull")
    } catch StudioError.layerFull(let kind, let limit) {
        check(kind == .noDepth && limit == 1, "noDepth 限 1 张")
    }
    let bg = project.tiles(in: .noDepth).first
    check(bg != nil && project.canvas.tiles.allSatisfy { $0.zIndex >= bg!.zIndex }, "背景层 zIndex 沉底")

    // streamDepth 限 8 张（可实例化）
    for i in 0..<8 {
        _ = try project.addSource(NDISource(name: "ndi\(i)", endpoint: "H (\(i))"))
    }
    do {
        _ = try project.addSource(CameraSource(name: "cam9"))
        check(false, "streamDepth 第 9 张应抛 layerFull")
    } catch StudioError.layerFull(let kind, let limit) {
        check(kind == .streamDepth && limit == 8, "streamDepth 限 8 张")
    }
    check(project.remainingSlots(for: .streamDepth) == 0, "streamDepth 名额用完")
    check(project.occupancyLabel(for: .streamDepth) == "8/8", "占用标签 8/8")

    // staticDepth / fromResource 不限
    for i in 0..<12 {
        _ = try project.addSource(FileInSource(name: "s\(i)", fileURL: URL(fileURLWithPath: "/tmp/s\(i).png")))
        _ = try project.addSource(MetalFXSource(name: "p\(i)",
                                                effect: .particle3D(.init(particleCount: 1000)),
                                                depthProcessing: ResourceDepth()))
    }
    check(project.tiles(in: .staticDepth).count == 12 && project.tiles(in: .fromResource).count == 12,
          "static / fromResource 不限数量")
    check(project.remainingSlots(for: .staticDepth) == nil, "static 名额不限")

    // 删除输入源：图块 + 注册表一起移除
    let streamTile = project.tiles(in: .streamDepth).first!
    project.removeSource(tileID: streamTile.id)
    check(project.tiles(in: .streamDepth).count == 7 && project.sources[streamTile.sourceID] == nil,
          "删除源后名额释放")

    // 深度范围：static/stream/fromResource 有默认 range；noDepth 没有
    let staticTile = project.tiles(in: .staticDepth).first!
    check(staticTile.depthRange != nil, "static 图块附带默认 DepthRange")
    check(project.tiles(in: .noDepth).first!.depthRange == nil, "noDepth 无深度范围")
    project.setDepthRange(of: staticTile.id, DepthRange(min: 0.2, max: 0.8, intensity: 1.5))
    let updated = project.canvas.tile(id: staticTile.id)!.depthRange!
    check(abs(updated.min - 0.2) < 1e-6 && abs(updated.max - 0.8) < 1e-6, "深度 min/max 可调")
    let r = DepthRange(min: 0.2, max: 0.8, intensity: 1.5)
    // 线性重映射 [0,1]→[min,max]（不裁剪）：v' = (v×span + min) × intensity
    let r1 = DepthRange(min: 0.2, max: 0.8)
    check(abs(r.remap(0.5) - 0.75) < 1e-6 && abs(r.remap(0.1) - 0.39) < 1e-6 && abs(r.remap(0.9) - 1.11) < 1e-6
          && abs(r1.remap(0) - 0.2) < 1e-6 && abs(r1.remap(1) - 0.8) < 1e-6,
          "DepthRange.remap 线性重映射（不裁剪）+ 强度")

    // 光源：不限数量 + 鼠标控制 + glowing fx
    for i in 0..<20 {
        project.addLight(LightSource(name: "L\(i)", glowingFX: i == 0))
    }
    check(project.lights.lights.count == 20, "光源不限数量（20 盏）")
    project.movePrimaryLight(to: CGPoint(x: 123, y: 456))
    let primary = project.lights.light(id: project.lights.primaryLightID!)!
    check(primary.position == CGPoint(x: 123, y: 456), "鼠标控制主光源位置")
    check(project.lights.lights.contains(where: { $0.glowingFX }), "glowing fx 层可叠加")

    // M3.5：光源锁定/随鼠标 additive 字段（默认关闭）+ 跟随唯一性（核心层约束）
    let freshLight = LightSource(name: "Fresh")
    check(!freshLight.isLocked && !freshLight.followsMouse, "光源锁定/跟随字段默认关闭")
    let followA = project.lights.lights[0].id
    let followB = project.lights.lights[1].id
    project.lights.setFollowsMouse(followA, true)
    check(project.lights.light(id: followA)?.followsMouse == true, "setFollowsMouse 开启跟随")
    project.lights.setFollowsMouse(followB, true)
    check(project.lights.light(id: followB)?.followsMouse == true
          && project.lights.light(id: followA)?.followsMouse == false
          && project.lights.lights.filter({ $0.followsMouse }).count == 1,
          "随鼠标移动的光源最多一个（开第二个自动关第一个）")
    project.lights.setFollowsMouse(followB, false)
    check(project.lights.lights.allSatisfy { !$0.followsMouse }, "setFollowsMouse 可关闭跟随")

    // 法线管线：默认基于混合后结果
    check(project.normalPipeline.mix == .zOrderTop, "normal 基于混合后整幅深度")

    // M3.7：输入源重命名（additive）
    let renameTile = project.tiles(in: .staticDepth).first!
    let renameSourceID = renameTile.sourceID
    project.renameSource(renameSourceID, to: "改名后的源")
    check(project.sources[renameSourceID]?.name == "改名后的源", "renameSource 改名生效")
    project.renameSource(UUID(), to: "幽灵")
    check(project.sources.count == 32 && project.sources[renameSourceID]?.name == "改名后的源",
          "renameSource 不存在的 id 空操作")
    project.renameSource(renameSourceID, to: "改名后的源")
    check(project.sources[renameSourceID]?.name == "改名后的源", "renameSource 同名不改")
    check(project.canvas.tile(id: renameTile.id)?.sourceID == renameSourceID
          && project.tiles(in: .staticDepth).contains(where: { $0.id == renameTile.id }),
          "改名后图块关联不受影响")
} catch {
    failures += 1
    print("  ❌ StudioProject 检查意外抛错: \(error)")
}

print(failures == 0 ? "\n全部检查通过 ✅" : "\n\(failures) 项失败 ❌")
exit(failures == 0 ? 0 : 1)
