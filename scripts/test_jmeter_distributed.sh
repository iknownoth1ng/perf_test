jmeter -n \
  -t /jmeter/scripts/压测app.jmx \
  -R 172.18.0.14,172.18.0.15,172.18.0.16 \
  -l /jmeter/results/result.jtl \
  -e -o /jmeter/results/report \
  -Dserver.rmi.ssl.disable=true


apt-get update && apt-get install -y docker.io