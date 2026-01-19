# High-Performance Testing Lab (企业级全链路性能测试实战靶场)

![License](https://img.shields.io/badge/License-MIT-blue.svg) ![Docker](https://img.shields.io/badge/Docker-Compose-2496ED.svg) ![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.5-green.svg) ![JMeter](https://img.shields.io/badge/Tools-JMeter-red.svg)

## 📖 项目简介 (Introduction)

本项目是一个基于 **Docker + Spring Boot + Middleware** 构建的企业级高并发性能测试实战环境。项目模拟了经典的互联网三层架构（Web -> Cache -> DB/MQ），并集成了 **Prometheus + Grafana + SkyWalking** 全链路可观测性平台。

**核心目标：** 复现真实的生产环境性能瓶颈（CPU/IO/内存/网络），并通过代码优化、架构调整、内核调优等手段解决问题，最终实现高可用与高性能。

---

## 🏗️ 架构拓扑 (Architecture)

系统部署在 Windows (WSL2) 的 Docker Desktop 环境下，采用 **A机 (施压机)** + **B机 (服务器)** 的物理隔离部署模式。

```text
[ Client (JMeter) ]
       │
       ▼
[ Nginx (Load Balancer) :80 ]
       │
       ├──> [ App Node 1 (Spring Boot + SkyWalking Agent) ]
       └──> [ App Node 2 (Spring Boot + SkyWalking Agent) ]
                     │
         ┌───────────┼──────────────┐
         ▼           ▼              ▼
    [ Redis ]   [ MySQL ]      [ RabbitMQ ]
     (Cache)      (DB)           (Async)
```

### 🛠️ 技术栈
*   **应用层:** Spring Boot 3.5, JDK 17
*   **中间件:** MySQL 8.0, Redis 7.0, RabbitMQ 3.9, Nginx
*   **监控层:** Prometheus, Grafana, Node Exporter, Windows Exporter, cAdvisor, MySQL Exporter
*   **APM:** Apache SkyWalking 9.5 (OAP + UI + Java Agent)
*   **测试/诊断:** JMeter, Arthas, sysstat (iostat), htop

---

## 🧪 核心实战场景与调优成果 (Performance Scenarios)

### 1. 基础设施层：Windows 端口耗尽与网络瓶颈
*   **场景:** Nginx 高并发转发压测。
*   **现象:** JMeter 报错 `SocketException`，TPS 卡在 2,000，`netstat` 显示大量 `TIME_WAIT`。
*   **根因:** 短连接导致 Windows 临时端口耗尽；Docker Desktop 虚拟网络转发消耗大量 CPU 软中断 (si)。
*   **调优:**
    *   JMeter 开启 `Use KeepAlive` 并禁用 `reset_state_on_thread_group_iteration`。
    *   Linux 内核开启 `net.ipv4.tcp_tw_reuse = 1`。
*   **成果:** TPS 提升至 **30,000+**，错误率归零。

### 2. 数据层：I/O 瓶颈与 Page Cache 欺骗
*   **场景:** 500万数据量的全表扫描 (`SELECT COUNT` & `LIKE`)。
*   **现象:**
    *   阶段一：磁盘读吞吐飙升至 **170MB/s** (真实 I/O)。
    *   阶段二：磁盘 I/O 归零，CPU 飙升 (Linux Page Cache 缓存了热数据，瓶颈转为内存计算)。
*   **实验:** 通过限制 Docker 容器内存至 **500MB**，成功复现了持续的磁盘 I/O 饱和 (Util 80%+)。
*   **优化:** 引入 Redis 缓存，命中率 99% 时响应时间从 **200ms** 降至 **5ms**。

### 3. 应用层：JVM 内存泄漏与 OOM 排查
*   **场景:** 模拟代码中使用 `static List` 持续堆积对象。
*   **现象:** GC 频率剧增，CPU 被 GC 线程占满，最终服务假死 (OOM)。
*   **排查:**
    1.  使用 **Arthas** `dashboard` 观察到 Old Gen 占用率 99.9%。
    2.  配置 `-XX:+HeapDumpOnOutOfMemoryError` 自动导出快照。
    3.  使用 **VisualVM / MAT** 分析 hprof 文件，定位到 `byte[]` 数组及引用根对象。

### 4. 架构层：异步削峰填谷
*   **场景:** 模拟秒杀下单写入。
*   **对比:**
    *   **同步写库:** TPS < 1,000 (受限于 DB 锁与 IO)。
    *   **引入 RabbitMQ:** 优化客户端连接为单例模式后，TPS 稳定在 **3,200+**，实现流量削峰。

---

## 📊 全链路监控体系 (Observability)

本项目解决了 Docker Desktop for Windows 监控的复杂性问题：

1.  **基础设施监控:**
    *   **windows_exporter:** 监控 Windows 物理网卡流量 (解决 WSL2 虚拟网卡无流量波形的问题)。
    *   **Node Exporter:** 监控 WSL2 虚拟机的 CPU 和 负载。
    *   **cAdvisor:** 监控容器级别的 CPU、内存和网络 (解决容器间流量区分问题)。

2.  **业务监控:**
    *   **MySQL Exporter:** 监控 QPS、连接数、Buffer Pool 命中率。
    *   **Grafana:** 集成 ID `1860`, `7362`, `14282` 等专业仪表盘。

3.  **链路追踪:**
    *   **SkyWalking:** 实现了 `Web -> Tomcat -> Redis/MySQL` 的完整调用链追踪。
    *   解决 Tomcat 启动脚本覆盖 `JAVA_OPTS` 导致探针失效的问题 (使用 `JAVA_TOOL_OPTIONS`)。

---

## 🚀 快速启动 (Quick Start)

### 前置要求
*   Docker Desktop (Windows/Mac/Linux)
*   JDK 8+ (用于本地开发/JMeter)

### 1. 启动基础设施
```bash
cd infrastructure
# 启动监控系统 (Prometheus, Grafana, SkyWalking...)
docker-compose -f docker-compose-monitor.yml up -d
# 启动中间件 (MySQL, Redis, RabbitMQ)
docker-compose -f docker-compose-middleware.yml up -d
```

### 2. 部署应用
```bash
cd app
# 构建 Spring Boot 镜像并启动集群 (App-1, App-2, Nginx)
docker-compose up -d --build
```

### 3. 访问入口
*   **业务入口 (Nginx):** `http://localhost:80`
*   **Grafana:** `http://localhost:3000` (admin/admin)
*   **SkyWalking UI:** `http://localhost:8088`
*   **RabbitMQ Console:** `http://localhost:15672` (admin/admin)

---

## 📂 目录结构说明

```text
├── infrastructure/         # Docker Compose 编排文件
│   ├── monitor/            # 监控相关 (Prometheus, Grafana, SkyWalking)
│   └── middleware/         # 中间件 (MySQL, Redis, MQ)
├── app/                    # Spring Boot 业务代码
│   ├── src/                # Java 源代码 (含性能测试案例 Controller)
│   ├── Dockerfile          # 应用镜像构建文件
│   └── docker-compose.yml  # 应用集群编排
├── configs/                # 配置文件挂载
│   ├── nginx/              # 负载均衡配置
│   ├── prometheus/         # 监控抓取规则
│   └── mysql/              # 数据库配置
├── jmeter-scripts/         # 压测脚本 (.jmx)
└── docs/                   # 详细复盘笔记与截图
```

---

## 📝 常用运维命令

**查看容器资源状态:**
```bash
docker stats
```

**进入应用容器:**
```bash
docker exec -it app-1 sh
```

**快速清除 Linux 缓存 (测试磁盘 IO 前使用):**
*(需在特权容器中执行)*
```bash
sync && echo 3 > /proc/sys/vm/drop_caches
```

---

### Author
*Designed & Built by [Your Name]*