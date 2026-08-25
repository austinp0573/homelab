# sbc-02 

* raspberry pi zero 2w 
    * Waveshare Ethernet hat

get dietpi image (though it's available in the rpi_imager)

flash it

use env/dietpi.txt

install openssh-sftp-server

run minimal-debian, but **only** the ux and vim

```bash
sudo apt update
sudo apt install -y systemd-zram-generator
```

```bash
─────┬─────────────────────────────────
     │ File: zram-generator.conf
─────┼──────────────────────────────────
   1 │ # This file is part of the zram-generator project
   2 │ # https://github.com/systemd/zram-generator
   3 │
   4 │ # At the top level, a set!variable = program
   5 │ # directive executes /bin/sh -c program,
   6 │ # parses the output as an expression, and remembers it in variable,
   7 │ # usable in later set! and zram-size/zram-resident-limit.
   8 │
   9 │ [zram0]
  10 │ # This section describes the settings for /dev/zram0.
  11 │ #
  12 │ # The maximum amount of memory (in MiB). If the machine has more RAM
  13 │ # than this, zram device will not be created.
  14 │ #
  15 │ # "host-memory-limit = none" may be used to disable this limit. This
  16 │ # is also the default.
  17 │ # host-memory-limit = 9048
  18 │
  19 │ # The size of the zram device, as a function of MemTotal, both in MB.
  20 │ # For example, if the machine has 1 GiB, and zram-size=ram/4,
  21 │ # then the zram device will have 256 MiB.
  22 │ # Fractions in the range 0.1–0.5 are recommended.
  23 │ #
  24 │ # The default is "min(ram / 2, 4096)".
  25 │ zram-size = min(ram / 2)
  26 │
  27 │ # The maximum memory resident for this zram device, as a function of MemTotal,
  28 │ # both in MB.
  29 │ # For example, if the machine has 1 GiB, and zram-resident-limit=ram/8,
  30 │ # then this device will not consume more than 128 MiB.
  31 │ #
  32 │ # 0 means no limit; this is the default.
  33 │ # zram-resident-limit = maxhotplug * 3/4
  34 │
  35 │ # The compression algorithm to use for the zram device,
  36 │ # or leave unspecified to keep the kernel default.
  37 │ #
  38 │ # Subsequent algorithms are used for recompression.
  39 │ # Comma-separated parameters may be specified in parentheses.
  40 │ #
  41 │ # Parameters without a compression algorithm are set as
  42 │ # global recompression parameters.
  43 │ compression-algorithm = lz4
  44 │
  45 │ swap-priority = 100
  46 │ # The following options are deprecated, and override zram-size.
  47 │ # These values would be equivalent to the zram-size setting above.
  48 │ #zram-fraction = 0.10
  49 │ #max-zram-size = 2048
  50 │
─────┴───────────────────────────────────────────────────────────────────────────────
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service
sudo systemctl status systemd-zram-setup@zram0.service
swapon -s
zramctl --output-all
```

install bat

```bash
curl -LO https://github.com/sharkdp/bat/releases/download/v0.26.1/bat_0.26.1_arm64.deb

sudo dpkg -i bat_0.26.1_arm64.deb
```