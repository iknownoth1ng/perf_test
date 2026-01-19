docker exec -it tomcat-1 bash -c 'cat <<EOF > /usr/local/tomcat/webapps/ROOT/test_sync_db.jsp
<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%
    // 模拟用户下单 -> 直接写数据库 -> 等待数据库落盘 -> 返回
    long start = System.currentTimeMillis();

    String url = "jdbc:mysql://my-mysql:3306/perftest?useSSL=false&allowPublicKeyRetrieval=true";

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        // 每次请求都建立连接（这也是性能杀手之一，虽然有连接池会好点，但写入本身是慢的）
        Connection conn = DriverManager.getConnection(url, "root", "root");

        String sql = "INSERT INTO orders (user_id, order_no, amount, status, create_time, note) VALUES (?, ?, ?, 1, NOW(), ?)";
        PreparedStatement ps = conn.prepareStatement(sql);

        // 随机数据
        ps.setInt(1, new Random().nextInt(1000));
        ps.setString(2, UUID.randomUUID().toString());
        ps.setDouble(3, new Random().nextDouble() * 100);
        ps.setString(4, "Sync Write Test");

        // 执行写入 (这里会发生磁盘 I/O)
        ps.executeUpdate();

        ps.close();
        conn.close();

        long duration = System.currentTimeMillis() - start;
        out.println("<h1>Order Created in MySQL!</h1>");
        out.println("Time Cost: " + duration + " ms");

    } catch (Exception e) {
        out.println(e.getMessage());
        e.printStackTrace();
    }
%>
EOF'

docker exec -it tomcat-2 bash -c 'cat <<EOF > /usr/local/tomcat/webapps/ROOT/test_sync_db.jsp
<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%
    // 模拟用户下单 -> 直接写数据库 -> 等待数据库落盘 -> 返回
    long start = System.currentTimeMillis();

    String url = "jdbc:mysql://my-mysql:3306/perftest?useSSL=false&allowPublicKeyRetrieval=true";

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        // 每次请求都建立连接（这也是性能杀手之一，虽然有连接池会好点，但写入本身是慢的）
        Connection conn = DriverManager.getConnection(url, "root", "root");

        String sql = "INSERT INTO orders (user_id, order_no, amount, status, create_time, note) VALUES (?, ?, ?, 1, NOW(), ?)";
        PreparedStatement ps = conn.prepareStatement(sql);

        // 随机数据
        ps.setInt(1, new Random().nextInt(1000));
        ps.setString(2, UUID.randomUUID().toString());
        ps.setDouble(3, new Random().nextDouble() * 100);
        ps.setString(4, "Sync Write Test");

        // 执行写入 (这里会发生磁盘 I/O)
        ps.executeUpdate();

        ps.close();
        conn.close();

        long duration = System.currentTimeMillis() - start;
        out.println("<h1>Order Created in MySQL!</h1>");
        out.println("Time Cost: " + duration + " ms");

    } catch (Exception e) {
        out.println(e.getMessage());
        e.printStackTrace();
    }
%>
EOF'
