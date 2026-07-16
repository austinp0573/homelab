# enable overclock and nvme on pi 5

`/boot/firmware/config.txt`

```bash
over_voltage_delta=50000
arm_freq=2800

# NVMe Enablement and Speed Adjustments
dtparam=pciex1
dtparam=pciex1_gen=3
```