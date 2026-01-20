#!/bin/sh
# 加载配置信息
RAW_USER_ACCOUNT=""    # 用户账号，就是学号
SERVERCHAN_KEY=""  # sever酱KEY，若不需要通知可留空

echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="

# 获取 eth1 的 IPv4 地址
IP=$(ifconfig eth1 2>/dev/null | awk '/inet addr/{print $2}' | cut -d: -f2)
[ -z "$IP" ] && IP=$(ifconfig eth1 2>/dev/null | awk '/inet /{print $2}')

echo "IP: $IP"

# 转换 IP -> 整数
IP_INT=$(echo "$IP" | awk -F. '{print ($1*16777216)+($2*65536)+($3*256)+$4}')

# 构建登出 URL
URL="https://web.hnu.edu.cn:802/eportal/portal/mac/unbind?callback=dr1003&user_account=${RAW_USER_ACCOUNT}&wlan_user_mac=000000000000&wlan_user_ip=${IP_INT}&jsVersion=4.2.1&v=4832&lang=zh"

# 重试配置
MAX_RETRIES=5
RETRY_COUNT=0
SUCCESS=0

# 重试循环
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "尝试登出 (第 $((RETRY_COUNT+1)) 次)..."
    
    # 发送登出请求
    LOGOUT_RESULT=$(curl -ks "$URL")
    echo "$LOGOUT_RESULT"
    
    # 检查是否成功 (包含 "result":1)
    if echo "$LOGOUT_RESULT" | grep -q '"result":1' || echo "$LOGOUT_RESULT" | grep -q '获取用户在线信息数据为空'; then
        echo "登出成功！"
        SUCCESS=1
        break
    else
        echo "登出失败，准备重试..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        # 如果不是最后一次尝试，等待2秒后重试
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            sleep 2
        fi
    fi
done

# 如果所有尝试都失败，发送通知
if [ $SUCCESS -eq 0 ]; then
    echo "登出失败，已达到最大重试次数 $MAX_RETRIES"
    
    # 提取错误信息
    ERROR_MSG=$(echo "$LOGOUT_RESULT" | grep -o '"msg":"[^"]*"' | cut -d'"' -f4)
    
    TITLE=$(echo -n "校园网登出失败" | jq -s -R -r @uri)
    DESP=$(echo -n "IP: $IP\n错误信息: $ERROR_MSG\n重试次数: $MAX_RETRIES\n时间: $(date '+%Y-%m-%d %H:%M:%S')" | jq -s -R -r @uri)
    
    # 发送Server酱通知
    curl -s "https://sctapi.ftqq.com/${SERVERCHAN_KEY}.send?title=$TITLE&desp=$DESP" >/dev/null
    echo "已发送失败通知"
    exit 1
else
    {
    echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
    echo "登出成功"
    echo ""
    } >> /root/netlogin/log.log 2>&1
    rm /root/netlogin/*.signal 2>/dev/null
    exit 0
fi

