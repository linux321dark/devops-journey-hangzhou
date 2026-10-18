# Day 2 实战：K8s Deployment 与 HPA（本地 kind 集群）

> 配套学习计划：Day 2 = K8s Deployment 与 HPA（kind 起本地集群 + 部署 Day 1 镜像 + 配 HPA(CPU) 压测观察 Pod 自动伸缩）。
> 风格与 `day1-evening-practice.md` 一致：**边做边固化坑**。本文件所有「坑」均为基于官方 kind/k8s 文档 + 2026 实战 lab 的**高频预判坑**，实战验证后转正（见 `21天学习计划.md` 坑24–26）。

---

## 0. 目标与验收标准

**目标**：用 `kind` 在本地（推荐 ECS）起一个单节点 K8s，把 Day 1 多阶段构建的镜像部署成 `Deployment` + `Service`，装上 `metrics-server` 后配 `HPA(CPU)`，压测观察 Pod 自动伸缩，截图收口。

**验收 5 条**：
1. `kind create cluster` 成功，`kubectl get nodes` 显示 `Ready`。
2. Day 1 镜像在集群内 `Running`（Pod Ready），`kubectl logs` 无 `ErrImagePull` / `CrashLoopBackOff`。
3. `metrics-server` 安装成功，`kubectl top nodes/pods` 能返回真实数值（非报错）。
4. `kubectl get hpa` 的 `TARGETS` 从 `/50%` 变成真实百分比，压测后 `REPLICAS` 从 1 涨到 >1。
5. 产出 `week2/day2/` 下：deployment.yaml / service.yaml / hpa.yaml + 一张「压测前后 HPA 伸缩」截图，提交 GitHub。

---

## §0 前置工具链（本机装一次）

### 0.1 kind 安装
- **Mac（arm64）**：`brew install kind`（Homebrew 已装前提下）。
- **ECS（amd64，推荐本实验在这里跑）**：下 release 二进制
  ```bash
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
  chmod +x ./kind && mv ./kind /usr/local/bin/kind
  kind version
  ```
  > kind 版本随 K8s 走，装最新稳定即可；本实验对 kind 版本不敏感。

### 0.2 kubectl（应已具备）
学习计划 2026-10-17 环境核验已装。确认：
```bash
kubectl version --client
```

### 0.3 ⚠️ 架构对齐（最容易白干的一步）
- Day 1 的七门镜像是在 **ECS（amd64）** 上 `docker build` 出来的 = **amd64** 架构。
- 若你在 **Mac（Apple Silicon = arm64）** 本地起 kind，kind 的 K8s 节点跑在 Docker Desktop 的 **arm64** Linux VM 里 → 拉 amd64 镜像会 `exec format error`（除非开 QEMU 模拟，极慢）。
- **结论**：**本实验优先在 ECS（amd64）上跑 kind**，Day 1 的 amd64 镜像零摩擦复用；若一定要在 Mac 跑，需把镜像重 build 成 `--platform linux/arm64` 再 load。

### 0.4 镜像来源决策（二选一，决定 §2 走哪条）
- **Path A（ECS 推荐）**：Day 1 镜像已在 ECS 本地 `/ docker images` 里 → 用 `kind load docker-image` 直接塞进 kind 节点，**免 registry、免鉴权、免网络**。
- **Path B（任意机器）**：从 ACR 拉（需 Day 1 已成功 `push` 到 ACR + 配 `imagePullSecret`）。若你 Day 1 的 ACR 推送因 `insufficient_scope` 没最终跑通，就别走 Path B，退回 Path A。

---

## §1 kind 起本地集群

```bash
# 起一个单节点集群（名字 day2，便于后续 delete 精确清理）
kind create cluster --name day2

# 切到该集群上下文
kubectl cluster-info --context kind-day2

# 验证节点就绪
kubectl get nodes
# 期望：NAME                     STATUS   ROLES           AGE   VERSION
#       kind-day2-control-plane  Ready    control-plane   30s   v1.xx.x
```

> ⚠️ ECS 内存小（<2G）可能起不来 → 见卡点自救「kind 节点 Pending / 起不来」。
> 收尾必做：`kind delete cluster --name day2`（释放 Docker 资源，否则镜像/cache 堆积）。

---

## §2 把 Day 1 镜像送进集群

### Path A：本地镜像直接 load（ECS 推荐，零鉴权）
```bash
# 列出 Day 1 镜像确认存在
docker images | grep day1-

# 把镜像塞进 kind 节点（名字必须和 --name 一致）
kind load docker-image registry.cn-hangzhou.aliyuncs.com/linux321-devops/day1-demo:go-v1 --name day2
# 若走本地 tag（未推 ACR）：kind load docker-image day1-go-demo:latest --name day2
```
> 关键：`kind load` 后 Deployment 的 `imagePullPolicy` 必须设 `IfNotPresent`（否则 kubelet 仍去远程拉，找不到就 `ErrImagePull`）。

### Path B：从 ACR 拉（需 ACR 已推 + 建 Secret）
```bash
# 1) 建拉取密钥（用户名=ACR 访问凭证页登录名，密码=Registry 专用密码）
kubectl create secret docker-registry acr-secret \
  --docker-server=registry.cn-hangzhou.aliyuncs.com \
  --docker-username=<访问凭证登录名> \
  --docker-password=<Registry专用密码>

# 2) Deployment 里加 imagePullSecrets（见 §3 YAML）
```

---

## §3 写 Deployment + Service（含 resources.requests.cpu）

新建 `week2/day2/go-demo.yaml`（用 Day 1 的 Go 镜像做示例；换成 node/java 同理）：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: day1-go
  labels:
    app: day1-go
spec:
  replicas: 1            # 初始 1 副本，HPA 接管后由它改
  selector:
    matchLabels:
      app: day1-go
  template:
    metadata:
      labels:
        app: day1-go
    spec:
      containers:
      - name: day1-go
        image: registry.cn-hangzhou.aliyuncs.com/linux321-devops/day1-demo:go-v1
        imagePullPolicy: IfNotPresent   # Path A 必须；Path B 也建议
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "100m"     # ⚠️ HPA 计算 CPU 利用率的分母，缺了就 /50%
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "256Mi"
      # imagePullSecrets:            # ← Path B 解开；Path A 删掉
      # - name: acr-secret
---
apiVersion: v1
kind: Service
metadata:
  name: day1-go-svc
spec:
  selector:
    app: day1-go
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

```bash
kubectl apply -f week2/day2/go-demo.yaml
kubectl rollout status deployment/day1-go
kubectl get pods -l app=day1-go
# 期望 Running / Ready 1/1
```

---

## §4 装 metrics-server（kind 必踩：--kubelet-insecure-tls）

kind **默认不带 metrics-server**，而 HPA 必须靠它取 CPU 指标。官方组件装好后，**kind 的 kubelet 用自签名证书**，metrics-server 默认校验证书会失败 → 必须加 `--kubelet-insecure-tls`（仅本地 lab 用，生产不该开）。

```bash
# 1) 装官方 metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 2) 给 metrics-server 加 --kubelet-insecure-tls（kind 专属 patch）
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# 3) 等就绪
kubectl rollout status deployment/metrics-server -n kube-system

# 4) 验证指标流（必须返回真实数值，非报错）
kubectl top nodes
kubectl top pods -l app=day1-go
```

> 若 `kubectl top nodes` 报错 `MetricsNotAvailableForPod` / 证书错 → patch 没生效或被覆盖，重跑第 2 步并确认 `kubectl get deployment metrics-server -n kube-system -o yaml | grep kubelet-insecure-tls` 有输出。

---

## §5 配 HPA（CPU 50%）

```bash
# 快速法（flags 生成 HPA）
kubectl autoscale deployment day1-go --cpu-percent=50 --min=1 --max=5

# 或写 manifest（推荐，可版本化）week2/day2/hpa.yaml：
```
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: day1-go
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: day1-go
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```
```bash
kubectl apply -f week2/day2/hpa.yaml
kubectl get hpa day1-go
# 期望：TARGETS 从 <unknown>/50% → 0%/50%（等 metrics-server 首轮采集，约 1 分钟）
```

---

## §6 压测观察伸缩

开三个终端（或用 `tmux` 分屏）：

```bash
# 终端1：盯 HPA
kubectl get hpa day1-go -w

# 终端2：盯 Pod 数量
kubectl get pods -l app=day1-go -w

# 终端3：起一个 busybox 压测 Pod，疯狂请求 Service
kubectl run load-generator --rm -i --tty --image=busybox:1.36 --restart=Never \
  -- /bin/sh -c "while true; do wget -q -O- http://day1-go-svc; done"
```

观察：
- `kubectl get hpa` 的 `TARGETS` 从 `0%/50%` 爬升（如 `250%/50%`）→ `REPLICAS` 从 1 涨到 >1（如 5）。
- `kubectl describe hpa day1-go` 的 Events 会显式写出 `computed the desired num of replicas` 和依据的指标读数。
- 停掉压测（Ctrl-C 终端3）→ 默认 300s 缩容稳定窗口后副本回落到 1。

> ⚠️ 若压测后 CPU 不涨、副本不增：Day 1 的 gin/express 只是回显 web 服务，单并发打不出 CPU。两种解法：① 多开几个 load-generator（`kubectl run lg2 ...` 并发轰）；② 改用官方 CPU 燃烧镜像 `registry.k8s.io/hpa-example`（php-apache，每请求烧 CPU）做**保底演示**——`kubectl set image deployment/day1-go day1-go=registry.k8s.io/hpa-example` 临时替换即可看到明显伸缩。

---

## §7 收口验证 + 截图

```bash
echo "=== 1. 节点 ===" && kubectl get nodes
echo "=== 2. Pod（应多副本 Running） ===" && kubectl get pods -l app=day1-go
echo "=== 3. metrics-server 生效 ===" && kubectl top pods -l app=day1-go
echo "=== 4. HPA 伸缩结果 ===" && kubectl get hpa day1-go
kubectl describe hpa day1-go | sed -n '/Events/,$p'
```

截图要点（存 `week2/day2/hpa-demo.png`）：`kubectl get hpa day1-go -w` 压测中 `TARGETS` 升高 + `REPLICAS` 增多的同屏。

收尾：
```bash
kubectl delete -f week2/day2/hpa.yaml -f week2/day2/go-demo.yaml
kind delete cluster --name day2
```

---

## 卡点自救（汇总预判坑 → 实战后转正）

- **`kubectl top nodes` 报错 / HPA `TARGETS` 一直 `<unknown>`**：metrics-server 没装或没加 `--kubelet-insecure-tls`（kind 专属）。重跑 §4 第 2 步并确认 patch 生效。
- **HPA `TARGETS` 显示 `/50%`（分母缺失）**：Deployment 的容器**没设 `resources.requests.cpu`**。HPA 公式是 `当前CPU/请求CPU`，无请求无法算百分比 → 补 requests.cpu。
- **Pod `ErrImagePull` / `ImagePullBackOff`**：① Path A 忘了 `kind load docker-image`；② `imagePullPolicy` 是 `Always` 但镜像只在本地 → 改成 `IfNotPresent`；③ Path B 没建 `acr-secret` 或 Secret 用户名/密码错（用 ACR 访问凭证页的值，非控制台密码）。
- **`exec format error`（Mac 跑 kind 拉 amd64 镜像）**：架构不匹配。回 ECS(amd64) 跑，或镜像重 build `--platform linux/arm64`。
- **kind 起不来 / 节点 Pending**：ECS 内存/CPU 不足（kind 单节点约需 2G）。调小 Docker 资源或换大规格；`docker system prune` 先清盘。
- **压测后副本不增**：见 §6 末尾——Day 1 镜像不烧 CPU，加并发或换 `hpa-example` 兜底。
- **`kubectl` 版本与集群版本 mismatch 警告**：kind 装的 K8s 版本可能新于本机 kubectl。`brew upgrade kubectl` 对齐，或忽略警告（一般不影响基础操作）。

---

## 附录：保底演示用官方 CPU 燃烧镜像
若 Day 1 镜像压测打不出 CPU，临时替换做 HPA 可视化：
```bash
kubectl set image deployment/day1-go day1-go=registry.k8s.io/hpa-example
# 压测：kubectl run -i --tty load --rm --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://day1-go-svc; done"
# 看完换回：kubectl set image deployment/day1-go day1-go=registry.cn-hangzhou.aliyuncs.com/linux321-devops/day1-demo:go-v1
```
