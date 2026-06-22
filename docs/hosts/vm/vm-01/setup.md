# vm-01 setup

### General & OS
-   **Machine:** `q35` (Required for proper PCIe passthrough).
-   **BIOS:** `OVMF (UEFI)` (Required for Resizable BAR and modern AMD drivers).
-   **QEMU Agent:** `Enabled` (Allows Proxmox to issue clean commands to the VM).

### CPU Settings
-   **Sockets:** `1`
-   **Cores:** `14` (Map exactly to the 14 physical Broadwell cores).
-   **Type:** `host` (Absolutely mandatory. This exposes the Xeon's AVX2 instructions directly to the VM, which `llama.cpp` and PyTorch rely heavily on for CPU-bound math).
-   **NUMA:** `Unchecked` (Unless it's a dual-socket motherboard with two E5-2680v4s installed, checking NUMA on a single CPU adds unnecessary abstraction overhead).

### Memory Settings
-   **Memory:** `53248` (52GB). 
-   **Minimum Memory:** `53248` (Matches max memory).
-   **Ballooning Device:** `UNCHECKED`. (Mandatory. Memory must be 100% statically pinned to RAM for the GPU DMA controller to function).
-   **KSM (Kernel Samepage Merging):** `UNCHECKED`.

### Disk / Storage
-   **SCSI Controller:** `VirtIO SCSI Single`.
-   **Hard Disk (local-lvm):**
    -   **Async IO:** `io_uring` (Lowest latency for NVMe).
    -   **Discard:** `CHECKED` (Passes TRIM commands to the NVMe to keep write speeds fast over time).
    -   **SSD Emulation:** `CHECKED`.
    -   **IO Thread:** `CHECKED` (Dedicates a specific host CPU thread strictly to handling this drive's I/O, preventing storage bottlenecks when the LLM is loading from disk to VRAM).

### PCIe GPU Passthrough
-   **Device:** Add the AMD GPU via **Add -> PCI Device**.
-   **Flags:** 
    -   `All Functions` (CHECKED - automatically grabs the audio controller).
    -   `ROM-Bar` (CHECKED).
    -   `PCI-Express` (CHECKED).
    -   `Primary GPU` (UNCHECKED - leave this off so the VM boots smoothly headless).

---

### Disable Swap Completely
It is better for the process to crash immediately than to use swap.
```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### Install the ROCm Stack (AMD's CUDA Alternative)
For an AMD Radeon PRO GPU, you must use ROCm to hardware-accelerate PyTorch or Llama.cpp.
1. Add the official AMD ROCm repository for your Ubuntu version.
2. Install the core driver and compute libraries:
   ```bash
   sudo apt install amdgpu-dkms rocm-dev rocm-libs
   ```
3. Add your user to the `render` and `video` groups to grant GPU access without `sudo`:
   ```bash
   sudo usermod -aG render,video $USER
   ```

### Force High Performance Mode in Ubuntu
Just like the host, the guest OS should not attempt to put the CPU to sleep.
```bash
sudo apt install linux-tools-common linux-tools-$(uname -r)
sudo cpupower frequency-set -g performance
```

---

## Software Deployment (Docker + ROCm)

1. **Install Docker:**
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   ```
2. **Run Ollama natively via Docker with ROCm support:**
   This allows you to pull and serve models instantly, leveraging the AMD GPU directly through the container:
   ```bash
   docker run -d \
     --device /dev/kfd \
     --device /dev/dri \
     -v ollama:/root/.ollama \
     -p 11434:11434 \
     --name ollama \
     ollama/ollama:rocm
   ```
