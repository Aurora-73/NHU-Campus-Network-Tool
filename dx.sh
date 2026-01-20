#!/bin/sh
# 加载配置信息
RAW_USER_ACCOUNT=""   # 用户账号，就是学号
USER_PASSWORD=""    # 用户密码
SERVERCHAN_KEY=""  # sever酱KEY，若不需要通知可留空

echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="

# 获取 eth1 的 IPv4 地址（优先使用 ip 命令，回退到 ifconfig）
IP=$(ip -4 addr show dev eth1 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
if [ -z "$IP" ]; then
  IP=$(ifconfig eth1 2>/dev/null | awk '/inet addr/{print $2}' | cut -d: -f2)
fi

# 仍然为空的话尝试从任何活动接口抓一个 IPv4（谨慎）
if [ -z "$IP" ]; then
  IP=$(ip -4 addr show scope global 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)
fi

echo "IP: $IP"

# URL encode account/password (需要 jq 可用)
if command -v jq >/dev/null 2>&1; then
  USER_ACCOUNT_ENC=$(printf '%s' "$RAW_USER_ACCOUNT" | jq -s -R -r @uri)
  PASSWORD_ENC=$(printf '%s' "$USER_PASSWORD" | jq -s -R -r @uri)
else
  # 没有 jq 的简单替代（对常见字符进行基本编码，若包含复杂字符请安装 jq）
  USER_ACCOUNT_ENC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$RAW_USER_ACCOUNT" 2>/dev/null || echo "$RAW_USER_ACCOUNT")
  PASSWORD_ENC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$USER_PASSWORD" 2>/dev/null || echo "$USER_PASSWORD")
fi

# 构造请求 URL（基于你提供的电信示例）
# 注意：v 参数使用样例中的 8141；如需更改可在上方修改
URL="https://web.hnu.edu.cn:802/eportal/portal/login?callback=dr1003&login_method=1&user_account=,0,${USER_ACCOUNT_ENC}@telecom&user_password=${PASSWORD_ENC}&wlan_user_ip=${IP}&wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=&jsVersion=4.2.1&terminal_type=1&lang=zh-cn&v=8141&lang=zh"

# 发起请求
LOGIN_RESULT=$(curl -ks "$URL" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0" \
  -H "Referer: https://web.hnu.edu.cn/")

# 输出原始返回便于调试
echo "$LOGIN_RESULT"

# 默认退出码：失败
EXIT_CODE=1

# 检查是否登录成功（返回包含 "result":1 表示成功）
echo "$LOGIN_RESULT" | grep -q '"result":1'
if [ $? -eq 0 ]; then
  if [ -n "$SERVERCHAN_KEY" ]; then
    # 产生切换信号文件
    rm /root/netlogin/dl.signal 2>/dev/null
    touch /root/netlogin/dx.signal
    TITLE=$(echo -n "电信登录成功" | jq -s -R -r @uri)
    DESP=$(echo -n "IP: $IP" | jq -s -R -r @uri)
    curl -s "https://sctapi.ftqq.com/${SERVERCHAN_KEY}.send?title=${TITLE}&desp=${DESP}" >/dev/null
    
    EXIT_CODE=0
  fi
fi

# 追加日志
{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
  echo "电信IP: $IP"
  echo "$LOGIN_RESULT"
  echo ""
} >> /root/netlogin/log.log 2>&1

exit $EXIT_CODE