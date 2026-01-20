# Kubernetes (K8s) 实战速查与 HPA 自动扩缩容指南

> **适用环境：** Docker Desktop for Windows (WSL2)
> **目标：** 掌握 K8s 常用命令、k9s 可视化管理及 HPA 自动扩缩容配置。

---

## 1. Kubectl 常用命令速查 (Cheat Sheet)

`kubectl` 是 K8s 的官方命令行工具，哪怕有 UI 工具，掌握这些命令也是必须的。

### 基础管理

```powershell
# 查看集群节点状态 (排查 K8s 是否启动成功)
kubectl get nodes

# 根据 YAML 文件部署应用 (创建/更新资源)
kubectl apply -f filename.yaml

# 删除 YAML 文件定义的资源
kubectl delete -f filename.yaml

# 强制重启 Deployment (通过滚动更新方式)
kubectl rollout restart deployment <deployment-name>
```

### 查看资源状态

```powershell
# 查看所有 Pod (容器)
kubectl get pods

# 查看所有 Service (网络入口)
kubectl get svc

# 查看所有 Deployment (部署控制器)
kubectl get deploy

# 查看 HPA (自动扩缩容状态)
kubectl get hpa

# 查看资源的详细信息 (排错神器，比如看为什么 Pod 启动失败)
kubectl describe pod <pod-name>
```

### 调试与交互

```powershell
# 查看 Pod 日志
kubectl logs <pod-name>
# 实时滚动查看日志
kubectl logs -f <pod-name>

# 进入 Pod 内部命令行 (类似 docker exec)
kubectl exec -it <pod-name> -- /bin/sh
# 如果镜像里没有 sh，尝试用 bash
kubectl exec -it <pod-name> -- /bin/bash

# 端口转发 (打洞)：把 K8s 内部端口映射到 localhost
# 格式: kubectl port-forward svc/<服务名> <本机端口>:<容器端口>
kubectl port-forward svc/mysql-svc 3306:3306
```

### 数据清理 (重置数据库用)

```powershell
# 查看所有持久化卷声明
kubectl get pvc

# 删除 PVC (相当于格式化硬盘，下次启动数据会丢失)
kubectl delete pvc <pvc-name>
```

---

## 2. K9s：终端可视化管理神器

k9s 是一个基于终端的 UI 工具，极大提高了 K8s 的管理效率。

### 安装与启动

- **下载：** [GitHub Releases](https://github.com/derailed/k9s/releases)
- **启动：** 在 PowerShell 输入 `k9s`

### 核心快捷键

| 按键            | 功能             | 说明                                               |
| :-------------- | :--------------- | :------------------------------------------------- |
| **`:` (冒号)**  | **命令模式**     | 输入资源类型进行跳转，如 `:pod`, `:svc`, `:deploy` |
| **`/` (斜杠)**  | **搜索/过滤**    | 输入关键字过滤列表 (如 `/mysql`)                   |
| **`l`**         | **Logs**         | 查看选中 Pod 的日志 (按 `Esc` 返回)                |
| **`s`**         | **Shell**        | 进入选中 Pod 的终端 (等于 kubectl exec)            |
| **`d`**         | **Describe**     | 查看资源的详细描述 (排错用)                        |
| **`shift + f`** | **Port Forward** | 快速建立端口转发                                   |
| **`ctrl + d`**  | **Delete**       | 删除选中的资源 (相当于重启 Pod)                    |
| **`0` (数字)**  | **Show All**     | 显示所有命名空间的资源 (默认只看 default)          |
| **`?`**         | **Help**         | 查看所有快捷键帮助                                 |

---

## 3. HPA (Horizontal Pod Autoscaler) 自动扩缩容实战

HPA 是 K8s 根据 CPU/内存利用率自动增减 Pod 数量的机制。

### 第一步：安装 Metrics Server (监控探头)

Docker Desktop 默认不带监控组件，必须手动安装并修补证书问题。

1.  **下载并安装：**

    ```powershell
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    ```

2.  **修正证书错误 (Patch)：**
    - 编辑 Deployment：`kubectl edit deployment metrics-server -n kube-system`
    - 在 `spec.containers.args` 下添加参数：`- --kubelet-insecure-tls`

3.  **验证安装：**
    ```powershell
    kubectl top nodes
    # 如果能显示 CPU/Memory 数值，说明安装成功
    ```

### 第二步：配置应用资源限额 (Resources)

**必须**在应用的 Deployment YAML 中声明 CPU 请求量 (`requests`)，否则 HPA 无法计算百分比。

```yaml
spec:
    containers:
        - name: java-app
          image: my-java-app:v1
          imagePullPolicy: Never # 关键：使用本地镜像
          # 👇 HPA 必须配置这里 👇
          resources:
              requests:
                  cpu: "100m" # 申请 0.1 核 (基准值)
              limits:
                  cpu: "500m" # 上限 0.5 核
```

### 第三步：创建 HPA 规则

创建一个 `hpa.yaml` 文件：

```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
    name: java-app-hpa
spec:
    scaleTargetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: java-app-deploy # 目标 Deployment 的名字
    minReplicas: 2 # 最小保留 2 个实例
    maxReplicas: 10 # 最大扩容到 10 个
    targetCPUUtilizationPercentage: 50 # CPU 超过 50% (相对于 request) 就扩容
```

应用规则：

```powershell
kubectl apply -f hpa.yaml
```

### 第四步：验证扩缩容

1.  **压测前：** 打开 k9s，查看 Pod 数量 (应为 2 个)。
2.  **压测中：** 使用 JMeter 发起高并发请求。
    - 观察 `kubectl get hpa`，`TARGETS` 数值会升高 (如 `120%/50%`)。
    - 观察 k9s，Pod 状态会变成 `ContainerCreating` -> `Running`。数量逐渐增加到 10 个。
3.  **压测后：** 停止 JMeter。
    - CPU 负载降为 0%。
    - **等待 5 分钟** (K8s 默认冷却时间 `stabilization window`)。
    - 观察 Pod 数量会自动缩减回 2 个。

---

## 4. 常见坑点备忘

1.  **镜像拉取失败 (ErrImagePull / ImagePullBackOff):**
    - **原因:** K8s 默认去 Docker Hub 找镜像。
    - **解决:** 在 Deployment YAML 中设置 `imagePullPolicy: Never`，强制使用本地构建的镜像。

2.  **数据库连接失败:**
    - **原因:** K8s 内不能用 `localhost` 或 IP 互连。
    - **解决:** 使用 Service Name (如 `mysql-svc`) 作为 Host。

3.  **数据库表不存在:**
    - **原因:** 重新部署后 PVC (硬盘) 里可能有旧数据，导致初始化脚本不执行。
    - **解决:** `kubectl delete pvc mysql-pvc` 彻底清除数据。

4.  **HPA 不扩容:**
    - **原因:** 没装 Metrics Server 或没配置 `resources.requests.cpu`。
    - **检查:** 运行 `kubectl get hpa`，如果 TARGETS 显示 `<unknown>/50%`，说明监控数据没取到。
