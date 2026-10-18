# Docker 视频配套笔记（尚硅谷 / 黑马 · 可直接读，免刷视频）

> **用途**：Day 1 上午"视频跟练"环节的替代/前置读物。把 B 站尚硅谷、黑马 Docker 教程中 Dockerfile 与多阶段构建的精华整理成文字，配合 `docker-multistage-allstacks.md` 食用。
> **资料来源**：① 尚硅谷 `BV1gr4y1U7CY`（Docker 实战教程/docker 教程天花板）、`BV1Ls411n7mx`（周阳基础篇）、`atguigu.com/video/307`（3 小时速通 Docker，含 Dockerfile 专章）；② 黑马 `BV1CJ411T7BK`；③ 社区笔记（CSDN / 博客园 / 掘金 / 人人代码等，见文末引用）；④ 官方文档 `docs.docker.top`、阿里云帮助。
> **说明**：本人未逐帧观看视频，笔记依据课程分集大纲 + 社区已整理笔记 + 官方文档整合而成；关键技术点均以官方文档兜底核对。建议先看本笔记再按需回看对应分集加深印象。

---

## 零、官方权威参考（以官方文档为准 · 中文镜像首选）

> 本笔记基于视频/社区整理"讲什么、为什么"；**遇到语法/参数细节必须回到官方文档**——它是唯一权威。你提供的两条官方参考已核实在线，按"国内优先 / 官方中文首选"原则优先用 `docs.docker.top` 中文镜像：

| 参考 | 中文镜像（首选） | 官方英文（兜底） |
| --- | --- | --- |
| **Dockerfile 指令参考**（全部 18 条指令的权威释义） | https://docs.docker.top/reference/dockerfile | https://docs.docker.com/reference/dockerfile |
| **Docker CLI 命令参考**（build/run/image/container/network/volume 等总入口） | https://docs.docker.top/reference/cli/docker/ | https://docs.docker.com/reference/cli/docker/ |

- 你原链接带 `?spm=...`（阿里云转发追踪参数），文档里统一用干净链接。
- CLI 子命令深链格式：`https://docs.docker.top/reference/cli/docker/<对象>/<动作>/`，例如构建 `image/build/`、运行 `container/run/`、网络 `network/create/`、卷 `volume/create/`。
- Dockerfile 各指令在参考页内有独立锚点（如 `#from` `#run` `#copy` `#entrypoint`），页内搜索指令名即可定位。

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

## 三、Dockerfile 核心指令速查（分三类 + 案例）

> 分类逻辑：① **镜像类**——构建期指令，决定"镜像里有什么"；② **容器类**——运行期指令，决定"容器怎么跑"；③ **仓库类**——并非 Dockerfile 指令，而是镜像构建后与仓库交互的 `docker` CLI 操作（Day 1 下午推 ACR 必用），一并列出。

### 3.1 镜像类指令（构建期）

| 指令 | 作用 | 案例 | 关键注意 |
| --- | --- | --- | --- |
| `FROM` | 指定基础镜像（第一条指令） | `FROM golang:1.26.0-alpine AS builder` | 多阶段可多次出现，配 `AS <名>` |
| `ARG` | 构建期变量（不写入镜像） | `ARG VER=1.26.0` → `FROM golang:${VER}` | 与 ENV 区别在生命周期；传版本号首选 |
| `ENV` | 设置环境变量（写入镜像） | `ENV NODE_ENV=production TZ=Asia/Shanghai` | 会固化进镜像，密钥别放这 |
| `WORKDIR` | 切换工作目录（自动建目录） | `WORKDIR /app` | 比 `RUN cd` 清晰，后续指令基于此路径 |
| `RUN` | 构建期执行命令（装依赖/编译） | `RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*` | 用 `&&` 连命令并清缓存 |
| `COPY` | 复制本地文件进镜像 | `COPY package.json ./` / 多阶段 `COPY --from=builder /app/dist ./dist` | 跨阶段搬运靠 `--from` |
| `ADD` | 类似 COPY，额外支持 tar 自动解压 / 远程 URL | `ADD app.tar.gz /app/` | 一般优先 COPY；需解压 tar 才用 ADD |
| `LABEL` | 添加镜像元数据（键值对） | `LABEL maintainer="dev@example.com" version="1.0"` | 便于检索/溯源，不影响运行 |
| `ONBUILD` | 延迟指令，被 FROM 继承时触发 | `ONBUILD COPY . /app` | 做基础镜像模板时用，慎用 |

### 3.2 容器类指令（运行期）

| 指令 | 作用 | 案例 | 关键注意 |
| --- | --- | --- | --- |
| `CMD` | 容器启动默认命令（可被 `docker run` 覆盖） | `CMD ["node","dist/index.js"]` | 多条只生效最后一条 |
| `ENTRYPOINT` | 容器主命令（不可被覆盖，参数追加） | `ENTRYPOINT ["java","-jar"]` | 固化程序本体时用 |
| `USER` | 指定运行用户（安全必做：非 root） | `USER 1000` / `USER appuser` | 默认 root，生产必切 |
| `EXPOSE` | 声明暴露端口（仅文档作用，不真正映射） | `EXPOSE 8080 9090` | 真正映射靠 `docker run -p` |
| `VOLUME` | 声明挂载点（数据持久化/与主机共享） | `VOLUME ["/data","/var/log"]` | 运行期数据用挂载，别写进镜像层 |
| `HEALTHCHECK` | 声明容器健康检测 | `HEALTHCHECK --interval=30s CMD curl -f http://localhost:8080/health \|\| exit 1` | 配合编排做自愈/流量剔除 |
| `STOPSIGNAL` | 容器停止时发送的信号 | `STOPSIGNAL SIGTERM` | 优雅停机用 |
| `SHELL` | 指定运行 RUN/CMD/ENTRYPOINT 的 shell | `SHELL ["/bin/bash","-c"]` | Windows 镜像或需 bash 特性时 |

> **挂载与网络补充**（视频必讲、易漏）：
> - **挂载（持久化数据）**：Dockerfile 里 `VOLUME` 只"声明"挂载点；真正挂载在运行时做——`docker run -v /host/data:/data myapp`（主机目录）或 `docker run -v myvol:/data myapp`（命名卷，Docker 管理）。**数据库/日志/配置必须挂卷，否则容器一删数据全没**。
> - **网络**：Dockerfile 只有 `EXPOSE` 做端口声明；真正联网在运行时——`docker run -p 8080:8080`（端口映射）、`docker run --network mynet`（自定义网络，容器间用服务名互访）。Compose 里用 `ports:` + `networks:` 配置。

> `CMD` vs `ENTRYPOINT`：ENTRYPOINT 定"程序"，CMD 给"默认参数"。生产常用 `ENTRYPOINT ["java","-jar"]` + `CMD ["app.jar"]` 组合——`docker run myapp other.jar` 能覆盖 jar 名。

> 📌 **官方权威释义（必查）**：上面 18 条指令的参数、语法、默认值、注意事项，以 Dockerfile 官方参考为准——中文镜像 https://docs.docker.top/reference/dockerfile （英文兜底 https://docs.docker.com/reference/dockerfile ）。页内每条指令有独立锚点（如 `#from` `#run` `#copy` `#entrypoint`），也可直接页内搜索指令名定位。视频/社区笔记有出入时，**以官方为准**。

### 3.3 仓库类操作（构建后 · 与镜像仓库交互）

> 以下不是 Dockerfile 指令，而是 `docker` CLI 对镜像仓库（Docker Hub / 阿里云 ACR / 私有仓库）的操作。Day 1 下午推 ACR 个人版必用。

| 操作 | 作用 | 案例 |
| --- | --- | --- |
| `docker tag` | 给镜像打仓库地址标签 | `docker tag myapp:1.0 registry.cn-hangzhou.aliyuncs.com/yourns/myapp:1.0` |
| `docker push` | 推送镜像到仓库 | `docker push registry.cn-hangzhou.aliyuncs.com/yourns/myapp:1.0` |
| `docker pull` | 从仓库拉取镜像 | `docker pull registry.cn-hangzhou.aliyuncs.com/yourns/myapp:1.0` |
| `docker images` | 查看本地镜像（验证体积） | `docker images \| grep myapp` |
| `docker history` | 查看镜像层构成 | `docker history myapp:1.0` |

> ACR 实操提示：推送前先 `docker login --username=你的阿里云账号 registry.cn-hangzhou.aliyuncs.com`（密码用 ACR 登录密码/临时令牌），再 `tag` + `push`。详见 `docker-multistage-allstacks.md` 与学习计划 §6。

---

### 3.4 Docker CLI 命令官方参考对照

> 下面命令的**权威参数说明**见 Docker CLI 官方参考（中文镜像首选）：https://docs.docker.top/reference/cli/docker/ 。子命令深链格式 `.../docker/<对象>/<动作>/`，旧式顶层命令（如 `docker build`）与对象式（`docker image build`）等价，已核实 `image/build/`、`container/run/` 在线。

| 用途 | 命令（对象式 / 旧式） | 官方中文参考 |
| --- | --- | --- |
| 构建镜像（Day1 核心） | `docker image build` / `docker build` | https://docs.docker.top/reference/cli/docker/image/build/ |
| 列出本地镜像（看体积） | `docker image ls` / `docker images` | https://docs.docker.top/reference/cli/docker/image/ls/ |
| 删除镜像 | `docker image rm` / `docker rmi` | https://docs.docker.top/reference/cli/docker/image/rm/ |
| 打仓库标签（推 ACR 前） | `docker image tag` / `docker tag` | https://docs.docker.top/reference/cli/docker/image/tag/ |
| 推送镜像 | `docker image push` / `docker push` | https://docs.docker.top/reference/cli/docker/image/push/ |
| 拉取镜像 | `docker image pull` / `docker pull` | https://docs.docker.top/reference/cli/docker/image/pull/ |
| 查看镜像层构成 | `docker image history` | https://docs.docker.top/reference/cli/docker/image/history/ |
| 运行容器（-p 映射 / -v 挂载 / --network） | `docker container run` / `docker run` | https://docs.docker.top/reference/cli/docker/container/run/ |
| 列出容器 | `docker container ls` / `docker ps` | https://docs.docker.top/reference/cli/docker/container/ls/ |
| 进容器排错 | `docker container exec` | https://docs.docker.top/reference/cli/docker/container/exec/ |
| 看容器日志 | `docker container logs` | https://docs.docker.top/reference/cli/docker/container/logs/ |
| 删除容器 | `docker container rm` | https://docs.docker.top/reference/cli/docker/container/rm/ |
| 自定义网络 | `docker network create` / `ls` / `connect` | https://docs.docker.top/reference/cli/docker/network/ |
| 数据卷 | `docker volume create` / `ls` | https://docs.docker.top/reference/cli/docker/volume/ |
| 仓库认证（推 ACR 前 login） | `docker login` / `docker logout` | https://docs.docker.top/reference/cli/docker/login/ |

> 链接为官方 CLI 参考标准路径（已核实 `image/build/`、`container/run/` 在线）；如个别动作名有差异，在对应页面内搜索命令即可定位。

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
FROM golang:1.26.0-alpine AS builder
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

**Python 范例（依赖隔离搬运 / 纯 Python distroless）**：
```dockerfile
# 阶段1：安装依赖 + 打包（依赖装进独立前缀，便于整体搬运）
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
COPY . .
RUN pip install --no-cache-dir --prefix=/install .
# 阶段2：运行（只带运行时 + 依赖，无构建缓存）
FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /install /usr/local
COPY --from=builder /app /app
USER 1000
CMD ["python","/app/main.py"]
```
> 关键点：`--prefix=/install` 把依赖装进独立目录再整体搬，避免把构建缓存带进最终镜像；`--no-cache-dir` 不留存 pip 缓存。纯 Python 也可上 `gcr.io/distroless/python3` 进一步瘦身。含 C 扩展的库（如 numpy）用此方式搬运预编译 wheel 最稳。

**Ruby (Rails) 范例**：
```dockerfile
FROM ruby:3.3-slim AS builder
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --path /vendor/bundle
COPY . .
RUN bundle exec rake assets:precompile
FROM ruby:3.3-slim
WORKDIR /app
COPY --from=builder /app /app
COPY --from=builder /vendor/bundle /vendor/bundle
ENV RAILS_ENV=production
USER 1000
EXPOSE 3000
CMD ["bundle","exec","puma","-C","config/puma.rb"]
```
> 把 `Gemfile` 提前单独 COPY 复用 bundle 缓存；assets 预编译放构建阶段，运行阶段只拿成品。

**PHP (PHP-FPM) 范例**：
```dockerfile
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs
COPY . .
RUN composer dump-autoload --no-dev --optimize
FROM php:8.3-fpm-alpine
WORKDIR /var/www/html
COPY --from=vendor /app /var/www/html
USER www-data
```
> PHP 主流多阶段：composer 阶段装依赖，运行阶段用 `php:8.3-fpm-alpine`；nginx 单独容器反向代理（见 `docker-multistage-allstacks.md` Nginx 节）。

**Rust 范例（→ scratch）**：
```dockerfile
FROM rust:1.80-alpine AS builder
WORKDIR /app
COPY . .
RUN cargo build --release
FROM scratch
COPY --from=builder /app/target/release/myapp /myapp
USER 65532:65532
ENTRYPOINT ["/myapp"]
```
> Rust 静态编译产物可直接跑 scratch；用 `rust:alpine` + musl 目标交叉编译可得纯静态二进制，体积 10MB 级。

> **范例覆盖说明**：以上覆盖杭州企业最常见的应用语言（Node / Go / Java / Python / Ruby / PHP / Rust）。MySQL / Redis / Kafka / RocketMQ / RabbitMQ / Nginx 等**基础设施/中间件**的多阶段（烘焙配置、源码编译瘦身、自定义运行时）范例在 `docker-multistage-allstacks.md` 全栈手册，不在本笔记重复。

---

## 五、体积优化实战 checklist（可直接用）

1. **多阶段构建**：build/runtime 分离，核心手段
2. **runtime 选最小基础镜像**：alpine / distroless / scratch / `*-jre-slim`，别用完整 JDK/SDK
3. **钉版本，不用 `latest`**：`golang:1.26.0`、`node:20-slim`、`alpine:3.18`（可再钉 digest）
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
- 下午实战：任选上面任一语言（Node / Go / Java / Python / Ruby / PHP / Rust）写 Dockerfile，优化到 `<100MB`，推 ACR 个人版验证

---

## 引用资料（国内优先 · 已核实在线）

- 尚硅谷 3 小时速通 Docker（含 Dockerfile 专章）：https://atguigu.com/video/307
- 尚硅谷 Docker 实战教程 BV1gr4y1U7CY：https://www.bilibili.com/video/BV1gr4y1U7CY
- 尚硅谷 基础篇（周阳）BV1Ls411n7mx：https://www.bilibili.com/video/BV1Ls411n7mx
- 黑马程序员 Docker BV1CJ411T7BK：https://www.bilibili.com/video/BV1CJ411T7BK
- 官方中文文档（多阶段构建）：https://docs.docker.top/build/building/multi-stage/
- **官方权威参考（本笔记以之为准）**：Dockerfile 指令参考 https://docs.docker.top/reference/dockerfile （英文 https://docs.docker.com/reference/dockerfile ）；Docker CLI 命令参考 https://docs.docker.top/reference/cli/docker/ （英文 https://docs.docker.com/reference/cli/docker/ ）
- 多阶段构建社区笔记：CSDN `2603_94880596` 文、人人代码《1.2GB 砍到 100MB 内》、Easton Dev《1GB 瘦身到 10MB》、博客园 `llcdbk` Node 双阶段实战、掘金 Dockerfile 详解
- 体积优化实战（Java/Python/前端）：devcxl.cn《Dockerfile 多阶段构建与镜像体积优化》
