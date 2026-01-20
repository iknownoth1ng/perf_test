// 计算每个计算机节点的吞吐量（简化版）
int throughputValue = Math.floor((Integer.parseInt("${QPS}") * 60) / Integer.parseInt("${computer_count}")) as int
vars.put("Throughput", String.valueOf(throughputValue))