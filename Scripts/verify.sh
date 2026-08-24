#!/bin/bash
# M3.3 防退化基座：一键验证。核心库 44 项 checks + UI 45 项 harness 串联，任一失败即非零退出。
# 用法：~/Documents/kimi/workspace/RayDepthStudio/Scripts/verify.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI_ROOT="$ROOT/../RayDepthStudioUI"
fail=0

echo "=== [1/2] raydepth-checks（核心库 44 项）==="
if ! (cd "$ROOT" && swift run raydepth-checks); then
    echo "--- raydepth-checks 失败 ---"
    fail=1
fi

echo ""
echo "=== [2/2] relight-harness（UI 45 项，release）==="
if ! (cd "$UI_ROOT" && swift run -c release relight-harness); then
    echo "--- relight-harness 失败 ---"
    fail=1
fi

echo ""
if [ "$fail" -ne 0 ]; then
    echo "verify: 存在失败项 ❌"
    exit 1
fi
echo "verify: 44 项 checks + 45 项 harness 全部通过 ✅"
