# pve-02

- Dell - OptiPlex 7080 Mini
    - CPU:
        - Intel Core i5-10600
            - Cores: 6C / 12T
            - Frequency: 3.3 GHz base / 4.8 GHz boost
    - RAM:
        - 16GB DDR4 (2x8GB, Dual Channel)
    - Storage:
        - 1TB NVMe M.2 SSD
    - Network:
        - 1Gbps Intel (Onboard)
        - 2.5Gbps Intel i226v (M.2 A+E Key Adapter)

## BIOS

- Integrated NIC: Enabled
- Secure Boot: Disabled
- Virtualization Support: All Enabled
- AC Recovery: Last State
- Wake on LAN: Enabled

## Notes

### M.2 to Intel i226-V Adapter Issue

- As described [here](https://www.dell.com/community/en/conversations/optiplex-desktops/25gb-lan-card-in-wifi-slot-optiplex-7080/67374109520b7c11ac4cfce0), OptiPlex 7080s don't play nice with M.2 to Ethernet adapters. A B+M key adapter in the M.2 NVMe SSD slot was only ever recognized at 10Mbps by the Mikrotik switch; all other machines using the same adapter auto-negotiated without issue.
- Returned the B+M key adapter and ordered an A+E key adapter.
