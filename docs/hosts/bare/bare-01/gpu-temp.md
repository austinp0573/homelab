# AMD R9700 is running hot

1. new intake fans ordered

2. going to install **LACT (Linux GPU Control Application)** and get the onboard blower to run faster.
    - At 100 C the fan is only at **70%**.

The amdgpu driver locks writing access to clock speeds and fan voltages.

- Unlock it with `ppfeaturemask`

Edit `/etc/default/grub`

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amdgpu.ppfeaturemask=0xffffffff"
```

- `sudo update-grub`

- `reboot`

### Get and install **LACT**

```bash
wget https://github.com/ilya-zlobintsev/LACT/releases/download/v0.9.0/lact-headless-0.9.0-0.amd64.ubuntu-2404.deb

 sudo apt install clinfo vulkan-tools

 sudo dpkg -i lact-headless-0.9.0-0.amd64.ubuntu-2404.deb
 ```

 ### Enable and start the daemon

 ```bash
 sudo systemctl enable --now lactd
 ```

 ### Have a look at the situation

 ```bash
 lact cli info
 ```

 > The **GPU ID** is important.

 ### Edit the config

config location: `/etc/lact/config.yaml`

```bash
version: 5
daemon:
  log_level: info
  admin_group: sudo
  disable_clocks_cleanup: false
apply_settings_timer: 5
current_profile: null
auto_switch_profiles: false
gpus:
 1002:7551-1DA2:E499-0000:05:00.0:
   fan_control_enabled: true
   fan_control_settings:
     mode: curve
     temperature_key: junction
     interval_ms: 500
     curve:
       30: 0.2
       50: 0.4
       65: 0.5
       75: 0.8
       85: 0.9
```

> The fan curve is: `Temperature in C: Fan %`.
> Full documentation for the config: [LACT - github](https://github.com/ilya-zlobintsev/LACT/blob/master/docs/CONFIG.md)

### Apply the configuration

```bash
sudo systemctl restart lactd
```

## Result

# **❄**

The junction temperature appears to stabilize below `80 C` with the fan at `85%`.