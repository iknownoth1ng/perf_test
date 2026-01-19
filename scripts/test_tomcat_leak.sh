docker exec -it my-tomcat bash -c 'cat <<EOF > /usr/local/tomcat/webapps/ROOT/test_redis_leak.jsp
<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page import="redis.clients.jedis.*" %>

<%!
    // 【毒药核心】定义一个静态列表
    // static 变量生命周期与 Class 一样长，GC 无法回收它
    // 只要 Tomcat 不重启，这个列表就会无限膨胀
    static List<byte[]> LEAK_CONTAINER = new ArrayList<>();
%>

<%
    // --- 1. 制造内存泄漏 (每次请求吃掉 1MB 内存) ---
    try {
        // 分配 1MB 的字节数组
        byte[] garbage = new byte[1024 * 1024];
        LEAK_CONTAINER.add(garbage);

        // 打印当前泄漏总大小
        out.println("<h3>☠️ Current Leak Size: " + LEAK_CONTAINER.size() + " MB (Heap is dying...)</h3>");
    } catch (OutOfMemoryError e) {
        out.println("<h1 style=\"color:red\">🔥 System Crashed: Java Heap Space OOM!</h1>");
        // 打印堆栈以便 SkyWalking 捕捉
        e.printStackTrace();
        throw e;
    }

    // --- 2. 正常的业务逻辑 (Redis + MySQL) ---
    Jedis jedis = null;
    try {
        jedis = new Jedis("my-redis", 6379);
        String cacheKey = "order_count";
        String result = jedis.get(cacheKey);

        if (result != null) {
            out.println("<p style=\"color:green\">Cache Hit! (From Redis)</p>");
            out.println("<p>Count: " + result + "</p>");
        } else {
            out.println("<p style=\"color:orange\">Cache Miss! (From MySQL)</p>");

            // 模拟业务耗时
            Thread.sleep(50);

            Class.forName("com.mysql.cj.jdbc.Driver");

            // 【防冲突写法】显式指定 java.sql.Connection
            java.sql.Connection conn = DriverManager.getConnection(
                "jdbc:mysql://my-mysql:3306/perftest?useSSL=false&allowPublicKeyRetrieval=true",
                "root",
                "root"
            );

            java.sql.Statement stmt = conn.createStatement();
            java.sql.ResultSet rs = stmt.executeQuery("SELECT count(*) FROM orders");

            if(rs.next()) {
                result = rs.getString(1);
                // 写入缓存
                jedis.setex(cacheKey, 60, result);
                out.println("<p>Count: " + result + "</p>");
            }

            // 关闭数据库资源
            rs.close();
            stmt.close();
            conn.close();
        }
    } catch (Exception e) {
        out.println("<p>Error: " + e.getMessage() + "</p>");
        e.printStackTrace();
    } finally {
        if (jedis != null) jedis.close();
    }
%>
EOF'