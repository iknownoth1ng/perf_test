# 基础镜像：使用轻量级 JDK
FROM eclipse-temurin:17-jre-alpine

# 设置工作目录
WORKDIR /app

# 拷贝 jar 包
COPY app.jar app.jar

# 暴露端口
EXPOSE 8001

# 启动命令 (注意：这里预留了 agent 的位置，稍后在 compose 里覆盖)
CMD ["java", "-jar", "app.jar"]