CALL insert_data_fast(100000);
-- 把表里的数据复制一遍，再插回去,执行9次
INSERT INTO orders (
    user_id,
    order_no,
    amount,
    status,
    create_time,
    note
  )
SELECT user_id,
  UUID(),
  -- 生成新的订单号
  amount,
  status,
  NOW(),
  note
FROM orders;
-- 强制让 Linux 忘掉所有缓存的文件，必须去读物理硬盘
-- docker run --rm -it --privileged --pid=host alpine /bin/sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"