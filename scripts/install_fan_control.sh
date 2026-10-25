# 停止并禁用服务
sudo systemctl stop fan-control.service
sudo systemctl disable fan-control.service

# 删除服务文件
sudo rm -f /etc/systemd/system/fan-control.service

# 删除脚本和配置文件
sudo rm -f /usr/local/bin/fan-control.py
sudo rm -f /etc/fan-control.conf

# 重新加载 systemd
sudo systemctl daemon-reload

# 可选：恢复风扇手动模式为默认（关闭手动模式）
if [ -f /sys/devices/platform/applesmc.768/fan1_manual ]; then
    echo 0 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual >/dev/null 2>&1
    echo "已恢复风扇自动控制模式"
fi

echo "风扇控制服务已卸载。"







#!/bin/bash
# 精简版：风扇自动控制（仅使用 sensors 读取温度）
[ "$EUID" -eq 0 ] || { echo "请以 root 运行：sudo $0"; exit 1; }

apt update && apt install -y lm-sensors python3-psutil
modprobe applesmc 2>/dev/null

cat > /usr/local/bin/fan-control.py << 'EOF'
#!/usr/bin/env python3
import os, time, glob, subprocess, re, sys

CONF_FILE = "/etc/fan-control.conf"
FAN_BASE = "/sys/devices/platform/applesmc.768"

def read_config():
    cfg = {"min_temp":50,"max_temp":85,"min_rpm":1300,"max_rpm":6200,"delay_seconds":10}
    try:
        with open(CONF_FILE) as f:
            for line in f:
                if "=" in line:
                    k,v = line.strip().split("=",1)
                    if k in cfg: cfg[k] = int(v)
    except: pass
    return cfg

def get_cpu_temp():
    # 仅使用 sensors 命令解析 Package id 0 温度
    try:
        out = subprocess.check_output(["sensors"], universal_newlines=True)
        for line in out.splitlines():
            if "Package id 0" in line:
                m = re.search(r'\+([\d\.]+)°C', line)
                if m: return float(m.group(1))
    except: pass
    return 50.0  # 默认值

def set_fan_rpm(rpm):
    for path in glob.glob(f"{FAN_BASE}/fan*_output"):
        try:
            with open(path,"w") as f: f.write(str(rpm))
            print(f"写入 {path} = {rpm}", flush=True)
        except Exception as e: print(f"写入失败 {path}: {e}", flush=True)

def enable_manual():
    mp = f"{FAN_BASE}/fan1_manual"
    if os.path.exists(mp):
        try:
            with open(mp,"w") as f: f.write("1")
            print("手动模式已启用", flush=True)
        except Exception as e: print(f"启用手动模式失败: {e}", flush=True)

def target_rpm(temp, cfg):
    if temp <= cfg["min_temp"]: return cfg["min_rpm"]
    if temp >= cfg["max_temp"]: return cfg["max_rpm"]
    r = (temp - cfg["min_temp"]) / (cfg["max_temp"] - cfg["min_temp"])
    return int(cfg["min_rpm"] + r * (cfg["max_rpm"] - cfg["min_rpm"]))

def main():
    enable_manual()
    cur = 0
    last_down = 0
    print("风扇控制启动", flush=True)
    while True:
        try:
            cfg = read_config()
            t = get_cpu_temp()
            target = target_rpm(t, cfg)
            now = time.time()
            if target > cur:
                if target != cur:
                    set_fan_rpm(target)
                    cur = target
                    print(f"{time.strftime('%H:%M:%S')} {t:.1f}℃ → 提速至 {target} RPM", flush=True)
                last_down = now
            elif target < cur:
                if now - last_down >= cfg["delay_seconds"]:
                    set_fan_rpm(target)
                    cur = target
                    print(f"{time.strftime('%H:%M:%S')} {t:.1f}℃ → 降速至 {target} RPM (延迟 {cfg['delay_seconds']}秒)", flush=True)
                    last_down = now
                else:
                    r = cfg["delay_seconds"] - (now - last_down)
                    print(f"{time.strftime('%H:%M:%S')} {t:.1f}℃ → 降速等待 {r:.1f} 秒", flush=True)
            time.sleep(5)
        except Exception as e:
            print(f"错误: {e}", flush=True)
            time.sleep(5)

if __name__ == "__main__":
    try: main()
    except KeyboardInterrupt: print("\n退出", flush=True)
EOF

chmod +x /usr/local/bin/fan-control.py

cat > /etc/fan-control.conf << EOF
min_temp=50
max_temp=85
min_rpm=1300
max_rpm=6200
delay_seconds=10
EOF

cat > /etc/systemd/system/fan-control.service << EOF
[Unit]
Description=Fan Control
After=multi-user.target
[Service]
Type=simple
ExecStart=/usr/local/bin/fan-control.py
Restart=always
User=root
StandardOutput=journal
StandardError=journal
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now fan-control.service
systemctl status fan-control.service --no-pager -l
echo "安装完成。日志: journalctl -u fan-control.service -f"