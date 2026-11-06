# setup k8s using `kubeadm` on alpine3.24.1

derived from the instructions at:
[https://wiki.alpinelinux.org/wiki/K8s](https://wiki.alpinelinux.org/wiki/K8s)
**With some adjustments for version and personal configurations**

## Prerequisites

You need an Alpine Linux install (this guide is written against version 3.24 standard image) with internet access. I recommend at least 2 CPU with 4GB of ram and 10GB of disk for each node.

For HA control planes you'll need a mininum of three nodes

## 1. Setup the Repositories
Update you repositories under `/etc/apk/repositories` to include community, edge community and testing.

Contents of /etc/apk/repositories:

```sh
#/media/sr0/apks
http://dl-cdn.alpinelinux.org/alpine/v3.24/main
http://dl-cdn.alpinelinux.org/alpine/v3.24/community
# edge
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
```

## 2. Node Setup

This series of commands solves a series is incremental problems and sets up the system (if the first control node) for kubectl/kubeadm to run properly on next login by linking the config.

The result here gives you a functional node that can be joined to an existing cluster or can become the first control plane of a new cluster.

**Note:** This build assumes CNI usage of flannel for networking. Skip the flannel packages if you want to use calico

### Add kernel module for networking stuff

```sh
echo "br_netfilter" > /etc/modules-load.d/k8s.conf
modprobe br_netfilter
sysctl net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
```

### Kernel stuff

```sh
echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
sysctl net.bridge.bridge-nf-call-iptables=1
```

### Installing kubernetes packages

```SH
apk add cni-plugin-flannel
apk add cni-plugins
apk add flannel
apk add flannel-contrib-cni
apk add kubelet
apk add kubeadm
apk add kubectl
apk add containerd
apk add uuidgen
apk add nfs-utils
```

### Get rid of swap

* **IF USING ZRAM & SWAP DO __NOT__ RUN THE FOLLOWING COMMANDS**

```sh
cp -av /etc/fstab /etc/fstab.bak
sed -i '/swap/s/^/#/' /etc/fstab
swapoff -a
```

### Fix prometheus errors

`mount --make-rshared /`

```sh
echo "#!/bin/sh" > /etc/local.d/sharemetrics.start
echo "mount --make-rshared /" >> /etc/local.d/sharemetrics.start
chmod +x /etc/local.d/sharemetrics.start
rc-update add local
```

### Fix id error messages

```sh
uuidgen > /etc/machine-id
```

### Update the containerd sandbox_image to the latest version

find the version with:

```sh
kubeadm config images list --kubernetes-version v1.37.0 | rg -n "pause"
# return should look like:
6:registry.k8s.io/pause:3.10.2
# pause should be set at 3.10.2
```

or check if it's already properly configured:

```sh
rg -n "sandbox" /etc/containerd/config.toml
# should look something like this:
28:      sandbox = 'registry.k8s.io/pause:3.10.2'
76:          sandboxer = 'podsandbox'
```

**NOTE: if `28: sandbox = 'registry.k8s.io/pause:3.10.2'` does not already have the value that was output by the `kubeadm config images list` command, it needs to be altered so that it matches**

### Add kubernetes services on all controlplane and worker nodes

```sh
rc-update add containerd
rc-update add kubelet
rc-service containerd start
```

### Enable time sync (Not required in 3.20 if using default chrony)

```sh
rc-update add ntpd
rc-service ntpd start
```

### Option 1 - Using flannel as your CNI

NOTE: This may no longer be necessary on newer versions of the flannel package

```sh
ln -s /usr/libexec/cni/flannel-amd64 /usr/libexec/cni/flannel
```

### Option 2 - Using calico as your CNI NOTE: This is required in 3.20 if you use calico

```sh
ln -s /opt/cni/bin/calico /usr/libexec/cni/calico
ln -s /opt/cni/bin/calico-ipam  /usr/libexec/cni/calico-ipam
```

### Pin your versions! If you update and the nodes get out of sync, it implodes.

```sh
apk add 'kubelet=~1.37'
apk add 'kubeadm=~1.37'
apk add 'kubectl=~1.37'

# double check
rg '(=|<|>|~|@)' /etc/apk/world
```

**Note: In the future you will manually have to add a newer version the same way to upgrade.**

## Additional steps I encountered

### 2a. Check containerd `SystemdCgroup`

```sh
rg -in "systemd" /etc/containerd/config.toml
# Needs to be false
88:            SystemdCgroup = false
```

### 2b. Make sure cgroupv2 is active

```sh
rg "cgroup2?" /proc/mounts
# should look like:
16:cgroup2 /sys/fs/cgroup cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate 0 0
```

### 2c. Create the declarative configuration file

To prevent kubeadm from overwriting /var/lib/kubelet/config.yaml with systemd defaults, write and pass a declarative configuration file in order to:

1. ensure the proper `cgroupDriver` is used.
    * by **default** it's set to `systemd`
2. Taint the node to allow swap.

`/root/kubeadm-config.toml`:
```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
nodeRegistration:
  name: $(hostname)
  criSocket: unix:///var/run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.37.0
networking:
  podSubnet: 10.244.0.0/16 # DO NOT CHANGE
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: cgroupfs
failSwapOn: false
memorySwap:
  swapBehavior: LimitedSwap
```

Your blank node is now ready! If it's the first, you'll want to make a control node.

### 3. Setup the Control Plane (New Cluster!)
Run this command to start the cluster and then apply a network.

```sh
#do not change subnet
# old tutorial command:
# kubeadm init --pod-network-cidr=10.244.0.0/16 --node-name=$(hostname)
# mkdir ~/.kube
# ln -s /etc/kubernetes/admin.conf /root/.kube/config

# what I used:
kubeadm init --config=kubeadm-config.yaml
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chmod 600 /root/.kube/config
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

You now have a control plane. This also gives you the command to run on our blank nodes to add them to this cluster as workers.

### If `kubeadm init` fails:

Reset before you try again:

```sh
kubeadm reset -f
rm -rf /etc/kubernetes/manifests/* /var/lib/etcd /etc/cni/net.d/*
```

### Verify admin connectivity

```sh
kubectl get nodes
```

#### If you get a `NotReady`.

Check why with:

```sh
kubectl describe node k8c-01 | rg -A 10 "Conditions:"
```

#### Check pod state

```sh
kubectl get pods -n kube-system -o wide
```

## Administer the cluster remotely

To control the cluster from a local workstation, transfer the administrative kubeconfig file (`/etc/kubernetes/admin.conf`) from the control plane node (`10.0.90.50`) to the local user's `~/.kube/config` directory and use the local `kubectl` CLI.

| Step | Action | Target Location | Command |
| --- | --- | --- | --- |
| **1. Install CLI** | Install `kubectl` | Local Workstation | Native package manager or direct binary download |
| **2. Retrieve Config** | Copy `admin.conf` via SSH | Local Workstation | `scp root@10.0.90.50:/etc/kubernetes/admin.conf ~/.kube/config` |
| **3. Secure Permissions** | Restrict file access | Local Workstation | `chmod 600 ~/.kube/config` |
| **4. Verify Access** | Test API server endpoint | Local Workstation | `kubectl get nodes -o wide` |

---

### Step 1: Install `kubectl` on the Local Machine

If `kubectl` is not already installed on your a workstation, install the client binary:

```sh
# For Ubuntu/Debian:
sudo apt-get update && sudo apt-get install -y kubectl

# Direct binary install (Linux amd64):
curl -LO "https://dl.k8s.io/release/v1.37.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

---

### Step 2: Transfer the Kubeconfig File

Run the following commands **from the local machine's terminal** (not on the node):

1. Create the local configuration directory:

```sh
mkdir -p ~/.kube
```

2. Copy the configuration file from `k8c-01`:

```sh
scp root@10.0.90.50:/etc/kubernetes/admin.conf ~/.kube/config
```
*(Note: If there is already an existing cluster(s) configured in `~/.kube/config`, save it to a separate path like `~/.kube/k8c-01.conf` and merge contexts, or export `KUBECONFIG=~/.kube/k8c-01.conf`).*
3. Restrict read/write permissions to your local user:

```sh
chmod 600 ~/.kube/config
```

---

### Step 4: Verify Remote API Connectivity

Verify that the local client connects directly to the control plane IP:

```sh
kubectl cluster-info
```

Check the node status remotely:

```sh
kubectl get nodes -o wide
```

```text
NAME     STATUS   ROLES           AGE   VERSION   INTERNAL-IP   OS-IMAGE      KERNEL-VERSION   CONTAINER-RUNTIME
k8c-01   Ready    control-plane   12m   v1.37.0   10.0.90.50    Alpine Linux  ...              containerd://...
```

---

* Verify local network route reachability to `<node_IP>:6443` if the connection times out.
* Rename the default context to identify the homelab cluster clearly: `kubectl config rename-context kubernetes-admin@kubernetes k8c-01`.
* Add shell completion and an alias to your local `~/.bashrc` or `~/.zshrc`: `source <(kubectl completion bash)` and `alias k=kubectl`.
