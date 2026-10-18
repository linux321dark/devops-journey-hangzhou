# Day 1 晚上实践 Checklist（阿里云 ECS 实例版 · 七语言全覆盖）

> **环境前提**：本实践在**个人付费的阿里云 ECS 实例**上完成（amd64 / Docker 29.9.1 已装 / 已配阿里云专属镜像加速器 `https://<实例ID>.mirror.aliyuncs.com` 首位）。  
> ECS 是个人求职准备资源，**不属于工行**，符合硬隔离原则（工行工时只做本职配管答疑 + 学工行内部规范）。  
> **目标**：七门主流语言各写一份「带真实依赖」的多阶段 Dockerfile → 全部 `docker build` 跑通 → 选 1 门做深（压体积 + 非 root + 推 ACR 验证）。  
> **目录约定**：在 ECS 上 `mkdir -p ~/devops-day1 && cd ~/devops-day1`，下文所有 `./<语言>-demo` 均为**相对当前目录**，不绑定 Mac 路径。

---

## 0. 前置确认（登录 ECS 后先做）

```bash
# 1. SSH 进 ECS（Mac 本地执行）
ssh root@<你的ECS公网IP>

# 2. 容器内引擎正常
docker info | grep -i "server version"      # 应显示 29.9.1
docker info | grep -A2 "Registry Mirrors"   # 应看到你的 *.mirror.aliyuncs.com（阿里云专属首位）

# 3. 当前目录约定
mkdir -p ~/devops-day1 && cd ~/devops-day1
pwd        # 记住这个目录，下文全相对它
```

- [x] ECS 可 SSH 登录
- [x] 已 `docker info | grep -iA3 "registry mirrors"` 确认**只**列出你的阿里云实例专属地址 `https://<实例ID>.mirror.aliyuncs.com`（内网最快）；若为空 / 含第三方死源(xuanyuan/daocloud/nju) / 公共 `mirror.aliyuncs.com`，先按学习计划 §6 / 坑16 改 `/etc/docker/daemon.json` 并 `sudo systemctl restart docker` 再 build（否则 `FROM` 会报 **not found**）
- [ ] ACR 个人版仓库已建：登录 `https://cr.console.aliyun.com` → 个人版 → 命名空间（如 `devops-journey`）→ 仓库（如 `day1-demo`）
- [x] 已 `cd` 到工作目录（本文约定 `~/devops-day1`）
- [ ] 已按 §0.4 安装 ECS 主机基础工具链
- [ ] 已按 §0.5 配好国内包管理器镜像源（否则拉依赖超时）

---

## 0.4 ECS 主机基础工具链安装（前置一次性）

> 全新 ECS（Ubuntu/Debian）默认没有 Go / Node / pip / Composer / Ruby。§0.5 的全局配置与 §2 主机侧 `go mod tidy` / `npm install` 都依赖这些工具，先一次性装好（Docker 镜像内已自带对应工具+镜像，这里只为满足**主机侧**步骤）。
> 注：即使不装主机工具，纯 `docker build` 也能跑（Dockerfile 已内置镜像）；装主机工具是为了你能在本机先解析依赖、生成 lockfile、本地验证。

```bash
# 0. 系统基础 + Python/pip + Ruby/Bundler + Composer（apt 直装）
sudo apt-get update
sudo apt-get install -y curl wget git build-essential ca-certificates \
  python3 python3-pip python3-venv \
  ruby ruby-dev bundler \
  composer

# 1. Go（apt 版本过旧会卡 go 1.23 指令，改用阿里云镜像二进制；版本号以镜像站最新 1.23.x 为准）
GO_VER=1.23.4
wget -q https://mirrors.aliyun.com/golang/go${GO_VER}.linux-amd64.tar.gz -O /tmp/go.tgz \
  && rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tgz \
  && ln -sf /usr/local/go/bin/go /usr/local/bin/go
go version

# 2. Node（apt 版本过旧，改用 npmmirror 二进制；版本号以镜像站最新 v22 为准）
NODE_VER=22.11.0
wget -q https://cdn.npmmirror.com/binaries/node/v${NODE_VER}/node-v${NODE_VER}-linux-x64.tar.gz -O /tmp/node.tgz \
  && tar -C /usr/local -xzf /tmp/node.tgz --strip-components=1
node -v && npm -v

# 3. Rust（主机侧非必需，Docker 内已构建；如需本机测，走 rsproxy 国内源）
# curl --proto '=https' --tlsv1.2 -sSf https://rsproxy.cn/rustup-init.sh | sh
```

> 若 `composer` / `gem` 仍报找不到：确认上一步 apt 已成功（你之前就是卡在没装）。Alibaba Cloud Linux 用 `yum`/`dnf` 而非 `apt`，本清单按 Ubuntu/Debian 写。

---

## 0.5 国内包管理器镜像源（ECS 必配，否则拉依赖超时）

> ⚠️ 阿里云镜像加速器只加速 **Docker 镜像 pull**，**不加速**语言级包下载（npm/pip/cargo/maven 等各有独立源）。ECS 直连 `proxy.golang.org` / `registry.npmjs.org` / `pypi.org` / `crates.io` / `repo1.maven.org` / `rubygems.org` / `packagist.org` 都会超时——你已踩到 Go 这个。
> 一次性在 ECS 主机全局配好下列源，主机侧 `go mod tidy` / `npm install` 即通；各语言 **Dockerfile 构建阶段也已内置对应镜像**，build 内 `go mod download` / `npm ci` / `pip install` / `cargo build` / `mvn` / `composer` / `bundle` 同样走国内源，无需你再手动加。

**主机一次性全局配置（复制执行一次）：**

```bash
# Go
go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,https://goproxy.cn,direct
go env -w GOSUMDB=sum.golang.google.cn
# npm
npm config set registry https://registry.npmmirror.com
# pip
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
# cargo (Rust)
mkdir -p ~/.cargo
cat > ~/.cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = 'rsproxy-sparse'
[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"
[net]
git-fetch-with-cli = true
EOF
# Maven (Java)
mkdir -p ~/.m2
cat > ~/.m2/settings.xml <<'EOF'
<settings>
  <mirrors>
    <mirror>
      <id>aliyun</id>
      <mirrorOf>central</mirrorOf>
      <name>aliyun maven</name>
      <url>https://maven.aliyun.com/repository/public</url>
    </mirror>
  </mirrors>
</settings>
EOF
# Composer (PHP)
composer config -g repos.packagist composer https://mirrors.aliyun.com/composer/
# RubyGems / Bundler
gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
bundle config mirror.https://rubygems.org https://gems.ruby-china.com
```

> Docker build 内镜像对照：Go `ENV GOPROXY` / npm `ENV npm_config_registry` / pip `ENV PIP_INDEX_URL` / cargo `~/.cargo/config.toml` / Maven 已写 `/root/.m2/settings.xml` / Composer `composer config` / Bundler `bundle config mirror`——均已写进各语言 Dockerfile。

---

## 1. 通用 `.dockerignore`（七语言共用，每个 demo 目录放一份）

```bash
cat > .dockerignore <<'EOF'
.git
node_modules
target
dist
__pycache__
*.md
Dockerfile
.dockerignore
vendor
EOF
```

> 每个 `./<语言>-demo` 目录里都放同一份 `.dockerignore`，避免把本地依赖/缓存打进构建上下文。

---

## 2. 七语言全覆盖（真实依赖 · 多阶段）

> 顺序建议：先 Go（最易压到 scratch，10–30MB，成就感强）→ 再 Java（杭州岗位对口）→ 其余按需。  
> 每门语言给「源码（真实依赖）→ Dockerfile → 构建验证」三件套，直接抄。

### 2.1 Node.js（TypeScript + Express，真实 Web 框架）

```bash
apt install npm
mkdir -p node-demo/src && cd node-demo
cat > package.json <<'EOF'
{
  "name": "node-demo",
  "version": "1.0.0",
  "scripts": {
    "build": "tsc",
    "start": "node dist/server.js"
  },
  "dependencies": {
    "express": "^4.21.2"
  },
  "devDependencies": {
    "typescript": "^5.7.2",
    "@types/express": "^5.0.0",
    "@types/node": "^22.10.2"
  }
}
EOF
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true
  },
  "include": ["src"]
}
EOF
cat > src/server.ts <<'EOF'
import express from 'express';
const app = express();
app.get('/', (_req, res) => res.json({ msg: 'DevOps Journey Day1 - Node', framework: 'express' }));
const port = 3000;
app.listen(port, () => console.log(`Node demo listening on :${port}`));
EOF
cp ../.dockerignore .
# 生成本地 lockfile（构建阶段用 npm ci 保证可复现）
npm install
cd ..
```

```dockerfile
# node-demo/Dockerfile
FROM node:22.11.0-alpine AS build
ENV npm_config_registry=https://registry.npmmirror.com
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22.11.0-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node","dist/server.js"]
```

---

### 2.2 Go（Gin 框架，真实 Web 依赖）

```bash
apt install golang-go
apt install gccgo-go
mkdir -p go-demo && cd go-demo
cat > main.go <<'EOF'
package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()
	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"msg": "DevOps Journey Day1 - Go", "framework": "gin"})
	})
	r.Run(":8080")
}
EOF
# 初始化模块并拉真实依赖（在 ECS 上联网生成 go.mod/go.sum；Go 代理已按 §0.5 全局配好）
go mod init go-demo
go get github.com/gin-gonic/gin@v1.10.0
go mod tidy
cp ../.dockerignore .
cd ..
```

```dockerfile
# go-demo/Dockerfile
# 注意：基础镜像必须钉死到具体补丁版本（golang:1.23 这种浮动 tag 经镜像加速常解析为 not found）。
# 此处 1.23.4 与 §0.4 主机安装的 GO_VER 保持一致。
FROM golang:1.23.4 AS build
# 国内 Go 代理（ECS 直连 proxy.golang.org 超时），保证 build 内 go mod download 可用
ENV GOPROXY=https://mirrors.aliyun.com/goproxy/,https://goproxy.cn,direct
ENV GOSUMDB=sum.golang.google.cn
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/app .

FROM scratch
COPY --from=build /bin/app /bin/app
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/   # gin 需 HTTPS/TLS 时带 CA
USER 65532:65532
EXPOSE 8080
CMD ["/bin/app"]
```

---

### 2.3 Java（Spring Boot，真实 Web 起步依赖）

```bash
mkdir -p java-demo/src/main/java/com/example && cd java-demo
cat > pom.xml <<'EOF'
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>java-demo</artifactId>
  <version>1.0.0</version>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.4.1</version>
  </parent>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
EOF
cat > src/main/java/com/example/JavaDemoApplication.java <<'EOF'
package com.example;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class JavaDemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(JavaDemoApplication.class, args);
    }
    @GetMapping("/")
    public String hello() {
        return "DevOps Journey Day1 - Java (Spring Boot real dep)";
    }
}
EOF
cp ../.dockerignore .
cd ..
```

```dockerfile
# java-demo/Dockerfile
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app
# 阿里云 Maven 镜像（直连 repo1.maven.org 超时）
RUN mkdir -p /root/.m2 && printf '%s' \
  '<settings><mirrors><mirror><id>aliyun</id><mirrorOf>central</mirrorOf><name>aliyun maven</name><url>https://maven.aliyun.com/repository/public</url></mirror></mirrors></settings>' \
  > /root/.m2/settings.xml
COPY pom.xml .
RUN mvn dependency:go-offline -q
COPY src ./src
RUN mvn package -DskipTests -q

FROM eclipse-temurin:17-jre-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
USER 1000
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
```

---

### 2.4 Python（FastAPI + Uvicorn，真实 ASGI 依赖）

```bash
mkdir -p py-demo && cd py-demo
cat > requirements.txt <<'EOF'
fastapi==0.115.6
uvicorn[standard]==0.34.0
EOF
cat > main.py <<'EOF'
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"msg": "DevOps Journey Day1 - Python", "framework": "fastapi"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
cp ../.dockerignore .
cd ..
```

```dockerfile
# py-demo/Dockerfile
FROM python:3.12.7-slim AS build
ENV PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
COPY . .

FROM python:3.12.7-slim AS runtime
WORKDIR /app
COPY --from=build /install /usr/local
COPY --from=build /app /app
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser
EXPOSE 8000
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]
```

---

### 2.5 Ruby（Sinatra + Puma，真实 Web 框架）

```bash
mkdir -p ruby-demo && cd ruby-demo
cat > Gemfile <<'EOF'
source "https://rubygems.org"
gem "sinatra", "~> 4.1"
gem "puma", "~> 6.5"
EOF
cat > app.rb <<'EOF'
require "sinatra"
require "json"
set :bind, "0.0.0.0"
set :port, 4567
get "/" do
  content_type :json
  { msg: "DevOps Journey Day1 - Ruby", framework: "sinatra" }.to_json
end
EOF
cp ../.dockerignore .
cd ..
```

```dockerfile
# ruby-demo/Dockerfile
FROM ruby:3.3.6-slim AS build
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*
COPY Gemfile ./
RUN bundle config set --global mirror.https://rubygems.org https://gems.ruby-china.com \
 && bundle config set --local without 'development test' \
 && bundle install --jobs 4
COPY . .

FROM ruby:3.3.6-slim AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
USER 1000
EXPOSE 4567
CMD ["ruby","app.rb"]
```

---

### 2.6 PHP（Slim 框架，真实微服务依赖，内置服务器运行）

```bash
mkdir -p php-demo/public && cd php-demo
cat > composer.json <<'EOF'
{
  "require": {
    "slim/slim": "^4.14",
    "slim/psr7": "^1.7"
  }
}
EOF
cat > public/index.php <<'EOF'
<?php
require __DIR__ . '/../vendor/autoload.php';
use Slim\Factory\AppFactory;
$app = AppFactory::create();
$app->get('/', function ($req, $res) {
    $res->getBody()->write(json_encode([
        "msg" => "DevOps Journey Day1 - PHP",
        "framework" => "slim"
    ]));
    return $res->withHeader('Content-Type', 'application/json');
});
$app->run();
EOF
cp ../.dockerignore .
cd ..
```

```dockerfile
# php-demo/Dockerfile
FROM composer:2 AS build
WORKDIR /app
RUN composer config -g repos.packagist composer https://mirrors.aliyun.com/composer/
COPY composer.json ./
RUN composer install --no-dev --no-scripts --optimize-autoloader
COPY . .

FROM php:8.3-cli-alpine AS runtime
WORKDIR /app
COPY --from=build /app /app
USER www-data
EXPOSE 8080
CMD ["php","-S","0.0.0.0:8080","-t","public"]
```

---

### 2.7 Rust（Actix-web，真实异步 Web 框架）

```bash
mkdir -p rust-demo/src && cd rust-demo
cat > Cargo.toml <<'EOF'
[package]
name = "rust-demo"
version = "0.1.0"
edition = "2021"

[dependencies]
actix-web = "4.9.0"
serde_json = "1.0"
EOF
cat > src/main.rs <<'EOF'
use actix_web::{get, App, HttpServer, Responder};

#[get("/")]
async fn index() -> impl Responder {
    actix_web::HttpResponse::Ok().json(serde_json::json!({
        "msg": "DevOps Journey Day1 - Rust",
        "framework": "actix-web"
    }))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    HttpServer::new(|| App::new().service(index))
        .bind(("0.0.0.0", 8080))?
        .run()
        .await
}
EOF
cp ../.dockerignore .
cd ..
```

```dockerfile
# rust-demo/Dockerfile
FROM rust:1.83.0-alpine AS build
WORKDIR /app
RUN apk add --no-cache musl-dev \
 && mkdir -p /usr/local/cargo \
 && printf '%s\n' '[source.crates-io]' 'replace-with = "rsproxy-sparse"' '[source.rsproxy-sparse]' 'registry = "sparse+https://rsproxy.cn/index/"' '[net]' 'git-fetch-with-cli = true' > /usr/local/cargo/config.toml
COPY . .
RUN cargo build --release

FROM scratch
COPY --from=build /app/target/release/rust-demo /app
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
USER 65532:65532
EXPOSE 8080
CMD ["/app"]
```

---

## 3. 全部构建 + 量体积（跑通七门）

```bash
cd ~/devops-day1
for d in node-demo go-demo java-demo py-demo ruby-demo php-demo rust-demo; do
  echo "===== build $d ====="
  docker build -t day1-$d ./$d && docker images day1-$d --format "{{.Size}}  $d"
done
```

**达标线（七门全 `docker build` 成功即覆盖完成）**：

| 技术栈          | 多阶段目标体积   | runtime 基础镜像                  |
| ------------ | --------- | ----------------------------- |
| Node         | 150–250MB | node:22-alpine                |
| Go           | 10–30MB   | scratch                       |
| Java(Spring) | 150–200MB | eclipse-temurin:17-jre-alpine |
| Python       | 200–400MB | python:3.12-slim              |
| Ruby         | 200–400MB | ruby:3.3-slim                 |
| PHP          | 150–250MB | php:8.3-cli-alpine            |
| Rust         | 5–20MB    | scratch                       |

> 七门全绿 = 覆盖达成。任意一门失败先查第 0 步镜加是否生效 + 卡点自救。

---

## 4. 深度优化示范（选 1 门做透：Go 或 Java）

挑 **Go**（最易压到 scratch）或 **Java**（杭州对口）做完整优化，作为面试可讲的「标杆产出」：


- [ ] 基础镜像钉版本且最小（alpine / slim / jre-alpine / scratch，不用 latest / 完整 ubuntu / 完整 JDK）
- [ ] 多阶段：build 工具链只在第一阶段，最终镜像无编译器（`docker history` 或 `docker run --rm <镜像> which go/mvn` 应为空）
- [ ] 依赖安装与代码复制分层（先 `COPY go.mod`/`pom.xml` 再拉依赖，利用缓存）
- [ ] 清包缓存：`apt` 后 `rm -rf /var/lib/apt/lists/*`；`apk cache clean`；`pip --no-cache-dir`
- [ ] `.dockerignore` 生效（上下文不含 `.git`/`node_modules`/`target`）
- [ ] 非 root：`USER` 已设（`docker run --rm <镜像> id -u` 返回非 0）
- [ ] Go 静态编译 `CGO_ENABLED=0` + `-ldflags="-s -w"`（否则 scratch 跑不了）

---

## 5. 推 ACR 个人版（深度那门先推，验证远端可用）

> push 到 ACR 走 `aliyuncs.com` 国内直连，**不需要 Clash 代理**（registry-mirrors 只管 pull）。

```bash
# 1. 登录（密码=ACR 个人版「访问凭证」里设的登录密码，非阿里云登录密码）
docker login --username=学徒321 registry.cn-hangzhou.aliyuncs.com

# 2. 打 tag（以 go-demo 为例；java 同理换目录/标签）
docker tag day1-go-demo registry.cn-hangzhou.aliyuncs.com/devops-journey/day1-demo:go-v1

# 3. 推送
docker push registry.cn-hangzhou.aliyuncs.com/devops-journey/day1-demo:go-v1

# 4. 拉回验证（确认远端可用）
docker rmi registry.cn-hangzhou.aliyuncs.com/devops-journey/day1-demo:go-v1
docker pull registry.cn-hangzhou.aliyuncs.com/devops-journey/day1-demo:go-v1
```

> 区域按 ACR 实际地域改（杭州=`cn-hangzhou`）。命名空间/仓库名换成第 0 步建的。

---

## 6. 扩展：基础设施多阶段（选做，补全「全栈」）

> 中间件通常不从零编译，多阶段用于「烘焙配置 / 预装插件 / 源码定制」。完整版见 `docker-multistage-allstacks.md` §8。两例速通：

**6.1 Nginx 静态前端（Node 构建 → Nginx 托管，约 50MB）**

```dockerfile
FROM node:22.11.0-alpine AS build
WORKDIR /app
COPY package*.json ./ && RUN npm ci
COPY . . && RUN npm run build
FROM nginx:1.27.4-alpine AS runtime
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
```

**6.2 Redis 自编译裁剪（debian:bookworm-slim，约 40–60MB）**

```dockerfile
FROM debian:bookworm AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential wget ca-certificates && rm -rf /var/lib/apt/lists/*
RUN wget -q https://download.redis.io/releases/redis-7.4.1.tar.gz && tar xzf redis-7.4.1.tar.gz && cd redis-7.4.1 && make BUILD_TLS=yes
FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /redis-7.4.1/src/redis-server /usr/local/bin/
COPY --from=build /redis-7.4.1/src/redis-cli /usr/local/bin/
USER 1000
EXPOSE 6379
CMD ["redis-server"]
```

> MySQL / Kafka / RocketMQ / RabbitMQ 多阶段多为「官方镜像 + 烘焙配置/插件」，详见手册 §8，不在本晚强制范围。

---

## 7. 沉淀到 Git

> ECS 上产出可直接在仓库目录操作：把 `~/devops-day1/*` 拷进本地克隆的 `devops-journey-hangzhou` 仓库（或 ECS 上也 clone 一份用 PAT 提交），再 push。

```bash
# 在仓库根（Mac 本地或 ECS 已 clone）
mkdir -p week1/day1
cp -r ~/devops-day1/* week1/day1/
git add week1/day1/ docs/day1-evening-practice.md
git commit -m "day1: 七语言多阶段 Dockerfile 实践（真实依赖）+ 推 ACR 验证"
git push -u origin main   # 密码填 jihulab Personal Access Token
```

> Dockerfile + 构建体积记录（`docker images` 截图 / 表格）一并提交，是 Day 1 核心产出，面试可讲。

---

## 验收标准（全满足 = Day 1 达标）

1. 七门语言（Node/Go/Java/Python/Ruby/PHP/Rust）Dockerfile **全部 `docker build` 成功**
2. 每门都**带真实依赖**（express/gin/spring-boot/fastapi/sinatra/slim/actix-web），非 hello world
3. 深度那门：最终镜像体积达到上表目标、**不含**编译器/构建工具、以**非 root** 运行
4. 深度那门成功推到 ACR 个人版并拉回验证
5. 产出物已提交 Git（本地 + push jihulab）

---

## 卡点自救

- **`docker build` 第一步 `load metadata for docker.io/library/xxx: not found`（404 而非超时）**：这是**镜像源坏了**，不是 tag 真的没有。常见成因：ECS 的 `/etc/docker/daemon.json` 沿用了 Mac 那套第三方死源（xuanyuan/daocloud/nju）或填了已停用的公共 `mirror.aliyuncs.com`，dockerd 查询这些源拿到错误响应，BuildKit 就报 not found。修正：ECS 的 daemon.json **只留**实例专属地址 `{"registry-mirrors":["https://<实例ID>.mirror.aliyuncs.com"]}`，`sudo systemctl restart docker`，再 `docker info | grep -iA3 "registry mirrors"` 确认生效；镜加正常后即使浮动 tag 也能解析，但稳妥起见所有基础镜像已钉死到具体补丁版本（见各 Dockerfile 的 `FROM`）。
- **pull 超时 / 基础镜像拉不到**：确认第 0 步 `Registry Mirrors` 首位为阿里云专属 `https://<实例ID>.mirror.aliyuncs.com`；极新 tag（如刚发的基础镜像）专属加速器可能未同步，临时 `export https_proxy=http://127.0.0.1:7897` 或改稍旧已缓存 tag。
- **`docker build`/`pull` 日志显示 `docker.io/library/...` 但怀疑没走镜加（关键误区）**：先分清两种可能。① 镜加是**透明代理**，日志里镜像规范名本就显示 `docker.io/library/xxx`，**不代表真直连**；判断真实是否走镜加看两点：`docker info | grep -iA3 "registry mirrors"` 是否列出你的阿里云地址，以及 `curl -sI https://<实例ID>.mirror.aliyuncs.com/v2/` 端点是否存活（200/401 均算通）。② 真没走：多半是改了 `/etc/docker/daemon.json` 后**没 `sudo systemctl restart docker` 让配置生效**，或 ECS 上配的是已停用的公共 `mirror.aliyuncs.com` / Mac 那套第三方死源 → dockerd 镜像拉取失败后**回退直连 docker.io**（ECS 上直连必超时）。修正：ECS 的 daemon.json 只留 `https://<实例ID>.mirror.aliyuncs.com`（同地域内网最快最稳），改完务必 `restart docker`。注意：阿里云镜加**只加速 docker.io(Docker Hub)**，不加速 gcr.io/quay.io/registry.k8s.io 等；你 Day1 基础镜像全是 docker.io，配好即加速。
- **Go 跑 scratch 报 `no such file` / panic**：漏 `CGO_ENABLED=0`，重 build；需出网再确认带了 `ca-certificates.crt`。
- **任何语言 `go mod tidy` / `npm ci` / `pip install` / `cargo build` / `mvn` / `composer` / `bundle` 报 `i/o timeout` 或 `dial tcp ...:443`**：都是默认境外源被墙。主机侧先按 §0.5 配全局国内源；Docker build 内已内置对应镜像（Go `GOPROXY` / npm `npm_config_registry` / pip `PIP_INDEX_URL` / cargo `config.toml` / Maven `settings.xml` / Composer `composer config` / Bundler `bundle config mirror`），无需额外操作。
- **Java `target/*.jar` 匹配不到**：确认 `mvn package` 成功产出 jar。
- **Python `pip install` 报编译错**：`build` 阶段已装 `gcc`，缺 `-dev` 包（如 `libpq-dev`）按需补。
- **Ruby bundle 报权限/编译错**：build 阶段装 `build-essential`；runtime 只装运行时库 `libpq5`。
- **PHP Slim 报类找不到**：确认 `composer install` 生成了 `vendor/autoload.php` 且被 `index.php` require。
- **Rust scratch 起不来**：确认用的是 `rust:*-alpine` + `musl-dev` 出静态二进制；否则改 `debian:bookworm-slim` 运行。
- **ACR 登录失败**：密码是 ACR 访问凭证密码，不是阿里云登录密码；控制台「访问凭证」重置。
- **push `denied: requested access`**：tag 的命名空间/仓库名与 ACR 里建的不一致，先核对。
