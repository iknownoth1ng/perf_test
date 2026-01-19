# 给 tomcat-1 写入脚本
docker exec -it tomcat-1 bash -c 'mkdir -p /usr/local/tomcat/webapps/ROOT && echo "<h1>我是节点 1</h1>" > /usr/local/tomcat/webapps/ROOT/whoami.html'

# 给 tomcat-2 写入脚本
docker exec -it tomcat-2 bash -c 'mkdir -p /usr/local/tomcat/webapps/ROOT && echo "<h1>我是节点 2</h1>" > /usr/local/tomcat/webapps/ROOT/whoami.html'


# 覆盖 tomcat-1 的首页
docker exec -it tomcat-1 bash -c 'echo "<h1>I am Node 1</h1>" > /usr/local/tomcat/webapps/ROOT/whoami.html'

# 覆盖 tomcat-2 的首页
docker exec -it tomcat-2 bash -c 'echo "<h1>I am Node 2</h1>" > /usr/local/tomcat/webapps/ROOT/whoami.html'


# 写入完整的 HTML 结构，带上 meta charset
# 写入完整的 HTML 结构，带上 meta charset
docker exec -it tomcat-1 bash -c 'echo "<html><head><meta charset=\"UTF-8\"></head><body><h1>我是节点 1</h1></body></html>" > /usr/local/tomcat/webapps/ROOT/whoami.html'

docker exec -it tomcat-2 bash -c 'echo "<html><head><meta charset=\"UTF-8\"></head><body><h1>我是节点 2</h1></body></html>" > /usr/local/tomcat/webapps/ROOT/whoami.html'