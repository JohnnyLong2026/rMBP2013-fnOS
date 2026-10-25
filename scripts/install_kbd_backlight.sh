sudo systemctl stop kbd-backlight-idle.service
sudo systemctl disable kbd-backlight-idle.service
sudo rm /etc/systemd/system/kbd-backlight-idle.service
sudo rm /usr/local/bin/kbd-backlight-idle.py
sudo rm /etc/kbd-backlight.conf
sudo systemctl daemon-reload







#!/bin/bash
# 一键安装键盘背光自动控制（空闲超时关闭/按键唤醒）
# 需要 root 权限运行

set -e

# 检查权限
if [ "$EUID" -ne 0 ]; then
    echo "请以 root 权限运行：sudo $0"
    exit 1
fi

echo "=== 安装依赖 ==="
apt update
apt install -y python3-evdev

echo "=== 创建 Python 脚本 ==="
cat > /usr/local/bin/kbd-backlight-idle.py << 'EOF'
#!/usr/bin/env python3
import os
import threading
import evdev
import glob

CONF_FILE = "/etc/kbd-backlight.conf"
KBD_PATH = "/sys/class/leds/smc::kbd_backlight/brightness"
SAVE_FILE = "/var/lib/mac-settings/kbd_last_brightness"

os.makedirs(os.path.dirname(SAVE_FILE), exist_ok=True)

def read_config():
    cfg = {"startup_brightness": 30, "idle_timeout": 180}
    try:
        with open(CONF_FILE) as f:
            for line in f:
                if "=" not in line:
                    continue
                k, v = line.strip().split("=", 1)
                if k == "startup_brightness":
                    cfg["startup_brightness"] = int(v)
                elif k == "idle_timeout":
                    cfg["idle_timeout"] = int(v)
    except:
        pass
    return cfg

def get_brightness():
    try:
        with open(KBD_PATH) as f:
            return int(f.read().strip())
    except:
        return -1

def set_brightness(value):
    try:
        with open(KBD_PATH, "w") as f:
            f.write(str(value))
    except Exception as e:
        print(f"设置背光失败: {e}")

def read_saved_brightness():
    try:
        with open(SAVE_FILE) as f:
            return int(f.read().strip())
    except:
        return -1

def save_brightness(value):
    try:
        with open(SAVE_FILE, "w") as f:
            f.write(str(value))
    except:
        pass

def find_keyboard_device():
    devs = glob.glob("/dev/input/by-id/*-event-kbd")
    if devs:
        apple = [d for d in devs if "apple" in d.lower()]
        return apple[0] if apple else devs[0]
    for ev in glob.glob("/dev/input/event*"):
        try:
            device = evdev.InputDevice(ev)
            if "keyboard" in device.name.lower() or "kbd" in device.name.lower():
                return ev
        except:
            continue
    return None

def main():
    dev_path = find_keyboard_device()
    if not dev_path:
        print("未找到键盘设备")
        return
    device = evdev.InputDevice(dev_path)
    print(f"监听设备: {device.name} ({dev_path})")

    timer = None
    def reset_timer():
        nonlocal timer
        if timer:
            timer.cancel()
        cfg = read_config()
        timer = threading.Timer(cfg["idle_timeout"], on_idle)
        timer.daemon = True
        timer.start()

    def on_idle():
        current = get_brightness()
        if current > 0:
            save_brightness(current)
            set_brightness(0)
            print("背光已关闭（空闲超时）")

    def restore_brightness():
        saved = read_saved_brightness()
        if saved > 0:
            set_brightness(saved)
            print(f"恢复亮度 {saved}")
        else:
            cfg = read_config()
            set_brightness(cfg["startup_brightness"])
            print(f"使用默认亮度 {cfg['startup_brightness']}")

    cfg = read_config()
    set_brightness(cfg["startup_brightness"])
    reset_timer()

    for event in device.read_loop():
        if event.type == evdev.ecodes.EV_KEY:
            key = evdev.categorize(event)
            if key.keystate == key.key_down:
                reset_timer()
                restore_brightness()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
EOF

chmod +x /usr/local/bin/kbd-backlight-idle.py

echo "=== 创建默认配置文件 ==="
cat > /etc/kbd-backlight.conf << 'EOF'
startup_brightness=30
idle_timeout=180
EOF

echo "=== 创建 systemd 服务 ==="
cat > /etc/systemd/system/kbd-backlight-idle.service << 'EOF'
[Unit]
Description=Keyboard Backlight Idle Control
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/kbd-backlight-idle.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "=== 重新加载 systemd 并启用服务 ==="
systemctl daemon-reload
systemctl enable kbd-backlight-idle.service
systemctl start kbd-backlight-idle.service

echo "=== 检查服务状态 ==="
systemctl status kbd-backlight-idle.service --no-pager

echo "=== 安装完成 ==="
echo "服务已启用并启动。你可以通过以下命令查看日志："
echo "  sudo journalctl -u kbd-backlight-idle.service -f"
echo "如需修改配置，请编辑 /etc/kbd-backlight.conf 并重启服务："
echo "  sudo systemctl restart kbd-backlight-idle.service"