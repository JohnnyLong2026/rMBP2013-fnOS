# rMBP2013-fnOS

MacBook Pro (Retina, Late 2013) 跑 fnOS 时的自用脚本备份。

## scripts/

| 文件 | 用途 |
| --- | --- |
| `install_fan_control.sh` | 风扇自动控制。基于 `sensors` 读取 CPU 温度（Package id 0），线性映射到 1300–6200 RPM 写入 `/sys/devices/platform/applesmc.768/fan*_output`，含降温延迟。安装为 systemd 服务 `fan-control.service`，配置在 `/etc/fan-control.conf`。文件开头另附一段卸载命令。 |
| `install_kbd_backlight.sh` | 键盘背光空闲自动熄灭 / 按键唤醒。通过 `python3-evdev` 监听键盘输入事件，超时（默认 180 秒）关闭背光并记住亮度，按键按下时恢复。安装为 systemd 服务 `kbd-backlight-idle.service`，配置在 `/etc/kbd-backlight.conf`。文件开头另附一段卸载命令。 |

## 使用

```bash
sudo bash scripts/install_fan_control.sh
sudo bash scripts/install_kbd_backlight.sh
```

查看日志：

```bash
sudo journalctl -u fan-control.service -f
sudo journalctl -u kbd-backlight-idle.service -f
```

> 脚本需以 root 运行，依赖 `applesmc` 内核模块（风扇）与 `/dev/input/event*`（键盘背光）。
