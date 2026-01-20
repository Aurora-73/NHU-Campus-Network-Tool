#!/bin/sh   
# 加载配置信息
RAW_USER_ACCOUNT=""   # 用户账号，就是学号
USER_PASSWORD=""    # 用户密码
SERVERCHAN_KEY=""  # sever酱KEY，若不需要通知可留空

echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="

# 获取 eth1 的 IPv4 地址
IP=$(ifconfig eth1 2>/dev/null | awk '/inet addr/{print $2}' | cut -d: -f2)

# 如果 ifconfig 输出是 "inet 10.123..." 而不是 "inet addr:10.123..."
# IP=$(ifconfig eth1 2>/dev/null | awk '/inet /{print $2}')

echo "IP: $IP"

# 登录请求并保存结果
LOGIN_RESULT=$(curl -ks "https://10.2.68.30:802/eportal/portal/login?callback=dr1003&login_method=1&user_account=%2C0%2C${RAW_USER_ACCOUNT}&user_password=${USER_PASSWORD}&wlan_user_ip=$IP&wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=&jsVersion=4.2.1&terminal_type=1&lang=zh-cn&v=10166" \
  -H "User-Agent: Mozilla/5.0" \
  -H "Referer: https://10.2.68.30/")

# 原有输出（保持不变）
echo "$LOGIN_RESULT"

# 默认退出码：失败
EXIT_CODE=1

# 判断 result 是否为1
if echo "$LOGIN_RESULT" | grep -q '"result":1'; then
  # 产生切换信号文件
  rm -f /root/netlogin/dx.signal 2>/dev/null
  touch /root/netlogin/dl.signal

  TITLE=$(echo -n "内网登录成功" | jq -s -R -r @uri)
  DESP=$(echo -n "IP: $IP" | jq -s -R -r @uri)
  curl -s "https://sctapi.ftqq.com/${SERVERCHAN_KEY}.send?title=$TITLE&desp=$DESP" >/dev/null

  EXIT_CODE=0
fi

{
echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
echo "内网IP: $IP"
echo "$LOGIN_RESULT"
echo ""
} >> /root/netlogin/log.log 2>&1

exit $EXIT_CODE
