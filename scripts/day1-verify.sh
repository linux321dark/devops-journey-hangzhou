#!/usr/bin/env bash
# Day1 收口验证脚本（在 ECS 上跑）
# 用法：
#   bash day1-verify.sh
#   DEEP_DEMO=java-demo ACR_IMG=registry.cn-hangzhou.aliyuncs.com/linux321-devops/day1-demo:java-v1 bash day1-verify.sh
set -u

DEMOS=(node-demo go-demo java-demo py-demo ruby-demo php-demo rust-demo)
# 深度那门（Go 最易压 scratch；杭州对口可改 java-demo）
DEEP_DEMO="${DEEP_DEMO:-go-demo}"
DEEP_IMG="day1-${DEEP_DEMO}"
# ACR 拉回验证：用你【真实】的命名空间/仓库/tag，别再用文档占位 devops-journey
ACR_IMG="${ACR_IMG:-registry.cn-hangzhou.aliyuncs.com/linux321-devops/day1-demo:go-v1}"

echo "===== 1) 七门构建产物体积（比对达标线：Go/Rust<30M, Node/PHP 150-250M, Java 150-200M, Py/Ruby 200-400M）====="
for d in "${DEMOS[@]}"; do
  sz=$(docker images "day1-$d" --format "{{.Size}}" 2>/dev/null)
  if [ -n "$sz" ]; then echo -e "${sz}\t$d"; else echo -e "MISSING\t\t$d"; fi
done

echo
echo "===== 2) 深度门($DEEP_DEMO) 三项验证 ====="
echo -n "  [非root] uid（期望非 0）: "
docker run --rm "$DEEP_IMG" id -u 2>/dev/null || echo "运行失败"
echo -n "  [无编译器]（期望 OK/无）: "
if docker run --rm "$DEEP_IMG" sh -c 'command -v go; command -v mvn; command -v rustc; command -v javac' 2>/dev/null | grep -q .; then
  echo "有编译器残留！"
else
  echo "OK（无 go/mvn/rustc/javac）"
fi
echo -n "  [体积] : "
docker images "$DEEP_IMG" --format "{{.Size}}" 2>/dev/null || echo "镜像不存在"

echo
echo "===== 3) ACR 拉回验证 ====="
if docker pull "$ACR_IMG" 2>&1 | tail -3; then
  echo "✅ ACR 拉回成功: $ACR_IMG"
else
  echo "❌ ACR 拉回失败（检查：命名空间/仓库/tag 是否真实存在、docker login 是否 Login Succeeded）"
fi
