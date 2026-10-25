# rMBP2013-fnOS

MacBook Pro (Retina, Late 2013) 跑 fnOS 时的自用脚本备份。

## scripts/

| 文件 | 用途 |
| --- | --- |
| `install_fan_control.sh` | 风扇自动控制。基于 `sensors` 读取 CPU 温度（Package id 0），线性映射到 1300–6200 RPM 写入 `/sys/devices/platform/applesmc.768/fan*_output`，含降温延迟。安装为 systemd 服务 `fan-control.service`，配置在 `/etc/fan-control.conf`。文件开头另附一段卸载命令。 |
| `install_kbd_backlight.sh` | 键盘背光空闲自动熄灭 / 按键唤醒。通过 `python3-evdev` 监听键盘输入事件，超时（默认 180 秒）关闭背光并记住亮度，按键按下时恢复。安装为 systemd 服务 `kbd-backlight-idle.service`，配置在 `/etc/kbd-backlight.conf`。文件开头另附一段卸载命令。 |
| `mtop.sh` | 终端版系统监控（`mtop` 命令）。实时刷新 CPU 占用、CPU 温度、风扇转速、内存、磁盘用量、磁盘 I/O、IP 与网速，并按 CPU 排序列出 Top 10 进程，带进度条。依赖 `lm-sensors` / `sysstat` / `bc`，缺失会自动尝试 apt 安装；手动安装时放到 `/usr/local/bin/mtop` 并 `chmod +x`。 |

## docs/

| 文件 | 用途 |
| --- | --- |
| `xubuntu-install-notes.sh` | Xubuntu 装机速查笔记（命令流水）：开启 SSH、换清华镜像源、降级安装 6.8.0-107 内核并设为 GRUB 默认项、删除旧内核、补齐 Broadcom 无线网卡所需 `linux-modules-extra` 并加载 `wl` 驱动、屏蔽 `b43`/`bcma`/`ssb`。 |

## 使用

```bash
sudo bash scripts/install_fan_control.sh
sudo bash scripts/install_kbd_backlight.sh

# 系统监控（也可手动放到 /usr/local/bin/mtop）
sudo bash scripts/mtop.sh
```

查看日志：

```bash
sudo journalctl -u fan-control.service -f
sudo journalctl -u kbd-backlight-idle.service -f
```

> 安装脚本需以 root 运行，依赖 `applesmc` 内核模块（风扇）与 `/dev/input/event*`（键盘背光）。
> `mtop.sh` 里的网卡名写死为 `ens9`（有线）和 `wlp3s0`（无线），换机器需要改。
