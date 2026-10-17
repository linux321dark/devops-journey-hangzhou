# Docker 视频配套笔记（尚硅谷 / 黑马 · 可直接读，免刷视频）

> **用途**：Day 1 上午"视频跟练"环节的替代/前置读物。把 B 站尚硅谷、黑马 Docker 教程中 Dockerfile 与多阶段构建的精华整理成文字，配合 `docker-multistage-allstacks.md` 食用。
> **资料来源**：① 尚硅谷 `BV1gr4y1U7CY`（Docker 实战教程/docker 教程天花板）、`BV1Ls411n7mx`（周阳基础篇）、`atguigu.com/video/307`（3 小时速通 Docker，含 Dockerfile 专章）；② 黑马 `BV1CJ411T7BK`；③ 社区笔记（CSDN / 博客园 / 掘金 / 人人代码等，见文末引用）；④ 官方文档 `docs.docker.top`、阿里云帮助。
> **说明**：本人未逐帧观看视频，笔记依据课程分集大纲 + 社区已整理笔记 + 官方文档整合而成；关键技术点均以官方文档兜底核对。建议先看本笔记再按需回看对应分集加深印象。

---

## 一、看哪几集（国内 B站 · 按优先级）

| 课程 | BV / 地址 | 讲 Dockerfile / 多阶段的集 | 时长 | 定位 |
| --- | --- | --- | --- | --- |
| 尚硅谷 3 小时速通 Docker | `atguigu.com/video/307`（B站同源） | **第 5 章 Dockerfile** 专章，末尾实战一键部署 MySQL/Redis/Kafka 等中间件 | 3h | 最快入门，Dockerfile 语法全覆盖 |
| 尚硅谷 Docker 实战教程 | `https://www.bilibili.com/video/BV1gr4y1U7CY` | Dockerfile 编写 + 构建复杂镜像章节 | 较长 | 重实战、企业级 |
| 尚硅谷 基础篇（周阳） | `https://www.bilibili.com/video/BV1Ls411n7mx` | 镜像/容器/仓库概念 + Dockerfile 制作复杂镜像 | 8h | 概念最扎实 |
| 黑马程序员 Docker | `https://www.bilibili.com/video/BV1CJ411T7BK` | 镜像原理 → 镜像制作（p≈28 起）→ Compose → 私有仓库 | — | 偏原理+部署 |

**建议路径**：先看「3 小时速通」第 5 章 Dockerfile（最快建立语法骨架）→ 卡概念再补周阳基础篇对应章 → 多阶段构建直接读本笔记第四节 + 手册。

---

## 二、镜像分层原理（视频都会先讲）

- 镜像 = 多层**只读层**叠加；Dockerfile 每条指令生成一层。
- 容器 = 镜像 + 最上层**可写层**（容器删除，可写层丢，镜像不变）。
- 层可**缓存、可复用**：指令和上下文未变 → 直接复用缓存层，加速重建。
- 推论：把"不常变的操作放前面、常变的放后面"能最大化缓存命中（见第六节）。

---

## 三、Dockerfile 核心指令速查

| 指令 | 作用 | 关键注意 |
| --- | --- | --- |
| `FROM` | 指定基础镜像（**第一条指令**） | 多阶段里可多次出现，配 `AS <名>` |
| `RUN` | 构建期执行命令（装依赖/编译） | 用 `&&` 连命令，末尾清理缓存 |
| `COPY` | 复制本地文件进镜像 | 多阶段里用 `COPY --from=<阶段>` 跨阶段搬运 |
| `ADD` | 类似 COPY，但支持 tar 自动解压 / 远程 URL | 一般优先用 `COPY`，少用 `ADD` |
| `CMD` | 容器启动默认命令（**可被 `docker run` 覆盖**） | 多条只生效最后一条 |
| `ENTRYPOINT` | 容器主命令（**不可被覆盖**，参数追加） | 固化启动行为时用 |
| `ENV` | 设置环境变量 | 会写进镜像，谨慎放密钥 |
| `WORKDIR` | 切换工作目录（类似 `cd`，会创建目录） | 比 `RUN cd` 更清晰 |
| `EXPOSE` | 声明暴露端口（仅文档作用，不真正映射） | 真正映射靠 `docker run -p` |
| `USER` | 指定运行用户（**安全必做：非 root**） | 默认 root，生产要切 |
| `ARG` | 构建期变量（构建后不存在于镜像） | 适合传版本号；与 `ENV` 区别在生命周期 |

> `CMD` vs `ENTRYPOINT`：ENTRYPOINT 定"程序"，CMD 给"默认参数"。生产常用 `ENTRYPOINT ["java","-jar"]` + `CMD ["app.jar"]` 组合。

---

## 四、单阶段 vs 多阶段（重点，面试常问）

**单阶段的问题**（社区笔记共识）：
- 镜像臃肿：编译器、构建工具、源码、中间文件全打进生产镜像
- 攻击面大：多余软件包带已知漏洞（CVE）
- 传输慢：大镜像拉取/推送耗时，CI/CD 易超时
- 缓存差：缺乏阶段隔离，缓存利用不充分

**多阶段核心思想**：
```
阶段1(构建): 大型基础镜像 → 装工具链 → 编译/打包 → 生成产物
                            ↓ COPY --from=builder
阶段2(运行): 小型基础镜像 → 只复制产物 → 配置运行 → 最终镜像
```
- 单个 Dockerfile 多个 `FROM`，每个开启新**隔离**阶段（前一阶段的环境变量/文件不自动传递）
- 最终只输出**最后一个阶段**的镜像层，构建工具链被丢弃
- 体积通常减少 **50%~90%**

**关键语法三要素**：
```dockerfile
FROM <构建镜像> AS build        # ① 命名阶段
... 编译 ...
FROM <运行镜像>                  # ② 最终阶段（只保留它）
COPY --from=build /path/bin /path/bin   # ③ 跨阶段搬运产物（也可用 COPY --from=0 按索引）
CMD [...]
```

**Go 范例（→ scratch，极致小）**：
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app/myapp .
FROM scratch
COPY --from=builder /app/myapp /myapp
USER 65532:65532
ENTRYPOINT ["/myapp"]
```
> `CGO_ENABLED=0` 生成完全静态二进制才能跑 scratch；`-s -w` 去调试符号再小一圈。单阶段 800MB+ → 多阶段 10~30MB。

**Java / Spring Boot 范例（JDK 只在构建阶段）**：
```dockerfile
FROM maven:3.8-openjdk-8 AS build
WORKDIR /build
COPY . .
RUN mvn clean package -DskipTests
FROM openjdk:8-jre-slim
WORKDIR /home/app
COPY --from=build /build/target/*.jar app.jar
EXPOSE 8080
CMD ["java","-jar","app.jar"]
```
> 普通构建 300MB+ → 多阶段 ~50MB，体积缩 6 倍以上。进阶用 `jlink` 自定义运行时或 Gradle 版（见手册）。

**Node 范例（层缓存优化）**：
```dockerfile
FROM node:20-slim AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install            # 依赖不变就复用缓存层，不重跑 install
COPY . .
RUN pnpm build
FROM node:20-slim AS runner
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
RUN test -f ./dist/index.js || (echo "Build failed" && exit 1)
CMD ["node","dist/index.js"]
```
> 把 `package.json` 提前单独 COPY，是"变动频率从低到高"排层的经典手法，CI 提速明显。

---

## 五、体积优化实战 checklist（可直接用）

1. **多阶段构建**：build/runtime 分离，核心手段
2. **runtime 选最小基础镜像**：alpine / distroless / scratch / `*-jre-slim`，别用完整 JDK/SDK
3. **钉版本，不用 `latest`**：`golang:1.21`、`node:20-slim`、`alpine:3.18`（可再钉 digest）
4. **`.dockerignore`**：排除 `.git`、`node_modules`、`target`、`*.md`、本地配置
5. **不装多余包**；清理包缓存：`apt-get` 后 `rm -rf /var/lib/apt/lists/*`，apk 后 `apk cache clean`
6. **非 root 运行**（`USER`）
7. **层顺序按变动频率从低到高**排，最大化缓存命中
8. 定期 `docker build --pull` 拿基础镜像安全更新
9. **密钥绝不写进镜像**（用构建参数 `ARG`/Secret 或运行时挂载）
10. 验证：`docker images` 看体积、`docker history <镜像>` 看层构成

> ⚠️ **纠偏**：过去"合并 RUN 减少层数"已非硬规则——现代 Docker 每条指令独立缓存，真正杠杆是"不装多余东西 + 多阶段 + 小基础镜像 + 钉版本"。该合并（如 `apt update && install && clean`）是为了清缓存，不是为减层。

---

## 六、常见坑（视频 / 社区高频）

1. **scratch 没 CA 证书** → HTTPS 失败；需要证书/配置就别用纯 scratch，改用 alpine 或 distroless 带证书变体
2. **alpine 用 musl libc**，少数程序需 glibc → 改用 `debian-slim`
3. **COPY 漏了运行时文件**（配置/证书）→ 镜像能 build 但运行缺文件
4. **层顺序错**（源码在前、依赖在后）→ 每次改一行代码都重跑整段 `install`，CI 巨慢
5. **用了 `latest`** → 环境不可复现，同一 Dockerfile 不同时间构建结果不同
6. **`.dockerignore` 没配** → 把 `node_modules`/`.git` 打进上下文，镜像变大还拖慢构建

---

## 七、与手册 / 自测的衔接

- 本笔记对应 `docker-multistage-allstacks.md` 的「语法三要素 / 最佳实践 10 条 / 自测 7 题」
- 看完本笔记，直接做手册末尾**上午验收自测 7 题**，能口述答出 = 上午达标
- 下午实战：任选 Java / Go / Python 写 Dockerfile，优化到 `<100MB`，推 ACR 个人版验证

---

## 引用资料（国内优先 · 已核实在线）

- 尚硅谷 3 小时速通 Docker（含 Dockerfile 专章）：https://atguigu.com/video/307
- 尚硅谷 Docker 实战教程 BV1gr4y1U7CY：https://www.bilibili.com/video/BV1gr4y1U7CY
- 尚硅谷 基础篇（周阳）BV1Ls411n7mx：https://www.bilibili.com/video/BV1Ls411n7mx
- 黑马程序员 Docker BV1CJ411T7BK：https://www.bilibili.com/video/BV1CJ411T7BK
- 官方中文文档（多阶段构建）：https://docs.docker.top/build/building/multi-stage/
- 多阶段构建社区笔记：CSDN `2603_94880596` 文、人人代码《1.2GB 砍到 100MB 内》、Easton Dev《1GB 瘦身到 10MB》、博客园 `llcdbk` Node 双阶段实战、掘金 Dockerfile 详解
- 体积优化实战（Java/Python/前端）：devcxl.cn《Dockerfile 多阶段构建与镜像体积优化》
