# how to change the boot order on a raspberry pi

If the system is running Raspberry Pi OS, `raspi-config` will be present, if not:

```bash
sudo apt update && sudo apt install raspi-config -y
```

enter the config whiptail

```bash
sudo raspi-config
```

**Advanced Options** -> **Boot Order**