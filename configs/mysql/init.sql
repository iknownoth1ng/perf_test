CREATE USER 'exporter' @'%' IDENTIFIED BY 'password';
GRANT PROCESS,
    REPLICATION CLIENT,
    SELECT ON *.* TO 'exporter' @'%';
FLUSH PRIVILEGES;

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  order_no VARCHAR(50) NOT NULL,
  amount DECIMAL(10, 2),
  status TINYINT,
  create_time DATETIME,
  # 加一个长文本字段，专门用来消耗磁盘 I/O
  note VARCHAR(500),
  KEY idx_user (user_id)
) ENGINE = InnoDB;

DELIMITER $$
DROP PROCEDURE IF EXISTS insert_data_fast $$
CREATE PROCEDURE insert_data_fast(IN total INT)
BEGIN
    DECLARE i INT DEFAULT 0;

    -- 【优化关键 1】关闭自动提交，显式开启事务
    -- 这样不会每插一条就写一次硬盘，而是攒在内存里
    SET autocommit = 0;

    WHILE i < total DO
        -- 完整的插入语句
        INSERT INTO orders (
            user_id,
            order_no,
            amount,
            status,
            create_time,
            note
        )
        VALUES (
            FLOOR(1 + RAND() * 1000),      -- 模拟 user_id (1-1000随机)
            UUID(),                       -- 模拟 订单号
            ROUND(RAND() * 1000, 2),      -- 模拟 金额
            1,                            -- 状态
            NOW(),                        -- 时间
            REPEAT('Performance Testing is fun! ', 10) -- 填充长文本 (约280字符)，占用磁盘空间
        );

        SET i = i + 1;

        -- 【优化关键 2】每 2000 条提交一次
        -- 既能利用批量写入的高效，又防止 undo log 撑爆内存
        IF MOD(i, 2000) = 0 THEN
            COMMIT;
        END IF;
    END WHILE;

    -- 【优化关键 3】把剩下的零头提交掉
    COMMIT;

    -- 恢复默认设置
    SET autocommit = 1;
END $$
DELIMITER ;