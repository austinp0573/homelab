# motionEyeOS setup on a raspberry pi 5 with an `imx708_wide_noir`

## Get camera working

```bash
sudo apt update && sudo apt install -y rpicam-apps libcamera-v4l2 libcamera-tools
```

There are multiple ways to configure things so that the system will load the camera.

Using the whiptail makes sense because DietPi might otherwise overwrite changes.

`dietpi-config` -> `display`

`KMS/DRM` -> on

`RPi Codes` -> on

`Rpi Camera` -> on

`RPi Camera LED` -> on

```bash




                          ┌──────────────────────────────────────────────────┤ DietPi-Config ├───────────────────────────────────────────────────┐
                          │ Please select an option:                                                                                             │
                          │                                                                                                                      │
                          │                             0   : Display Resolution and Rotation                                                    │
                          │                             3   : LCD/OLED Panel addon: [none]                                                       │
                          │                             16  : Display Brightness                                                                 │
                          │                             17  : X.Org DPI: [96]                                                                    │
                          │                             14  : LED Control                                                                        │
                          │                             103 : KMS/DRM             : [On]                                                         │
                          │                             2   : GPU/RAM memory split                                                               │
                          │                             5   : LCD/OLED Rotation   : [0]                                                          │
                          │                             6   : Overscan            : [Off]                                                        │
                          │                             18  : RPi Codecs          : [On] V4L2 hardware video codecs                              │
                          │                             8   : RPi Camera          : [On]                                                         │
                          │                             9   : RPi Camera LED      : [On]                                                         │
                          │                             11  : JustBoom IR remote  : [Off]                                                        │
                          │                             12  : VC1 Key             : [none]                                                       │
                          │                             13  : MPEG2 Key           : [none]                                                       │
                          │                                                                                                                      │
                          │                                                                                                                      │
                          │                                  <Select>                                  <Back>                                    │
                          │                                                                                                                      │
                          └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

```

`dietpi-config` -> `advanced`

`I2C state` -> on

`SPI state` -> on

```bash

                          ┌──────────────────────────────────────────────────┤ DietPi-Config ├───────────────────────────────────────────────────┐
                          │ Please select an option:                                                                                             │
                          │                                                                                                                      │
                          │                        Swap file                  : [Off | /var/swap]                                                │
                          │                        APT                        : Manage APT cache and list storage                                │
                          │                        Time sync mode             : [Boot + Daily]                                                   │
                          │                        RTC mode                   : [Emulated]                                                       │
                          │                        Update RPi EEPROM firmware : [Bootloader: 1779807685 | VL805: N/A]                            │
                          │                        Serial/UART                : Manage available devices                                         │
                          │                        Bluetooth                  : [On]                                                             │
                          │                        I2C state                  : [On]                                                             │
                          │                        I2C frequency              : [100 kHz]                                                        │
                          │                        SPI state                  : [On]                                                             │
                          │                        RPi kernel choice          : Select/deselect optional kernel packages                         │
                          │                                                                                                                      │
                          │                                                                                                                      │
                          │                                  <Select>                                  <Back>                                    │
                          │                                                                                                                      │
                          └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

**CHECK IF THE CAMERA WORKS**: `rpicam-hello --list-cameras`


## Install motioneye

`dietpi-software` -> `browse` -> `motioneye`

## Edit the service

`/etc/systemd/system/motioneye.service`

in order to enable the legacy format `motioneyeos` uses, need `ExecStart` to begin with `/usr/bin/libcamerify`

Otherwise this is just the stock `motioneye.service`

```bash
[Unit]
Description=motionEye Server
After=network.target local-fs.target remote-fs.target

[Service]
User=motion
RuntimeDirectory=motioneye
LogsDirectory=motioneye
StateDirectory=motioneye
ExecStart=/usr/bin/libcamerify /opt/motioneye/bin/meyectl startserver -c /etc/motioneye/motioneye.conf
Restart=on-abort

[Install]
WantedBy=multi-user.target
```