# Docker 多阶段构建 · 全栈参考手册（杭州企业常见技术栈）

> 适用：Day 1 上午理论 → 下午实战的扩展素材。覆盖杭州企业主流技术栈：**Node / Go / Java(Spring Boot) / Python / Ruby / PHP / Rust**，以及基础设施类 **MySQL / Redis / Kafka / RocketMQ / RabbitMQ / Nginx 静态前端**。
>
> 已验证权威链接（2026-10-17 实测在线）：
> - 多阶段构建官方文档：https://docs.docker.com/build/building/multi-stage/
> - Dockerfile 最佳实践：https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
>
> 各语言基础镜像版本请到 https://hub.docker.com 核对最新 tag，本文钉版本号仅为示例，请按实际替换。

---

## 0. 通用语法（所有语言共用）

```dockerfile
FROM <构建镜像> AS build        # 命名阶段，可引用
... 编译/打包 ...
FROM <运行镜像>                 # 最终阶段（Docker 只保留最后一个 FROM）
COPY --from=build /path/产物 /path/产物
CMD [...]
```

- `COPY --from=` 可引用**阶段名**或**序号**（0 起）。
- 用 `--target build` 可单独构建某阶段（调试用）。
- 体积杠杆排序：**不装多余东西 > 多阶段 > 小基础镜像 > 钉版本 > 清缓存**，不是"拼命合并 RUN 层数"。

---

## 1. Node.js

```dockerfile
# 阶段1：依赖安装 + 构建
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# 阶段2：生产运行（只带运行时依赖）
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
USER node
EXPOSE 3000
CMD ["node","dist/index.js"]
```

- **体积目标**：单阶段 ~1GB → 多阶段 ~150–250MB（含 node_modules）。
- **关键坑**：
  - 必须 `npm ci`（锁定 lockfile），别用 `npm install`，否则不可复现。
  - `node:22-alpine` 已带 `node` 用户，直接 `USER node` 即可，无需自建。
  - 前端构建（Vite/Webpack）同理，runtime 阶段可不带 node_modules，只搬 `dist` + 用 Nginx 托管（见 §9）。

---

## 2. Go

```dockerfile
# 阶段1：编译
FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/app ./cmd/server

# 阶段2：scratch 运行（无 shell/包管理器，攻击面最小）
FROM scratch
COPY --from=build /bin/app /bin/app
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/   # 需联网时带 CA
USER 65532:65532
CMD ["/bin/app"]
```

- **体积目标**：单阶段 ~800MB+ → 多阶段 ~10–30MB。
- **关键坑**：
  - `CGO_ENABLED=0` 生成完全静态二进制，才能跑 `scratch`；否则缺动态库会 panic。
  - `-ldflags="-s -w"` 去调试符号再小一圈。
  - 需 HTTPS 出网时务必 `COPY ca-certificates.crt`，否则 TLS 握手失败。
  - 也可用 `gcr.io/distroless/static` 替代 scratch（自带 CA、可 `USER` ByName）。

---

## 3. Java / Spring Boot

### 3.1 Maven 版
```dockerfile
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline          # 先拉依赖，利用层缓存
COPY src ./src
RUN mvn package -DskipTests

FROM eclipse-temurin:17-jre-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
USER 1000
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
```

### 3.2 Gradle 版
```dockerfile
FROM gradle:8.10-jdk17 AS builder
WORKDIR /app
COPY build.gradle settings.gradle ./
RUN gradle dependencies --no-daemon
COPY . .
RUN gradle bootJar --no-daemon

FROM eclipse-temurin:17-jre-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
USER 1000
ENTRYPOINT ["java","-jar","/app/app.jar"]
```

### 3.3 进阶：jlink 自定义运行时（极致瘦身）
```dockerfile
FROM eclipse-temurin:17 AS builder
RUN "$JAVA_HOME/bin/jlink" \
    --add-modules java.base,java.logging,java.sql,jdk.httpserver \
    --strip-debug --no-man-pages --no-header-files \
    --compress=2 --output /jre

FROM alpine:3.21 AS runtime
COPY --from=builder /jre /opt/jre
COPY --from=builder /app/target/*.jar /app.jar
ENV PATH="/opt/jre/bin:$PATH"
USER 1000
ENTRYPOINT ["java","-jar","/app.jar"]
```

- **体积目标**：单阶段（含 JDK）~700MB → JRE runtime ~150–200MB → jlink 自定义 ~80–120MB。
- **关键坑**：JDK 只在 `builder` 阶段，runtime 用 `*-jre-*`（只含 JRE），别把 JDK 打进最终镜像。

---

## 4. Python

Python 难点：C 扩展（numpy/psycopg2/cryptography）需要编译工具链，必须在 build 阶段装、runtime 阶段丢。

### 4.1 含 C 扩展（推荐 wheel 预编译搬运）
```dockerfile
FROM python:3.12-slim AS build
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc python3-dev libpq-dev && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

FROM python:3.12-slim AS runtime
WORKDIR /app
COPY requirements.txt .
COPY --from=build /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt \
    && rm -rf /wheels
COPY . .
USER 1000
CMD ["python","app.py"]
```

### 4.2 纯 Python（无编译依赖，可更轻）
```dockerfile
FROM python:3.12-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

FROM gcr.io/distroless/python3-debian12 AS runtime
WORKDIR /app
COPY --from=build /deps /usr/local/lib/python3.12/site-packages
COPY . .
USER 1000
CMD ["app.py"]
```

### 4.3 AI/ML（torch/tensorflow 巨大）
- 多阶段对体积帮助有限（依赖本身就大），改用：runtime 用 `pytorch/pytorch:2.x-cuda` 官方镜像 + 只 COPY 应用代码；或 `python:3.12-slim` + `pip install torch --index-url https://download.pytorch.org/whl/cpu`（CPU 版小很多）。
- **关键坑**：`apt-get` 后必须 `rm -rf /var/lib/apt/lists/*`，否则该层白增几十 MB。

---

## 5. Ruby（Rails 为例）

```dockerfile
FROM ruby:3.3-slim AS build
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' \
    && bundle install --jobs 4
COPY . .
RUN bundle exec rails assets:precompile RAILS_ENV=production SECRET_KEY_BASE=dummy

FROM ruby:3.3-slim AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
USER 1000
ENV RAILS_ENV=production
CMD ["rails","server","-b","0.0.0.0"]
```

- **关键坑**：runtime 阶段只装**运行时库**（`libpq5` 而非 `libpq-dev`），编译工具链留在 build 阶段。

---

## 6. PHP（PHP-FPM 为例）

```dockerfile
FROM composer:2 AS build
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --optimize-autoloader
COPY . .

FROM php:8.3-fpm-alpine AS runtime
WORKDIR /app
# 按需装扩展（docker-php-ext-install 是 php 官方镜像专用）
RUN docker-php-ext-install pdo_mysql opcache \
    && docker-php-source delete
COPY --from=build /app /app
USER www-data
```

- **关键坑**：
  - PHP 扩展必须用 `docker-php-ext-install` / `pecl`，不能用 apt 直接装。
  - 静态站点（无后端）见 §9 用 Nginx + `COPY --from=build`。

---

## 7. Rust

```dockerfile
# 阶段1：编译（musl 静态，便于跑 scratch）
FROM rust:1.83-alpine AS build
WORKDIR /app
RUN apk add --no-cache musl-dev
COPY . .
RUN cargo build --release

# 阶段2：scratch 运行
FROM scratch
COPY --from=build /app/target/release/app /app
USER 65532:65532
CMD ["/app"]
```

- **体积目标**：~5–20MB。
- **关键坑**：用 `rust:*-alpine` + musl 才能出静态二进制跑 scratch；用 debian 系需带 libc，改跑 `debian:bookworm-slim`。

---

## 8. 基础设施 / 中间件（MySQL / Redis / Kafka / MQ）

> **重要认知**：这类组件**通常不自己从零编译**，而是消费官方镜像（钉版本 + 安全加固）。多阶段在这里主要用于三种场景：
> ① 从源码构建自定义版本/模块；② 预烘焙初始化 SQL / 配置文件；③ 生成 distroless 加固变体。
> 不要把数据库"编译进镜像"当常规做法——那是反模式。

### 8.1 MySQL（预烘焙初始化 + 加固）
```dockerfile
# 单阶段即可，重点是钉版本 + 烘焙 init + 非 root 官方已处理
FROM mysql:8.0-debian
# 初始化 SQL 自动执行（官方 entrypoint 约定目录）
COPY init/ /docker-entrypoint-initdb.d/
# 自定义配置
COPY my.cnf /etc/mysql/conf.d/zz-custom.cnf
# 官方镜像已非 root 运行(mysql 用户)，无需额外 USER
```
- 若要从源码构建自定义 MySQL（极少），用 `FROM debian:bookworm AS build` 编译，runtime 用 `debian:bookworm-slim` 搬 `mysqld`。

### 8.2 Redis（从源码构建 + 裁剪）
```dockerfile
FROM debian:bookworm AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential wget ca-certificates && rm -rf /var/lib/apt/lists/*
RUN wget -q https://download.redis.io/releases/redis-7.4.1.tar.gz \
    && tar xzf redis-7.4.1.tar.gz \
    && cd redis-7.4.1 && make BUILD_TLS=yes

FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /redis-7.4.1/src/redis-server /usr/local/bin/
COPY --from=build /redis-7.4.1/src/redis-cli /usr/local/bin/
COPY redis.conf /usr/local/etc/redis.conf
USER 1000
EXPOSE 6379
CMD ["redis-server","/usr/local/etc/redis.conf"]
```
- 体积：官方 redis 镜像 ~100MB → 自编译 slim ~40–60MB，且可按需 `BUILD_TLS` / 模块。

### 8.3 Kafka（预烘焙连接器 / 插件）
```dockerfile
# 阶段1：编译自定义 connector jar
FROM maven:3.9-eclipse-temurin-17 AS connector
WORKDIR /connector
COPY connector-pom.xml .
RUN mvn dependency:go-offline
COPY connector-src ./src
RUN mvn package -DskipTests

# 阶段2：官方 Kafka 运行时 + 注入自定义 jar
FROM confluentinc/cp-kafka:7.7.0
COPY --from=connector /connector/target/*.jar /usr/share/java/kafka/
```
- 纯官方 Kafka 直接 `FROM confluentinc/cp-kafka:7.7.0` 即可，多阶段只在**自研连接器/插件**时有意义。

### 8.4 RocketMQ（杭州企业高频，阿里开源）
```dockerfile
# 阶段1：构建 broker 自定义配置 / 从源码编译（可选）
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /rmq
COPY . .
RUN mvn package -DskipTests

# 阶段2：官方镜像 + 注入配置
FROM apache/rocketmq:5.3.0
COPY --from=build /rmq/dist/broker.conf /home/rocketmq/rocketmq-5.3.0/conf/broker.conf
# 官方镜像已非 root(rocketmq 用户)
```
- 杭州电商/支付场景 RocketMQ 极常见，面试常问；多阶段用于**烘焙 broker.conf /  Namesrv 配置 / 自定义插件**。

### 8.5 RabbitMQ（烘焙插件 + 配置）
```dockerfile
FROM rabbitmq:3.13-management-alpine AS runtime
COPY enabled_plugins /etc/rabbitmq/enabled_plugins
COPY rabbitmq.conf /etc/rabbitmq/rabbitmq.conf
# 启动即加载插件与配置；官方镜像已非 root(rabbitmq 用户)
```
- management 插件自带 Web 控制台（端口 15672），学习演示方便。

---

## 9. Nginx 静态前端（Vite/React/Vue 构建产物）

```dockerfile
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.27-alpine AS runtime
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
# 官方 nginx 镜像已非 root(nginx 用户)
EXPOSE 80
```

- 体积：build 阶段 ~1GB → runtime ~50MB（只 Nginx + 静态文件）。
- 这是前端项目最标准的多阶段模板，必会。

---

## 10. 体积目标速查表

| 技术栈 | 单阶段约 | 多阶段目标 | runtime 基础镜像 |
| --- | --- | --- | --- |
| Node | ~1000MB | 150–250MB | node:22-alpine |
| Go | ~800MB | 10–30MB | scratch / distroless/static |
| Java(Spring) | ~700MB | 150–200MB(JRE) / 80–120MB(jlink) | eclipse-temurin:17-jre-alpine |
| Python(含C扩展) | ~900MB | 200–400MB | python:3.12-slim |
| Ruby(Rails) | ~900MB | 200–400MB | ruby:3.3-slim |
| PHP-FPM | ~400MB | 150–250MB | php:8.3-fpm-alpine |
| Rust | ~1500MB | 5–20MB | scratch |
| 前端静态 | ~1000MB | ~50MB | nginx:1.27-alpine |
| Redis(自编译) | ~100MB | 40–60MB | debian:bookworm-slim |
| MySQL/Kafka/RMQ/Rabbit | 官方镜像 | 钉版本+加固即可 | 官方镜像 + 烘焙配置 |

---

## 11. 通用最佳实践（纠偏版）

1. **多阶段**是体积优化核心（build/runtime 分离）。
2. runtime 选**最小基础镜像**：alpine / distroless / scratch / JRE 镜像，别用完整 JDK/SDK/Ubuntu。
3. **钉版本，不用 `latest`**：`golang:1.26`、`eclipse-temurin:17-jre-alpine`、`alpine:3.21`，可进一步钉 digest。
4. **`.dockerignore`** 排除：`.git`、`node_modules`、`target`、`__pycache__`、`*.md`、本地配置、`.env`。
5. **不装不必要包**；`apt` 后 `rm -rf /var/lib/apt/lists/*`，`apk` 后 `apk cache clean`。
6. **非 root 运行**（`USER`），官方镜像多数已内置非 root 用户（node/www-data/nginx/mysql/rabbitmq 等）。
7. 提速靠**层缓存**：不常变指令放前（先 `COPY pom.xml`/`package.json` → 拉依赖），常变源码放后。
8. **密钥绝不写进镜像**（用构建参数 `--build-arg` / Secret / 运行时挂载）。
9. 定期 `docker build --pull` 拿基础镜像安全更新。
10. 可复现：锁版本 + 不用 latest + 依赖 lockfile（package-lock / go.sum / Gemfile.lock / poetry.lock）。

---

## 12. 上午验收自测（结束前能答出 = 过关）

1. 多阶段靠哪条指令把产物从 build 搬进 runtime？
2. 为什么最终用 scratch/distroless 比 ubuntu 更安全？
3. Go 静态编译为什么要 `CGO_ENABLED=0`？Python 的 C 扩展又为什么需要 build 阶段留 gcc？
4. Java 多阶段里 JDK 和 JRE 各出现在哪个阶段、为什么？
5. MySQL/Redis/Kafka 这类中间件，多阶段主要解决什么（别答"编译数据库"）？
6. 不写 `.dockerignore` 会怎样（举一例）？
7. 前端静态站点多阶段，runtime 用什么镜像、为什么不用 node 镜像？

---

> 本手册为 Day 1 上午理论扩展。下午实战建议：任选 1–2 个你目标岗位最相关的栈（杭州优先 Java / Go / Python）写 Dockerfile，多阶段优化到上表目标体积，推 ACR 个人版验证。
