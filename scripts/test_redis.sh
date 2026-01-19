docker exec -it tomcat-1 bash -c 'cat <<EOF > /usr/local/tomcat/webapps/ROOT/test_redis.jsp
<%@ page import="java.sql.*" %>
<%@ page import="redis.clients.jedis.*" %>

<%
    Jedis jedis = null;
    String cacheKey = "order_count_cache";
    String result = null;
    long start = System.currentTimeMillis();
    out.println("<h2>I am Node1</h2>");

    try {
        // 1. 连接 Redis
        jedis = new Jedis("my-redis", 6379);

        // 2. 尝试从缓存获取
        result = jedis.get(cacheKey);

        if (result != null) {
            // --- 命中缓存 (Hit) ---
            out.println("<h1>🚀 Cache HIT! (From Redis)</h1>");
            out.println("<h3>Value: " + result + "</h3>");
        } else {
            // --- 未命中，回源数据库 (Miss) ---
            out.println("<h1>🐢 Cache MISS! (Loading from MySQL...)</h1>");

            // 模拟业务耗时 (让回源看起来更慢一点)
            Thread.sleep(50);

            Class.forName("com.mysql.cj.jdbc.Driver");
            java.sql.Connection conn = DriverManager.getConnection(
                "jdbc:mysql://my-mysql:3306/perftest?useSSL=false&allowPublicKeyRetrieval=true",
                "root", "root");

            java.sql.Statement stmt = conn.createStatement();
            // 查一个大表聚合，消耗 DB 资源
            java.sql.ResultSet rs = stmt.executeQuery("SELECT count(*) FROM orders");

            if(rs.next()) {
                result = rs.getString(1);
                // 3. 写入 Redis (设置 60 秒过期，模拟缓存失效)
                jedis.setex(cacheKey, 60, result);
                out.println("<h3>Value: " + result + "</h3>");
            }

            conn.close();
        }
    } catch (Exception e) {
        out.println(e.getMessage());
        out.println(e.getStackTrace());
        e.printStackTrace();
    } finally {
        if (jedis != null) jedis.close();
    }

    long duration = System.currentTimeMillis() - start;
    out.println("<p>Total Time: " + duration + " ms</p>");
%>
EOF'