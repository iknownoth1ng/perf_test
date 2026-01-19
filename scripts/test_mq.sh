docker exec -it tomcat-1 bash -c 'cat <<EOF > /usr/local/tomcat/webapps/ROOT/test_mq.jsp
<%@ page import="com.rabbitmq.client.*" %>
<%!
    // 【核心优化】静态变量，全局共享，只初始化一次
    static Connection connection = null;
    static String QUEUE_NAME = "order_queue";

    // 初始化连接的方法
    public synchronized void initMQ() {
        if (connection == null || !connection.isOpen()) {
            try {
                ConnectionFactory factory = new ConnectionFactory();
                factory.setHost("my-rabbitmq");
                factory.setUsername("admin");
                factory.setPassword("admin");
                connection = factory.newConnection();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
%>
<%
    // 确保连接已建立
    if (connection == null || !connection.isOpen()) {
        initMQ();
    }

    try {
        // 【核心优化】每次只创建 Channel (轻量级)，不创建 Connection (重量级)
        // 甚至 Channel 也可以复用，但为了线程安全，这里先复用 Connection
        Channel channel = connection.createChannel();

        channel.queueDeclare(QUEUE_NAME, false, false, false, null);
        String message = "Order_" + System.currentTimeMillis();
        channel.basicPublish("", QUEUE_NAME, null, message.getBytes());

        // 用完关闭 Channel，但保留 Connection
        channel.close();

        out.println("<h1>MQ Async Send OK!</h1>");
    } catch (Exception e) {
        out.println(e.getMessage());
    }
%>
EOF'

docker exec -it tomcat-2 bash -c 'cat <<EOF > /usr/local/tomcat/webapps/ROOT/test_mq.jsp
<%@ page import="com.rabbitmq.client.*" %>
<%!
    // 【核心优化】静态变量，全局共享，只初始化一次
    static Connection connection = null;
    static String QUEUE_NAME = "order_queue";

    // 初始化连接的方法
    public synchronized void initMQ() {
        if (connection == null || !connection.isOpen()) {
            try {
                ConnectionFactory factory = new ConnectionFactory();
                factory.setHost("my-rabbitmq");
                factory.setUsername("admin");
                factory.setPassword("admin");
                connection = factory.newConnection();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
%>
<%
    // 确保连接已建立
    if (connection == null || !connection.isOpen()) {
        initMQ();
    }

    try {
        // 【核心优化】每次只创建 Channel (轻量级)，不创建 Connection (重量级)
        // 甚至 Channel 也可以复用，但为了线程安全，这里先复用 Connection
        Channel channel = connection.createChannel();

        channel.queueDeclare(QUEUE_NAME, false, false, false, null);
        String message = "Order_" + System.currentTimeMillis();
        channel.basicPublish("", QUEUE_NAME, null, message.getBytes());

        // 用完关闭 Channel，但保留 Connection
        channel.close();

        out.println("<h1>MQ Async Send OK!</h1>");
    } catch (Exception e) {
        out.println(e.getMessage());
    }
%>
EOF'

