#!/bin/sh

DL_SIGNAL="/root/netlogin/dl.signal"
DX_SIGNAL="/root/netlogin/dx.signal"
TC="/root/netlogin/dk.sh"
DL_SCRIPT="/root/netlogin/dl.sh"
DX_SCRIPT="/root/netlogin/dx.sh"

PRE_SLEEP=5        # 执行退出脚本后等待秒数
POLL_INTERVAL=2    # 轮询间隔（秒）
POLL_TIMEOUT=5     # 等待信号最大时长（秒）
LOOP_SLEEP=5       # 一轮失败后等待秒数

# 计数器（分别记录对 dl/dx 的尝试次数）
cnt_dl=0
cnt_dx=0

# 小函数：打印你想要的两行简洁日志
log_try() {
    cur="$1"    # 当前判断到的“当前登录方式”依据 (dl 或 dx)
    try="$2"    # 本轮实际尝试的脚本 (dl 或 dx)
    if [ "$try" = "dl" ]; then
        cnt_dl=$((cnt_dl+1))
        n=$cnt_dl
    else
        cnt_dx=$((cnt_dx+1))
        n=$cnt_dx
    fi

    echo "目前的登录方式是 $cur"
    echo "切换为 $try 的第 $n 次尝试..."
}

# 主循环
while :; do
    # 判断“当前的登录方式”：如果 dx.signal 存在，则当前记录为 dx（按你原设逻辑是存在 dx.signal 就去尝试 dl）
    if [ -f "$DX_SIGNAL" ]; then
        current="dx"
        chosen="dl"
        chosen_script="$DL_SCRIPT"
    else
        current="dl"
        chosen="dx"
        chosen_script="$DX_SCRIPT"
    fi

    # 简洁日志
    log_try "$current" "$chosen"

    # 清理老信号，避免误判
    [ -f "$DL_SIGNAL" ] && rm -f "$DL_SIGNAL" 2>/dev/null
    [ -f "$DX_SIGNAL" ] && rm -f "$DX_SIGNAL" 2>/dev/null

    # 先调用退出脚本（如果存在）
    if [ -x "$TC" ]; then
        sh "$TC"
    fi

    sleep "$PRE_SLEEP"

    # 同步执行选中的登录脚本（等待其返回）
    if [ -x "$chosen_script" ]; then
        sh "$chosen_script"
    else
        echo "错误：$chosen_script 不存在或不可执行"
    fi

    # 轮询等待信号文件出现
    waited=0
    success=0
    while [ "$waited" -lt "$POLL_TIMEOUT" ]; do
        if [ -f "$DL_SIGNAL" ] || [ -f "$DX_SIGNAL" ]; then
            success=1
            break
        fi
        sleep "$POLL_INTERVAL"
        waited=$((waited + POLL_INTERVAL))
    done

    if [ "$success" -eq 1 ]; then
        # 发现任一信号认为成功
        if [ -f "$DL_SIGNAL" ]; then
            echo "检测到 dl.signal，登录（dl）成功"
        else
            echo "检测到 dx.signal，登录（dx）成功"
        fi
        exit 0
    else
        echo "尝试超时（${POLL_TIMEOUT}s），未检测到信号文件，切换并重试..."
        # 清理并等待下一轮
        [ -f "$DL_SIGNAL" ] && rm -f "$DL_SIGNAL" 2>/dev/null
        [ -f "$DX_SIGNAL" ] && rm -f "$DX_SIGNAL" 2>/dev/null
        sleep "$LOOP_SLEEP"
    fi
done
