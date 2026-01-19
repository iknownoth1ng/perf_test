# 解释一下命令：
# -n: 非GUI模式 (No GUI)
# -t: 指定脚本文件
# -l: 指定保存结果的日志文件 (.jtl)
# -j: 指定JMeter运行日志文件位置
# -e: 测试结束后生成报告
# -o: 指定报告输出的文件夹 (这个文件夹必须为空或不存在)

# jmeter -n -t '.\Test Plan.jmx' -l result.jtl -e -o ./report_folder
jmeter -n -t '.\Test Plan.jmx' -l ./report_folder/result.jtl  -e -o ./report_folder 