#!/bin/bash

# 1. Display current Volume Group status
echo "--- Current LVM Volume Group Status ---"
vgs pve

# 2. Extract the free space in Gigabytes (removing the 'g' unit)
# We use 'pve' specifically as that is the default Proxmox VG name
VG_FREE=$(vgs pve --noheadings -o vg_free --units g | sed 's/g//' | xargs)

# 3. Calculate the 95% safety threshold using 'bc' or 'awk'
# awk is used here for standard compatibility on Proxmox
SAFE_VALUE=$(awk "BEGIN {print int($VG_FREE * 0.95)}")

echo ""
echo "Total Free Space: ${VG_FREE}G"
echo "Recommended 95% Value (Safety Buffer): ${SAFE_VALUE}G"
echo "---------------------------------------"

# 4. Prompt for User Input
read -p "Enter the Gigabyte value for your new thin pool (e.g., $SAFE_VALUE): " USER_VAL

# 5. Execute the LVM and Proxmox commands
echo "Creating LVM-Thin Pool 'data' with size ${USER_VAL}G..."
lvcreate -L "${USER_VAL}G" -T pve/data

echo "Registering 'local-lvm' in Proxmox storage config..."

pvesm add lvmthin local-lvm --vgname pve --thinpool data

echo ""
echo "--- Final Storage Status ---"
pvesm status