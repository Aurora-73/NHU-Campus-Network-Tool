#!/bin/sh
# 交替运行 dk.sh 和 dl.sh，直到 dl.sh 返回 0
# 失败后短等待 5s；每连续 6 次失败后当次等待 30s（发生时记录日志）
# 累计等待达到 3600s（60 分钟）触发重启
DIR=/root/netlogin
LOGFILE="$DIR/log.log"

DK="$DIR/dk.sh"
DX="$DIR/dx.sh"

SHORT_WAIT=5
LONG_WAIT=30
FAILS_BEFORE_LONG=6
REBOOT_AFTER_SECONDS=3600

# 初始化
mkdir -p "$DIR"

fail_count=0
total_wait=0
round=0

# 仅在发生长等待时写这段格式的日志
log_long_wait() {
    { 
      echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
      echo "长等待事件: 第 ${fail_count} 次失败，执行等待 ${LONG_WAIT}s"
      echo "累计等待: ${total_wait}s"
      echo ""
    } >> "$LOGFILE" 2>&1
}

# 程序结束时写最终结果
log_final() {
    RESULT_MSG="$1"
    { 
      echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
      echo "${RESULT_MSG}"
      echo "轮次: ${round} 失败次数: ${fail_count} 累计等待: ${total_wait}s"
      echo ""
    } >> "$LOGFILE" 2>&1
}

# 捕获中断，记录并退出
trap 'log_final "脚本被中断（SIGINT/SIGTERM）"; exit 1' INT TERM

# 主循环
while true; do
    round=$((round + 1))

    # 先运行 dk.sh（忽略返回值）
    if [ -f "$DK" ]; then
        sh "$DK" || true
    fi

    # 再运行 dx.sh（期待返回 0）
    if [ -f "$DX" ]; then
        sh "$DX"
        rc=$?
    else
        rc=1
    fi

    if [ "$rc" -eq 0 ]; then
        log_final "登录成功: $DX 返回 0"
        exit 0
    fi

    # dx.sh 失败处理
    fail_count=$((fail_count + 1))

    if [ $((fail_count % FAILS_BEFORE_LONG)) -eq 0 ]; then
        waitt=$LONG_WAIT
        total_wait=$((total_wait + waitt))
        # 记录长等待事件（只记录此类）
        log_long_wait
    else
        waitt=$SHORT_WAIT
        total_wait=$((total_wait + waitt))
    fi

    # 判断是否达到重启阈值
    if [ "$total_wait" -ge "$REBOOT_AFTER_SECONDS" ]; then
        log_final "连续失败累计 ${total_wait}s >= ${REBOOT_AFTER_SECONDS}s，触发重启系统"
        sync
        /sbin/reboot
        # 如果重启命令返回，退出脚本
        exit 0
    fi

    sleep "$waitt"
done
