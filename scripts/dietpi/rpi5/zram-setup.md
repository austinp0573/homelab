# dietpi - rpi5 zram setup

use `systemd-zram-generator`

[https://github.com/systemd/zram-generator](https://github.com/systemd/zram-generator)

```bash
sudo apt update && sudo apt install systemd-zram-generator -y
```

`/etc/systemd/zram-generator.conf`

```bash
[zram0]
zram-size = ram / 2
compression-algorithm = lz4
swap-priority = 100
```


`/etc/sysctl.d/99-zram.conf`

```bash
vm.swappiness=180
vm.watermark_boost_factor=0
vm.watermark_scale_factor=125
vm.page-cluster=0
```


reload and start it

```bash
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service
```

check it

```bash
swapon -s
```