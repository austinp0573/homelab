# proxmox cloud-init

### Debian 13 Cloud Image Comparison

| Image Variant | Optimization Target | Proxmox Use Case |
| --- | --- | --- |
| **`debian-13-genericcloud-amd64.qcow2`** | Optimized specifically for virtualized KVM/QEMU environments. Stripped of unnecessary physical hardware drivers. | Ideal for typical homelab and production VMs to minimize base storage overhead and memory footprint. |
| **`debian-13-generic-amd64.qcow2`** | Includes broader physical hardware drivers and firmware. | Use only if executing complex deployments requiring guest-level hardware access, such as physical PCIe device passthrough. |
| **`debian-13-nocloud-amd64.qcow2`** | Designed for local testing without a cloud metadata service. | Avoid. Bypasses the native Proxmox Cloud-Init automation infrastructure. |

* [https://cloud.debian.org/images/cloud/](https://cloud.debian.org/images/cloud/)

## setup

1. create minimal vm template 
* OS -> `Do note use any media`
* Disks -> just delete the disk

2. add cloud-init drive
* Hardware -> Add -> local-lvm

3. populate cloud-init vars
* Cloud-Init -> adjust vars
* `Regenerate Image`

4. get cloud image

```bash
sudo mkdir -p /var/lib/vz/template/iso
cd /var/lib/vz/template/iso
curl -LO <image-url>
```

5. run command to apply working console

```bash
qm set <vm_id> --serial0 socket --vga serial0
```

6. resize the cloud image

```bash
qemu-img resize <image-name> 8G
```

7. import disk to proxmox

```bash
qm importdisk <vm_id> <image_name> local-lvm
```

8. add the disk
* webUI -> Hardware -> very bottom `Unused Disk`
* adjust disk variables

9. edit boot order
* Options -> Boot Order 
* adjust appropriately

10. **optionally** convert to template

11. resize a clone's disk

```bash
qm resize <clone_vm_id> virtio0 DESIRED_SIZE
```