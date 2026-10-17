# 学习资源总导航（国内优先）

> **引用原则（贯穿全部学习文档）**：
> 1. **国内源首选**——阿里云帮助、国内开发者社区、国内技术博客、B站课程优先于国外源。
> 2. **国外官方若有中文页，也作首选**——例如 `kubernetes.io/zh-cn`、`docs.docker.top`（docs.docker.com 中文镜像）、`helm.sh/zh`、`docs.gitlab.cn`（极狐）、`help.aliyun.com`（阿里云官方中文）。
> 3. **官方英文仅作兜底**——仅在无中文/国内源时引用。
> 4. 所有外链均经 2026-10-17 检索/核验（官方中文页已逐一确认在线；社区链接为检索返回的高质结果，使用前以实际打开为准）。
>
> 本文件覆盖《21天学习计划》涉及的全部技术栈。配套：Docker 专题见 `docker-multistage-allstacks.md`。

---

## 1. Docker
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 国内·官方中文镜像·首选 | Docker 文档中文站（docs.docker.com 完整中文镜像） | https://docs.docker.top/index.htm |
| 国内·官方中文镜像·备选 | Docker 中文网（另一份中文镜像） | http://docker.github.net.cn/ |
| 国内 | 阿里云「官方镜像加速」帮助（中文，配 registry-mirrors） | https://help.aliyun.com/knowledge_detail/60750.html |
| 国内 | 多阶段构建实战 Node 1GB→50MB | https://hipro.cc/category/devops/docker-multi-stage-build-image-optimization-tutorial |
| 国内 | Spring Boot 多阶段全流程 | https://m.jb51.net/server/36980267b.htm |
| 官方·英文·兜底 | 多阶段构建 | https://docs.docker.com/build/building/multi-stage/ |

## 2. Kubernetes
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 官方中文·首选 | Kubernetes 官方中文文档（概念/任务/教程） | https://kubernetes.io/zh-cn/docs/home/ |
| 国内 | 国内源安装（阿里云镜像，避 gcr 被墙，必看） | https://developer.aliyun.com/article/1147479 |
| 国内 | Kubernetes 中文社区 | https://www.kubernetes.org.cn |
| 国内·视频 | 尚硅谷 K8s 教程（B站·零基础首选） | https://www.bilibili.com/video/BV1Qv41167ck |
| 国内·视频 | 阿里云云原生技术公开课（张磊等） | 阿里云开发者社区搜「云原生技术公开课」 |
| 书籍/专栏 | 张磊《深入剖析 Kubernetes》极客时间；《Kubernetes in Action》 | 极客时间 / 图书 |
| 官方·英文·兜底 | K8s 英文文档 | https://kubernetes.io/docs/ |

## 3. Helm
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 官方中文·首选 | Helm 官网中文 | https://helm.sh/zh/ ｜ 文档 https://helm.sh/zh/docs/ |
| 国内 | Helm 中文文档镜像 | https://helm.kubernetes.ac.cn/ |
| 国内 | 保姆级中文简明教程 | https://www.hi-linux.com/posts/23277.html |
| 官方·英文·兜底 | Helm 英文文档 | https://helm.sh/docs/ |

## 4. GitLab CI/CD
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 官方中文·首选 | 极狐 GitLab 中文文档（你用的 jihulab 同系） | https://docs.gitlab.cn/docs/jh/ci/quick_start ｜ 复杂流水线 https://docs.gitlab.cn/docs/jh/ci/quick_start/tutorial/ |
| 国内 | 从 GitLab Flow 到 Pipeline 一文打通 | https://gitlab.cn/zh/news/cmtb65esd000spq0hlqkbzzez |
| 官方·英文·兜底 | GitLab CI 英文文档 | https://docs.gitlab.com/ee/ci/ |

## 5. Terraform（阿里云优先）
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 官方中文·首选 | 阿里云 Terraform 文档（Provider / 学习路径） | https://help.aliyun.com/zh/terraform/terraform-provider/ ｜ https://help.aliyun.com/zh/document_detail/95817.html |
| 国内 | 阿里云实践教程（VPC/ECS/OSS/ACK 示例） | help.aliyun.com 搜「Terraform 实践教程」 |
| 官方·英文·兜底 | HashiCorp Terraform 文档 | https://developer.hashicorp.com/terraform/docs |

## 6. ArgoCD / GitOps
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 官方中文·首选 | 阿里云「基于 Argo-CD 的 GitOps 最佳实践」 | https://help.aliyun.com/zh/cs/user-guide/argo-cd-based-gitops-best-practices |
| 国内 | 华为云「使用 Argo CD 实现持续交付」 | https://support.huaweicloud.com/intl/zh-cn/bestpractice-cce/cce_bestpractice_10007.html |
| 国内 | GitOps 实践指南（声明式部署/多集群） | https://pcltxs.github.io/2026/05/17/GitOps实践指南 ｜ https://www.yunthe.com/argocdgitops-chi-xu-jiao-fu-ping-tai-da-jian-yu-duo-ji-qun |
| 官方·英文·兜底 | Argo CD 文档 | https://argo-cd.readthedocs.io/ |

## 7. Prometheus / Grafana（无官方中文站，国内教程首选）
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 国内·首选 | Prometheus 监控告警快速入门（概念清晰） | https://helloyu.top/test-ops/monitor/prometheus-quickstart |
| 国内 | 全网最全：Prometheus+Grafana 智能监控告警系统 | https://developer.volcengine.com/articles/7582491098472267827 |
| 国内 | Grafana 自托管部署与运维实战 | https://kaiyuanbang.cn/zh-cn/tutorials/grafana-grafana |
| 国内 | 钉钉/飞书告警集成（Alertmanager → webhook） | 见上述文章中的告警通道配置 |
| 官方·英文·兜底 | Prometheus / Grafana 英文文档 | https://prometheus.io/docs/ ｜ https://grafana.com/docs/ |

## 8. Trivy（容器安全 / DevSecOps）
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 国内·首选 | Trivy 5 分钟上手（镜像/密钥/K8s 扫描） | https://blog.csdn.net/gitblog_00206/article/details/159983317 |
| 国内 | Trivy 深度实战 2026（工程化/CI 集成） | https://www.chenxutan.com/d/3199.html |
| 国内·技巧 | 国内 DB 镜像加速（避 GitHub 慢） | `export TRIVY_DB_REPOSITORY="https://gitee.com/aqua-security/trivy-db.git"` 或 `ghcr.io/aquasecurity/trivy-db:2` |
| 官方·英文·兜底 | Trivy 文档 | https://trivy.dev/ |

## 9. 本地 K8s / 边缘（kind / minikube / K3s）
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 官方中文·首选 | minikube 中文文档 | http://minikube.cn/ |
| 国内 | K3s 国内镜像安装（Rancher 国内源） | https://www.bingjie.vip/index.php/archives/238 ｜ WSL2 国内加速 https://www.cnblogs.com/zhenyu1/p/21383521 |
| 国内·技巧 | K3s 阿里云镜像（避免组件拉取失败） | 安装时加 `--system-default-registry=registry.cn-hangzhou.aliyuncs.com` |
| 官方·英文 | kind / minikube / K3s 英文文档 | https://kind.sigs.k8s.io/ ｜ https://minikube.sigs.k8s.io/ ｜ https://k3s.io/ |

## 10. CKA / 面试 / 视频课程（社区分享）
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 国内·视频·首选 | 尚硅谷 K8s（零基础） | https://www.bilibili.com/video/BV1Qv41167ck |
| 国内·视频 | B站 CKA 认证培训 | https://www.bilibili.com/video/BV1S7411m7vM |
| 国内·课程 | 阿里云云原生公开课 / 极客时间《Kubernetes 实战课》张磊 | 阿里云开发者社区 / 极客时间 |
| 官方·英文 | Killer.sh 模拟考试（官方，考试附赠） | https://killer.sh/ |

## 11. 阿里云（ACK / OSS / ACR）
| 优先级 | 资源 | 链接 |
| --- | --- | --- |
| 官方中文·首选 | 容器镜像服务 ACR（镜像加速器 / 仓库） | https://cr.console.aliyun.com |
| 官方中文 | 对象存储 OSS 控制台 | https://oss.console.aliyun.com |
| 官方中文 | 容器服务 ACK 控制台 | https://cs.console.aliyun.com |
| 官方中文 | Terraform 阿里云（见第 5 节） | help.aliyun.com/zh/terraform |

---

### 使用说明
- 每个 Day 的「视频/文档」具体链接，统一查本表对应技术，**默认点首选（国内/官方中文）**。
- 视频类（B站/阿里云公开课）优先于文字，上午输入阶段用；文档类下午实战随时查。
- 官方英文兜底仅在首选链接打不开或内容缺失时启用。
- 若某首选链接失效，先尝试同技术下的「备选/社区」项，并告知维护者更新本表。
