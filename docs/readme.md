没问题！这是正确的选择。

**Prometheus + Grafana** 是现在互联网大厂的标配监控方案。学会它，你就拥有了**“上帝视角”**。

以后你再也不用开着 `htop` 和 `iostat` 两个黑窗口死死盯着看了，你可以坐在老板椅上，喝着咖啡，看着大屏上五颜六色的折线图，指着某一个波峰说：“看，昨晚 8 点，数据库 IO 爆了。”

---

### 第七课：上帝视角 —— 搭建全链路监控平台

我们将在你的 **服务器 B** 上部署这套系统。

#### 1. 核心架构（三件套）

我们要部署三个组件，它们的关系如下：

1.  **Node Exporter (苦力):** 负责干脏活。它安装在服务器上，专门采集 CPU、内存、磁盘 IO、网络流量等数据，并暴露一个 HTTP 接口。
    *   *替代了你之前的 `htop`, `iostat`, `ifconfig`*。
2.  **Prometheus (数据库):** 负责存储。它每隔几秒钟去 Node Exporter 那里“抓”一次数据，存到自己的时序数据库里。
3.  **Grafana (电视机):** 负责展示。它去 Prometheus 里查数据，画成炫酷的图表。

---

### 第二步：编写配置文件

我们在 B 机上创建一个新目录 `monitor_system`，然后创建两个文件。

#### 1. 创建 `prometheus.yml` (配置抓取规则)

这是 Prometheus 的大脑，告诉它去哪里抓数据。

```yaml
global:
  scrape_interval: 5s     # 每 5 秒抓一次 (高精度监控)
  evaluation_interval: 5s

scrape_configs:
  - job_name: 'server-b-monitor'
    static_configs:
      - targets: ['node-exporter:9100'] # 指向同一个 Docker 网络下的 node-exporter
```

#### 2. 创建 `docker-compose.yml` (一键部署)

注意：我们需要把这个监控系统和宿主机的一些系统目录挂载起来，这样才能读到真实的硬件数据。

```yaml
version: '3.8'

services:
  # 1. 数据采集器 (替代 htop/iostat)
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    expose:
      - 9100

  # 2. 时序数据库
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml # 挂载配置文件
      - prometheus_data:/prometheus                     # 持久化存储数据
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d' # 数据保留15天

  # 3. 炫酷仪表盘
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana # 持久化存储配置和图表
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin # 初始密码

volumes:
  prometheus_data:
  grafana_data:
```

---

### 第三步：启动并验证

1.  **启动：**
    在 B 机 `monitor_system` 目录下执行：
    ```bash
    docker compose up -d
    ```

2.  **检查数据源 (Prometheus):**
    *   在 A 机浏览器访问 B 机 IP：`http://192.168.x.x:9090`。
    *   点顶部菜单 **Status** -> **Targets**。
    *   如果看到 `server-b-monitor` 的状态是 **UP (绿色)**，说明数据链路通了！

---

### 第四步：Grafana 配置（见证奇迹的时刻）

这里是大部分新手最容易卡住的地方，请一步步来：

1.  **登录 Grafana:**
    *   访问 `http://192.168.x.x:3000`。
    *   账号: `admin`，密码: `admin` (或者你刚才在 yml 里配的)。
    *   第一次登录会让你改密码，可以 Skip。

2.  **添加数据源 (Data Source):**
    *   在左侧菜单栏（汉堡图标）找到 **Connections** -> **Data Sources**。
    *   点击 **Add data source**。
    *   选择 **Prometheus**。
    *   在 **Prometheus server URL** 一栏填入：
        `http://prometheus:9090`
        *(注意：这里填容器名 `prometheus`，不要填 IP，因为它们在同一个 Docker 网络里)*
    *   拉到最下面，点击 **Save & test**。
    *   如果显示绿色的 `Successfully queried the Prometheus API`，就成功了。

3.  **导入现成的仪表盘 (Dashboard):**
    *   不要自己画图，我们要用全世界大神做好的模板。
    *   点击左侧菜单 **Dashboards**。
    *   点击右上角 **New** -> **Import**。
    *   在 **"Import via grafana.com"** 的框里输入 ID：**1860**。
        *(1860 是最经典的 Node Exporter Full 模板)*
    *   点击 **Load**。
    *   在最下面的 **Select a Prometheus data source** 下拉框里，选择刚才添加的 `Prometheus`。
    *   点击 **Import**。

---

### 第五步：全链路压测复盘

现在，你的屏幕上应该出现了一个密密麻麻、极其专业的仪表盘。

**让我们把昨天的“数据库 I/O 压测”重演一遍，看看图表会怎么变：**

1.  **准备环境：**
    *   确保 MySQL 容器也启动着（和监控系统并存）。
    *   确保 JMeter 在 A 机准备好（用那个 `SELECT COUNT(*)` 全表扫描脚本）。

2.  **开始压测！**
    *   运行 JMeter。
    *   **盯着 Grafana 的大屏看！**

**你应该关注这些图表（上帝视角）：**

1.  **CPU Usage:**
    *   你会看到 `System` (黄色) 和 `User` (绿色) 的曲线飙升。
    *   *以前你看的是 htop 的瞬间值，现在你能看到过去 5 分钟的**趋势**。*

2.  **Disk I/O (重点):**
    *   向下滚动，找到 **Disk** 面板。
    *   你会看到 **Disk R/W Data** 里的 **Read** 曲线瞬间拉起，变成一个高高的波峰（比如 150MB/s）。
    *   你会看到 **Disk IO Time** (就是 %util) 这一栏被填满。

3.  **Network Traffic:**
    *   如果是之前的 Nginx 压测，你会看到 **Inbound** 流量把带宽填满。

---

### 作业

请把这一套系统搭起来，跑一次压测，然后**截图 Grafana 的仪表盘给我看**。

一旦你拥有了这个界面，你就再也不需要手动敲命令了。
你可以指着屏幕对开发说：
**“你看，10:05 分的时候，磁盘读操作飙到了 200MB/s，导致 CPU 的 I/O Wait 升高，这就是接口超时的根本原因。”**

这就叫**专业**。