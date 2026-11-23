# shared talos machine inputs and patches, not Kubernetes manifests.

`base/` - minimal bootstrap settings: static-node DNS, KubePrism, and schedulable control planes. These are patches over Omni-generated configuration, not standalone configs.

`kubespan.patch.yaml` - enables KubeSpan at cluster scope when selected by a template.

`cilium.patch.yaml` - control-plane-only prerequisite that removes Flannel and disables kube-proxy. Cilium's feature settings are not changed by the base. Hardware/network/storage instances belong under `clstr/<cluster>/talos/`; actual Cilium and Longhorn Helm values live under `infra/net/cilium/` and `infra/stor/longhorn/`.
