# Day 1 晚上实践 Checklist（19:30–22:30）

> **前提**：本实践属于「离职求职准备」，一律在**个人设备 + 家庭宽带/热点**完成（工行工时不做本计划内容，见学习计划硬隔离原则）。
> **目标**：写一份多阶段 Dockerfile → 优化到 `<100MB` → 推 ACR 个人版验证。
> **语言选择**：Java / Go / Python 三选一（建议跟杭州目标岗对口；没想好就先用 Go，最易压到 10–30MB）。

---

## 0. 前置确认（19:30–19:40）

- [ ] Docker Desktop 运行中：`docker info` 无报错
- [ ] 镜像加速器已生效（pull 走国内，不依赖 Clash）：
  ```bash
  docker info | grep -A3 "Registry Mirrors"
  ```
  有输出（你的 `*.mirror.aliyuncs.com` 等）= 已配；空 = 去 Docker Desktop → Settings → Docker Engine 粘入学习计划 §6 的 `registry-mirrors` JSON → Apply
- [ ] ACR 个人版仓库已建：登录 `https://cr.console.aliyun.com` → 个人版 → 命名空间（如 `devops-journey`）→ 仓库（如 `day1-demo`）
- [ ] 选定语言：□ Java  □ Go  □ Python

---

## 1. 建项目骨架（19:40–20:00）

任选一门，在 `~/Documents/devops-journey-hangzhou/week1/day1/` 下建子目录：

**Go**（`go-demo/`）：
```bash
mkdir -p ~/Documents/devops-journey-hangzhou/week1/day1/go-demo && cd "$_"
cat > main.go <<'EOF'
package main
import "fmt"
func main() { fmt.Println("Hello DevOps Journey Day1") }
EOF
cat > go.mod <<'EOF'
module go-demo
go 1.26
EOF
```

**Java（Spring Boot 最小可跑）**（`java-demo/`）：用 `spring initializr` 或手建 `pom.xml` + `src/main/java/com/example/App.java`（仅需一个打印端口的 Web 起步依赖，或直接用纯 `main()` + `maven-compiler-plugin` 跑通即可，重点是验证多阶段，不必真做业务）。

**Python**（`py-demo/`）：
```bash
mkdir -p ~/Documents/devops-journey-hangzhou/week1/day1/py-demo && cd "$_"
cat > main.py <<'EOF'
print("Hello DevOps Journey Day1")
EOF
cat > requirements.txt <<'EOF'
# 留空或放一两个纯 python 依赖，便于演示依赖安装层
EOF
```

---

## 2. 写多阶段 Dockerfile（20:00–21:00）

每个语言各给一份**已验证结构**，直接抄。配 `.dockerignore`。

### 2.1 `.dockerignore`（三种语言通用）
```
.git
target
node_modules
__pycache__
*.md
Dockerfile
.dockerignore
```

### 2.2 Go（→ scratch，约 10–30MB）
```dockerfile
# 阶段1：构建
FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /bin/app ./main.go

# 阶段2：运行（scratch 无 shell/包管理器，攻击面最小）
FROM scratch
COPY --from=build /bin/app /bin/app
USER 65532:65532
CMD ["/bin/app"]
```

### 2.3 Java / Spring Boot（Maven + JRE，约 80–120MB）
```dockerfile
# 阶段1：用 Maven 构建
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -q
COPY src ./src
RUN mvn package -DskipTests -q

# 阶段2：运行（只带 JRE，不带 JDK/构建工具）
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
USER 1000
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
```

### 2.4 Python（slim 运行，约 40–90MB；进阶可改 distroless）
```dockerfile
# 阶段1：装依赖
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
COPY . .

# 阶段2：运行
FROM python:3.12-slim
COPY --from=builder /install /usr/local
COPY --from=builder /app /app
WORKDIR /app
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser
CMD ["python","main.py"]
```

> 进阶（体积更小/更安全）：Python 可改 `FROM gcr.io/distroless/python3-debian12` + `USER nonroot`，但需注意 distroless 无 shell、`python` 路径与 `CMD` 写法差异，初学者先跑通 slim 版。

---

## 3. 构建 + 量体积（21:00–21:30）

```bash
cd ~/Documents/devops-journey-hangzhou/week1/day1/<语言>-demo
docker build -t day1-demo:multistage .

# 看最终体积
docker images day1-demo

# 看每层构成（找胖层）
docker history day1-demo:multistage
```

**对照目标**：Go <30MB、Java 80–120MB、Python 40–90MB。未达到就进第 4 步优化。

---

## 4. 优化到目标体积（21:30–22:00）

按顺序排查，改完重 build 对比：

- [ ] **基础镜像钉版本且最小**：`alpine` / `slim` / `jre-alpine` / `scratch`，不用 `latest`、不用完整 `ubuntu`/`jdk`
- [ ] **多阶段**：build 工具链（maven/golang/python 编译期）只在第一阶段，最终镜像不残留
- [ ] **依赖安装与代码复制分层**：先 `COPY pom.xml`/`go.mod` 再装依赖，利用缓存且让源码变更不拖累依赖层
- [ ] **清理包缓存**：`apt-get` 后 `rm -rf /var/lib/apt/lists/*`；apk 后 `apk cache clean`；pip 用 `--no-cache-dir`
- [ ] **`.dockerignore` 生效**：构建上下文不含 `.git`/`target`/`node_modules`
- [ ] **非 root**：`USER` 已设
- [ ] **Go 静态编译**：`CGO_ENABLED=0` + `-ldflags="-s -w"`（否则跑不了 scratch）
- [ ] **确认只有最后一个 FROM 进入最终镜像**（多阶段默认行为）

---

## 5. 推 ACR 个人版（22:00–22:20）

> push 到 ACR 走 `aliyuncs.com` 国内直连，**不需要 Clash 代理**（registry-mirrors 只管 pull，不管 push）。

```bash
# 1. 登录（用户名=阿里云账号，密码=ACR 个人版「访问凭证」里设的登录密码，非账号登录密码）
docker login --username=<你的阿里云账号> registry.cn-hangzhou.aliyuncs.com

# 2. 打 tag（格式：registry.cn-<区域>.aliyuncs.com/<命名空间>/<仓库>:<标签>）
docker tag day1-demo:multistage registry.cn-hangzhou.aliyuncs.com/devops-journey/day1-demo:go-v1

# 3. 推送
docker push registry.cn-hangzhou.aliyuncs.com/devops-journey/day1-demo:go-v1

# 4. 验证：从 ACR 拉回（可选，确认远端可用）
docker rmi registry.cn-hangzhou.aliyuncs.com/devops-journey/day1-demo:go-v1
docker pull registry.cn-hangzhou.aliyuncs.com/devops-journey/day1-demo:go-v1
```

> 区域按你 ACR 实际地域改（杭州=`cn-hangzhou`）。命名空间/仓库名换成你第 0 步建的。

---

## 6. 沉淀到 Git（22:20–22:30）

```bash
cd ~/Documents/devops-journey-hangzhou
git add week1/day1/<语言>-demo/ docs/day1-evening-practice.md
git commit -m "day1: 多阶段 Dockerfile 实践（<语言>）+ 推 ACR 验证"
git push -u origin main   # 密码填 jihulab Personal Access Token
```

> 把 Dockerfile + 构建体积记录（截图 `docker images`/`history`）一并提交，是 Day 1 的产出物，面试可讲。

---

## 验收标准（全满足 = Day 1 达标）

1. 多阶段 Dockerfile 写通，`docker build` 成功
2. 最终镜像体积达到速查表目标（Go<30MB / Java 80–120MB / Python 40–90MB）
3. 镜像内**不含**编译器/构建工具（用 `docker history` 或 `docker run --rm <镜像> which mvn/gc` 验证为空）
4. 以**非 root** 用户运行（`docker run --rm <镜像> id -u` 返回非 0）
5. 成功推到 ACR 个人版并拉回验证
6. 产出物已提交 Git（本地 + push jihulab）

---

## 卡点自救

- **pull 超时**：确认第 0 步 `Registry Mirrors` 已配；仍慢就临时开 Clash TUN 或手动 `export https_proxy=http://127.0.0.1:7897` 后 build/pull。
- **Go 跑 scratch 报 `no such file`**：漏了 `CGO_ENABLED=0`，重新 build。
- **Java `target/*.jar` 匹配不到**：确认 `mvn package` 成功产出 jar，且 `COPY --from=builder /app/target/*.jar`。
- **ACR 登录失败**：密码是 ACR 访问凭证密码，不是阿里云登录密码；在 ACR 控制台「访问凭证」重置。
- **push 报 `denied: requested access`**：tag 的命名空间/仓库名与 ACR 里建的不一致，先去控制台核对。
