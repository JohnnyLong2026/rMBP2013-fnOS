cd /usr/local/bin/
sudo nano mtop
sudo chmod +x mtop




#!/bin/bash
# ==================================================
# 系统监控脚本 - 终端版（带进度条，优化排版）
# 功能：实时显示 CPU、内存、磁盘、网络、温度、风扇、进程列表
# 依赖：lm-sensors, sysstat, bc, procps
# 自动检测并安装缺失依赖（需 sudo 权限）
# ==================================================

# 颜色定义
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 临时文件路径（使用 /tmp 下的唯一文件名，避免冲突）
NET_PREV="/tmp/mtop_net_prev_$$"
NET_TIME="/tmp/mtop_net_time_$$"

# 检查并安装依赖
check_deps() {
    local missing=()
    for cmd in sensors iostat bc; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "缺少必要工具: ${missing[*]}"
        echo "尝试自动安装（需要 sudo 权限）..."
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y lm-sensors sysstat bc
        else
            echo "无法自动安装，请手动安装以下包：lm-sensors sysstat bc"
            exit 1
        fi
    fi
}

# 初始化网络速度记录
init_net() {
    # 确保临时文件可写（如果存在且不可写则删除）
    for f in "$NET_PREV" "$NET_TIME"; do
        if [ -f "$f" ] && [ ! -w "$f" ]; then
            rm -f "$f"
        fi
    done
    local rx tx
    read rx tx < <(awk '/eth0|ens|wlan|wl/ {if($1!="lo:"){print $2,$10; exit}}' /proc/net/dev)
    echo "$rx $tx" > "$NET_PREV"
    echo "$(date +%s)" > "$NET_TIME"
}

# 获取网络速度（KB/s）
get_net_speed() {
    local now_rx now_tx now_time prev_rx prev_tx prev_time rx_kb tx_kb
    read now_rx now_tx < <(awk '/eth0|ens|wlan|wl/ {if($1!="lo:"){print $2,$10; exit}}' /proc/net/dev)
    now_time=$(date +%s)
    if [ -f "$NET_PREV" ] && [ -f "$NET_TIME" ]; then
        read prev_rx prev_tx < "$NET_PREV"
        prev_time=$(cat "$NET_TIME")
        local delta_t=$((now_time - prev_time))
        if [ $delta_t -gt 0 ]; then
            rx_kb=$(((now_rx - prev_rx) / 1024 / delta_t))
            tx_kb=$(((now_tx - prev_tx) / 1024 / delta_t))
        fi
    fi
    echo "$rx_kb $tx_kb"
    echo "$now_rx $now_tx" > "$NET_PREV"
    echo "$now_time" > "$NET_TIME"
}

# 获取 CPU 占用率
get_cpu_usage() {
    local user nice system idle iowait
    read user nice system idle iowait < <(awk '/cpu / {print $2,$3,$4,$5,$6}' /proc/stat)
    local total=$((user + nice + system + idle + iowait))
    local idle_total=$((idle + iowait))
    echo "$total $idle_total"
}

# 绘制进度条（百分比，宽度）
draw_bar() {
    local percent=$1
    local width=${2:-30}
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    printf "["
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "] %3d%%" "$percent"
}

# 将兆字节转换为吉字节（保留一位小数）
mb_to_gb() {
    local mb=$1
    if [ -z "$mb" ]; then
        echo "0.0"
    else
        echo "scale=1; $mb / 1024" | bc
    fi
}

# 主循环
main() {
    check_deps
    echo "初始化传感器（请稍等）..."
    # 首次运行后建议手动执行 sudo sensors-detect --auto，然后注释下一行
    # sudo sensors-detect --auto &>/dev/null
    echo "监控已启动，按 Ctrl+C 退出"

    # 初始化网络记录
    init_net

    # 上次 CPU 数据
    prev_total=0
    prev_idle=0

    while true; do
        # 清屏并显示标题
        clear
        echo "============== 系统监控 =============="
        date
        echo "--------------------------------------"

        # 1. CPU 占用率
        read cur_total cur_idle < <(get_cpu_usage)
        if [ $prev_total -ne 0 ]; then
            diff_total=$((cur_total - prev_total))
            diff_idle=$((cur_idle - prev_idle))
            cpu_usage=$((100 * (diff_total - diff_idle) / diff_total))
        else
            cpu_usage=0
        fi
        prev_total=$cur_total
        prev_idle=$cur_idle
        echo -e "${GREEN}CPU 占用率:${NC} ${cpu_usage}%"
        draw_bar "$cpu_usage" 30
        echo

        # 2. CPU 温度 & 风扇转速
        temp=$(sensors | awk '/Package id 0/ {gsub(/[+°C]/,"",$4); print $4}')
        fan=$(sensors | awk '/Right Side/ {print $4}' | tr -d ' RPM')
        temp_int=${temp%.*}
        if [ -n "$temp_int" ] && [ "$temp_int" -gt 100 ]; then
            temp_percent=100
        else
            temp_percent=${temp_int:-0}
        fi
        echo -e "${GREEN}CPU 温度:${NC} ${temp:-N/A}°C"
        draw_bar "$temp_percent" 30
        echo

        fan_int=${fan:-0}
        if [ "$fan_int" -gt 6200 ]; then
            fan_percent=100
        else
            fan_percent=$((fan_int * 100 / 6200))
        fi
        echo -e "${GREEN}风扇转速:${NC} ${fan_int} RPM"
        draw_bar "$fan_percent" 30
        echo

        # 3. 内存占用（以 GB 为单位）
        if command -v free &>/dev/null; then
            mem_total_mb=$(LANG=C free -m | awk '/^Mem:/ {print $2}')
            mem_used_mb=$(LANG=C free -m | awk '/^Mem:/ {print $3}')
            mem_percent=$((mem_used_mb * 100 / mem_total_mb))
            mem_total_gb=$(mb_to_gb "$mem_total_mb")
            mem_used_gb=$(mb_to_gb "$mem_used_mb")
            mem_info="${mem_used_gb}G/${mem_total_gb}G"
        else
            mem_info="未安装 procps"
            mem_percent=0
        fi
        echo -e "${GREEN}内存占用:${NC} ${mem_info}"
        draw_bar "$mem_percent" 30
        echo
        echo "--------------------------------------"

        # 4. 磁盘用量（以 GB 为单位）
        disk_total_mb=$(df -BM / | awk 'NR==2 {print $2}' | tr -d 'M')
        disk_used_mb=$(df -BM / | awk 'NR==2 {print $3}' | tr -d 'M')
        if [ -n "$disk_total_mb" ] && [ "$disk_total_mb" -gt 0 ]; then
            disk_percent=$((disk_used_mb * 100 / disk_total_mb))
            disk_total_gb=$(mb_to_gb "$disk_total_mb")
            disk_used_gb=$(mb_to_gb "$disk_used_mb")
            disk_info="${disk_used_gb}G/${disk_total_gb}G ($disk_percent%)"
        else
            disk_info="无法获取"
            disk_percent=0
        fi
        echo -e "${GREEN}磁盘用量:${NC} ${disk_info}"
        draw_bar "$disk_percent" 30
        echo

        # 5. 磁盘 I/O
        if command -v iostat &>/dev/null; then
            io=$(iostat -d -k | awk 'NR==4 {print $3,$4}')
            read_kb=$(echo "$io" | awk '{print $1}')
            write_kb=$(echo "$io" | awk '{print $2}')
            echo -e "${GREEN}磁盘 I/O: ${NC}读 ${read_kb:-0} KB/s, 写 ${write_kb:-0} KB/s"
        else
            echo "磁盘 I/O: 未安装 sysstat"
        fi

        echo "--------------------------------------"

        # 6. 网络 IP
        wired_ip=$(ip -4 addr show dev ens9 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        wireless_ip=$(ip -4 addr show dev wlp3s0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        echo -e "${GREEN}有线 IP:${NC} ${wired_ip:-无}"
        echo -e "${GREEN}无线 IP:${NC} ${wireless_ip:-无}"

        # 7. 网络速度
        read rx_kb tx_kb < <(get_net_speed)
        echo -e "${GREEN}网络速度: ${NC}下载 ${rx_kb:-0} KB/s, 上传 ${tx_kb:-0} KB/s"

        # ========== 进程列表 ==========
        echo "======================================"        
        echo -e "${GREEN}进程列表 (按 CPU 占用排序):${NC}"
	echo "--------------------------------------"
 	# 表头
        printf "%-9s %-8s %-8s %-8s %-10s %-30s\n" "进程ID" "用户" "CPU%" "内存%" "时间" "进程"
        # 数据行（与表头宽度一致）
        ps -eo pid,user,%cpu,%mem,time,comm --sort=-%cpu --no-headers | head -10 | awk '{
            pid=$1; user=$2; cpu=$3; mem=$4; time=$5;
            comm=substr($0, index($0,$6));
           printf "%-7s %-7s %-7s %-7s %-8s %-30s\n", pid, user, cpu, mem, time, substr(comm,1,30)
        }'

        echo "======================================"
        sleep 3
    done
}

# 捕获退出信号，清理临时文件
trap 'rm -f "$NET_PREV" "$NET_TIME"; echo; exit' INT TERM

main