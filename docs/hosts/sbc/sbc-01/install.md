# sbc-01 install

To get an OS on the **eMMC** the easiest thing to do is start the system on a **microSD card** and then just `dd` whatever OS you want onto the **eMMC**.

## Flashing to the eMMC from a booted OS

- make sure the system you're on has:
    - `wget`
    - `xz-utils`


```sh
sudo apt update
sudo apt install xz-utils wget -y

# or just check and see if you have it, you probably do
# apt list -- installed | grep -e "wget" -e "xz-utils"
```

- go to [the dietpi website](https://dietpi.com) and get the image
    - (https://dietpi.com/downloads/images/DietPi_NanoPiZero2-ARMv8-Trixie.img.xz)


```bash
cd /var/tmp
wget https://dietpi.com/downloads/images/DietPi_NanoPiZero2-ARMv8-Trixie.img.xz
```

- **Note:** Do not use /tmp on DietPi. By default, DietPi mounts /tmp as tmpfs (RAM disk). Downloading or extracting large files within a RAM disk will deplete your system memory, instantly freezing or crashing the device. Using /var/tmp forces persistent on-disk storage execution.

The **microSd card** will appear in lsblk as an  `mmcblk` device. The **eMMC** will as well. 

```bash
NAME         MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
mmcblk0      179:0    0 59.5G  0 disk
└─mmcblk0p1  179:1    0 59.5G  0 part /
mmcblk2      179:32   0 58.2G  0 disk
mmcblk2boot0 179:64   0    4M  1 disk
mmcblk2boot1 179:96   0    4M  1 disk
```

Obviously this is a little confusing initially because I have `64GB` **microSD card** and `64GB` of **eMMC**.

- decompress the image to stdout and pipe that to `dd`

```bash
# still in the right dir
# user@sbc-01:/var/tmp$
# dd can be very destructive if you're not careful
# make sure the of= is pointed to the right place
xz -dc DietPi_NanoPiZero2-ARMv8-Trixie.img.xz | sudo dd of=/dev/mmcblk2 bs=4M status=progress conv=fsync
```

- have a look at the new partition

```bash
lsblk
```

- Mount the 2nd partition so you can alter/add dietpi.txt

```bash
sudo mkdir -p /mnt/target_eMMC
sudo mount /dev/mmcblk2p2 /mnt/target_eMMC
# sudo vim /mnt/target_eMMC/dietpi.txt
# or
# sudo cp ~/dietpi.txt /mnt/target_eMMC/
sudo umount /mnt/target_eMMC && sync
```

- turn it off and take out the **microSD card**

## System setup

- run the basic scripts

- run the dietpi setup utilities to ensure everything is configured

```bash
dietpi-config
dietpi-services
dietpi-software
```

Follow the README.md for services/lab-ups/ 
