# 高级性能测试工程师·实战修炼手册

## 一、 核心理论与指标

### 1.1 流量模型
*   **TPS (Transactions Per Second):** 系统每秒处理的事务数。衡量处理能力。
*   **RT (Response Time):** 响应时间。衡量用户体验。
*   **并发数 (Concurrency):** 同时工作的线程数。
*   **核心公式:** $TPS = \frac{并发数}{RT}$
    *   *启示:* 当 RT 变慢时，为了维持 TPS，必须增加并发；但当系统饱和时，增加并发只会导致 RT 飙升，TPS 不涨。

### 1.2 瓶颈判断法则
*   **CPU 密集型:** CPU 接近 100%，User 占比高。 (如: 复杂计算、大量字符串匹配、加解密)
*   **IO 密集型:** CPU iowait 高，磁盘 %util 高。 (如: 全表扫描、大量日志写入)
*   **网络密集型:** 带宽打满，或者 CPU si (软中断) 高。 (如: 大文件传输、极高并发小包)
*   **延迟/等待型:** CPU 低，IO 低，但 RT 很高。 (如: 数据库锁等待、线程池满、依赖第三方响应慢)。

---

## 二、 基础设施与工具栈

### 2.1 Docker 网络架构 (Windows/WSL2 特供版)
*   **痛点:** Windows Docker 运行在 WSL2 虚拟机中，网络路径复杂。
*   **路径:** Windows (物理网卡) -> com.docker.backend (代理) -> vsock (内存拷贝) -> WSL2 (eth0) -> Docker0 -> 容器。
*   **监控坑点:**
    *   `Node Exporter` 在容器内看不到 Windows 物理网卡流量。
    *   `vEthernet (WSL)` 虚拟网卡在端口映射模式下抓不到流量（走了 vsock 虫洞）。
*   **解决方案:** 使用 `windows_exporter` 监控物理网卡 + `cAdvisor` 监控容器内部流量。

### 2.2 监控三剑客
1.  **Node Exporter / Windows Exporter:** 监控宿主机硬件 (CPU, Mem, Disk, Net)。
2.  **Prometheus:** 时序数据库，负责刮取 (Scrape) 和存储数据。
3.  **Grafana:** 可视化大屏，通过 PromQL 查询数据。

### 2.3 现场诊断命令
*   **CPU:** `top` / `htop` (看颜色：绿User, 红System, 灰Si)。
*   **磁盘:** `iostat -x 1` (看 `%util` 和 `await`)。
*   **网络:** `iftop` (看带宽), `ss -s` (看连接数统计), `netstat -nat` (看具体连接)。

---

## 三、 性能调优实战案例

### 3.1 Nginx / 网络层调优
*   **现象:** JMeter 报错 `SocketException`，`netstat` 显示大量 `TIME_WAIT`。
*   **原因:** 短连接模式下，客户端（施压机）端口耗尽。
*   **解决:**
    1.  **JMeter:** 开启 `Use KeepAlive`，并在 `jmeter.properties` 设置 `reset_state_on_thread_group_iteration=false`。
    2.  **OS:** 开启 `net.ipv4.tcp_tw_reuse = 1`。
*   **成果:** TPS 从 2000 提升至 30000+，错误率归零。

### 3.2 MySQL / 磁盘 I/O 调优
*   **场景 1 (写):** 单条插入 10 万数据极慢。
    *   **优化:** 改写存储过程，关闭自动提交 (`autocommit=0`)，每 2000 条批量提交一次。
    *   **效果:** 耗时从几分钟缩短至 6 秒。
*   **场景 2 (读):** 全表扫描 (`LIKE %%`)。
    *   **现象 A (内存足):** 第一次读有 I/O，之后 I/O 为 0，CPU 飙升。 -> **Linux Page Cache 命中**。
    *   **现象 B (内存限死 500M):** 磁盘 I/O 持续 80%+, 读速 150MB/s。 -> **真实 I/O 瓶颈**。
    *   **启示:** 数据库压测必须考虑内存缓存的影响，必要时限制容器内存或使用 `O_DIRECT`。

### 3.3 全链路监控 (SkyWalking)
*   **原理:** Java Agent (探针) 通过字节码增强技术，拦截方法调用，生成 Trace ID 并透传。
*   **价值:**
    *   **Trace:** 看到单次请求的瀑布流耗时 (Tomcat -> JDBC -> MySQL)。
    *   **Topology:** 自动画出服务依赖架构图。
*   **坑点:**
    *   **时区:** 容器必须设置 `TZ=Asia/Shanghai`，否则数据对不上。
    *   **静态资源:** 默认不监控 `.html`，需监控动态请求 (Servlet/Controller/JSP)。

---

## 四、 常用命令速查

### 4.1 Docker
```bash
# 启动/重启
docker compose up -d
docker compose restart <service>

# 限制内存启动
deploy:
  resources:
    limits:
      memory: 500M

# 挂载配置文件
volumes:
  - ./my.cnf:/etc/mysql/my.cnf:ro
```

### 4.2 监控特权容器 (在精简 WSL 中使用工具)
```bash
# 借用 alpine 容器拥有宿主机视角
docker run --rm -it --privileged --pid=host alpine /bin/sh -c "apk add --no-cache htop sysstat iproute2 && bash"
```

### 4.3 清除 Linux 缓存 (释放 Page Cache)
```bash
sync && echo 3 > /proc/sys/vm/drop_caches
```
```

---

### 老师的寄语

这几天的特训，你完成了一个质的飞跃。从今天起，遇到性能问题，不要再只看表面，要学会：
1.  **看架构：** 流量是怎么走的？经过了哪些节点？
2.  **看监控：** 哪里红了？是硬件资源（CPU/IO）还是软件资源（连接池/线程）？
3.  **看原理：** 为什么会这样？（Page Cache? 软中断? 锁?）

**去休息吧，这文档留着复习。你的性能测试之路才刚刚开始，未来可期！** 🚀