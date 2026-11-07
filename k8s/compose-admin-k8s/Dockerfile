# BASE IMAGE
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

USER root

# use a normal toolbox process
ENTRYPOINT []


# SHELL AND UNIX TOOLS

# core interactive environment
RUN apk add --no-cache \
    bash \
    bash-completion \
    ca-certificates \
    curl \
    wget \
    git \
    openssh-client \
    openssh-keygen \
    openssl \
    less \
    vim \
    tmux \
    tzdata


# general unix utilities
RUN apk add --no-cache \
    coreutils \
    findutils \
    diffutils \
    grep \
    sed \
    gawk \
    util-linux \
    procps \
    psmisc \
    file \
    tree \
    tar \
    gzip \
    xz \
    unzip \
    zip \
    patch \
    make \
    gettext \
    rsync \
    zstd


# jq and yq
# mike farah yq matches the shell configuration
RUN apk add --no-cache \
    jq \
    yq-go


# shell conveniences
RUN apk add --no-cache \
    fzf \
    ripgrep \
    fd \
    bat \
    eza \
    fastfetch


# shared completion directory
RUN mkdir -p /usr/share/bash-completion/completions


# default shell configuration
COPY config/dotfiles/bashrc /etc/skel/.bashrc


# architecture for release downloads
RUN set -eu; \
    architecture="$(uname -m)"; \
    case "$architecture" in \
        x86_64) printf '%s\n' amd64 > /tmp/tool-arch ;; \
        aarch64) printf '%s\n' arm64 > /tmp/tool-arch ;; \
        *) printf 'Unsupported architecture: %s\n' "$architecture" >&2; exit 1 ;; \
    esac


# KUBERNETES CLIENTS

# kubectl, supplied by the base image
RUN kubectl completion bash > /usr/share/bash-completion/completions/kubectl


# kubectx and kubens
RUN apk add --no-cache kubectx


# kubecolor
ARG KUBECOLOR_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/kubecolor.tar.gz" \
        "https://github.com/kubecolor/kubecolor/releases/download/${KUBECOLOR_VERSION}/kubecolor_${KUBECOLOR_VERSION#v}_linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/kubecolor.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/kubecolor" /usr/local/bin/kubecolor; \
    kubecolor --kubecolor-version; \
    rm -rf "$tmp"


# k9s
ARG K9S_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/k9s.tar.gz" \
        "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/k9s.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/k9s" /usr/local/bin/k9s; \
    k9s version; \
    rm -rf "$tmp"


# stern
ARG STERN_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/stern.tar.gz" \
        "https://github.com/stern/stern/releases/download/${STERN_VERSION}/stern_${STERN_VERSION#v}_linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/stern.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/stern" /usr/local/bin/stern; \
    stern --version; \
    rm -rf "$tmp"


# etcdctl
RUN apk add --no-cache etcd-ctl


# talosctl
ARG TALOSCTL_VERSION
ARG KUBERNETES_VERSION
ENV TALOS_VERSION=${TALOSCTL_VERSION}
ENV KUBERNETES_VERSION=${KUBERNETES_VERSION}
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/talosctl" \
        "https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}/talosctl-linux-${arch}"; \
    install -m 0755 "$tmp/talosctl" /usr/local/bin/talosctl; \
    talosctl version --client; \
    talosctl completion bash > /usr/share/bash-completion/completions/talosctl; \
    rm -rf "$tmp"


# omnictl, optional
ARG OMNICTL_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/omnictl" \
        "https://github.com/siderolabs/omni/releases/download/${OMNICTL_VERSION}/omnictl-linux-${arch}"; \
    install -m 0755 "$tmp/omnictl" /usr/local/bin/omnictl; \
    omnictl --help > /dev/null; \
    omnictl completion bash > /usr/share/bash-completion/completions/omnictl; \
    rm -rf "$tmp"


# ======================================================================
# KREW AND PLUGINS, REMOVE TOGETHER
ENV KREW_ROOT=/opt/krew
ENV PATH="/opt/krew/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# krew index
# plugin manifests come from the current upstream index
RUN set -eu; \
    mkdir -p "$KREW_ROOT/index"; \
    git clone --depth=1 https://github.com/kubernetes-sigs/krew-index.git "$KREW_ROOT/index/default"


# krew plugin manager
ARG KREW_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/krew.tar.gz" \
        "https://github.com/kubernetes-sigs/krew/releases/download/${KREW_VERSION}/krew-linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/krew.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/krew-linux_${arch}" /usr/local/bin/kubectl-krew; \
    kubectl krew version; \
    rm -rf "$tmp"


# access matrix, effective rbac permissions
RUN kubectl krew install --manifest="$KREW_ROOT/index/default/plugins/access-matrix.yaml"


# tree, resource ownership
RUN kubectl krew install --manifest="$KREW_ROOT/index/default/plugins/tree.yaml"


# resource capacity, requests and limits and metrics
RUN kubectl krew install --manifest="$KREW_ROOT/index/default/plugins/resource-capacity.yaml"


# get all, resource types beyond kubectl get all
RUN kubectl krew install --manifest="$KREW_ROOT/index/default/plugins/get-all.yaml"


# who can, rbac subjects with access
RUN kubectl krew install --manifest="$KREW_ROOT/index/default/plugins/who-can.yaml"


# rolesum, rbac summary for a subject
RUN kubectl krew install --manifest="$KREW_ROOT/index/default/plugins/rolesum.yaml"


# view allocations, resource allocation and utilization
RUN kubectl krew install --manifest="$KREW_ROOT/index/default/plugins/view-allocations.yaml"


# krew plugin permissions
RUN chmod -R a+rX "$KREW_ROOT"
# ======================================================================


# AUTHENTICATION

# kubelogin, generic oidc
ARG KUBELOGIN_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/kubelogin.zip" \
        "https://github.com/int128/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin_linux_${arch}.zip"; \
    unzip -q "$tmp/kubelogin.zip" -d "$tmp"; \
    install -m 0755 "$tmp/kubelogin" /usr/local/bin/kubelogin; \
    ln -s /usr/local/bin/kubelogin /usr/local/bin/kubectl-oidc_login; \
    kubectl oidc-login --version; \
    kubelogin completion bash > /usr/share/bash-completion/completions/kubelogin; \
    rm -rf "$tmp"


# DEPLOYMENT

# flux
ARG FLUX_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/flux.tar.gz" \
        "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/flux_${FLUX_VERSION#v}_linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/flux.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/flux" /usr/local/bin/flux; \
    flux --version; \
    flux completion bash > /usr/share/bash-completion/completions/flux; \
    rm -rf "$tmp"


# age
RUN apk add --no-cache age


# sops
ARG SOPS_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/sops" \
        "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${arch}"; \
    install -m 0755 "$tmp/sops" /usr/local/bin/sops; \
    sops --version; \
    rm -rf "$tmp"


# ======================================================================
# HELM AND PLUGINS AND HELMFILE, REMOVE TOGETHER
# plugins stay in the image rather than the persistent state mount
ENV HELM_PLUGINS=/opt/helm/plugins

# helm
ARG HELM_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/helm.tar.gz" \
        "https://get.helm.sh/helm-${HELM_VERSION}-linux-${arch}.tar.gz"; \
    tar -xzf "$tmp/helm.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/linux-${arch}/helm" /usr/local/bin/helm; \
    mkdir -p "$HELM_PLUGINS"; \
    helm version --short; \
    helm completion bash > /usr/share/bash-completion/completions/helm; \
    rm -rf "$tmp"


# helm diff, required by helmfile diff
ARG HELM_DIFF_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/helm-diff.tgz" \
        "https://github.com/databus23/helm-diff/releases/download/${HELM_DIFF_VERSION}/helm-diff-linux-${arch}.tgz"; \
    mkdir -p "$HELM_PLUGINS"; \
    tar -xzf "$tmp/helm-diff.tgz" -C "$HELM_PLUGINS"; \
    helm diff version; \
    rm -rf "$tmp"


# helm secrets, requires sops and age
ARG HELM_SECRETS_VERSION
RUN set -eu; \
    tmp="$(mktemp -d)"; \
    mkdir -p "$HELM_PLUGINS"; \
    for plugin in secrets secrets-getter secrets-post-renderer; do \
        curl -fsSL --retry 3 \
            -o "$tmp/$plugin.tgz" \
            "https://github.com/jkroepke/helm-secrets/releases/download/${HELM_SECRETS_VERSION}/${plugin}-${HELM_SECRETS_VERSION#v}.tgz"; \
        tar -xzf "$tmp/$plugin.tgz" -C "$HELM_PLUGINS"; \
    done; \
    helm secrets --version; \
    rm -rf "$tmp"


# helm plugin permissions
RUN chmod -R a+rX "$HELM_PLUGINS"


# helmfile
ARG HELMFILE_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/helmfile.tar.gz" \
        "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION#v}_linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/helmfile.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/helmfile" /usr/local/bin/helmfile; \
    helmfile --version; \
    rm -rf "$tmp"
# ======================================================================


# argocd, optional
# ARG ARGOCD_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/argocd" \
#         "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${arch}"; \
#     install -m 0755 "$tmp/argocd" /usr/local/bin/argocd; \
#     argocd version --client; \
#     argocd completion bash > /usr/share/bash-completion/completions/argocd; \
#     rm -rf "$tmp"


# STANDALONE KUSTOMIZE
ARG KUSTOMIZE_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/kustomize.tar.gz" \
        "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/kustomize.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/kustomize" /usr/local/bin/kustomize; \
    kustomize version; \
    kustomize completion bash > /usr/share/bash-completion/completions/kustomize; \
    rm -rf "$tmp"


# NETWORKING

# cilium cli
ARG CILIUM_CLI_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/cilium.tar.gz" \
        "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${arch}.tar.gz"; \
    tar -xzf "$tmp/cilium.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/cilium" /usr/local/bin/cilium; \
    cilium version --client; \
    cilium completion bash > /usr/share/bash-completion/completions/cilium; \
    rm -rf "$tmp"


# hubble cli
ARG HUBBLE_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/hubble.tar.gz" \
        "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${arch}.tar.gz"; \
    tar -xzf "$tmp/hubble.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/hubble" /usr/local/bin/hubble; \
    hubble version; \
    hubble completion bash > /usr/share/bash-completion/completions/hubble; \
    rm -rf "$tmp"


# network troubleshooting
RUN apk add --no-cache \
    bind-tools \
    iproute2 \
    iputils \
    netcat-openbsd \
    nmap \
    tcpdump \
    socat \
    mtr \
    busybox-extras


# istioctl, optional
# ARG ISTIOCTL_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/istioctl.tar.gz" \
#         "https://github.com/istio/istio/releases/download/${ISTIOCTL_VERSION}/istioctl-${ISTIOCTL_VERSION}-linux-${arch}.tar.gz"; \
#     tar -xzf "$tmp/istioctl.tar.gz" -C "$tmp"; \
#     install -m 0755 "$tmp/istioctl" /usr/local/bin/istioctl; \
#     istioctl version --remote=false; \
#     istioctl completion bash > /usr/share/bash-completion/completions/istioctl; \
#     rm -rf "$tmp"


# linkerd, optional edge release
# ARG LINKERD_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/linkerd" \
#         "https://github.com/linkerd/linkerd2/releases/download/${LINKERD_VERSION}/linkerd2-cli-${LINKERD_VERSION}-linux-${arch}"; \
#     install -m 0755 "$tmp/linkerd" /usr/local/bin/linkerd; \
#     linkerd version --client; \
#     linkerd completion bash > /usr/share/bash-completion/completions/linkerd; \
#     rm -rf "$tmp"


# calicoctl, optional
# ARG CALICOCTL_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/calicoctl" \
#         "https://github.com/projectcalico/calico/releases/download/${CALICOCTL_VERSION}/calicoctl-linux-${arch}"; \
#     install -m 0755 "$tmp/calicoctl" /usr/local/bin/calicoctl; \
#     calicoctl version --client; \
#     calicoctl completion bash > /usr/share/bash-completion/completions/calicoctl; \
#     rm -rf "$tmp"


# VALIDATION AND POLICY

# shellcheck and shfmt
RUN apk add --no-cache \
    shellcheck \
    shfmt


# yamllint, includes its python runtime dependencies
RUN apk add --no-cache yamllint


# kubeconform
ARG KUBECONFORM_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/kubeconform.tar.gz" \
        "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-${arch}.tar.gz"; \
    tar -xzf "$tmp/kubeconform.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/kubeconform" /usr/local/bin/kubeconform; \
    kubeconform -v; \
    rm -rf "$tmp"


# kube linter
ARG KUBE_LINTER_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    case "$arch" in \
        amd64) archive=kube-linter-linux.tar.gz ;; \
        arm64) archive=kube-linter-linux_arm64.tar.gz ;; \
    esac; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/kube-linter.tar.gz" \
        "https://github.com/stackrox/kube-linter/releases/download/${KUBE_LINTER_VERSION}/${archive}"; \
    tar -xzf "$tmp/kube-linter.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/kube-linter" /usr/local/bin/kube-linter; \
    kube-linter version; \
    rm -rf "$tmp"


# conftest
ARG CONFTEST_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    case "$arch" in \
        amd64) arch=x86_64 ;; \
    esac; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/conftest.tar.gz" \
        "https://github.com/open-policy-agent/conftest/releases/download/${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION#v}_Linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/conftest.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/conftest" /usr/local/bin/conftest; \
    conftest --version; \
    conftest completion bash > /usr/share/bash-completion/completions/conftest; \
    rm -rf "$tmp"


# kube score
ARG KUBE_SCORE_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/kube-score" \
        "https://github.com/zegl/kube-score/releases/download/${KUBE_SCORE_VERSION}/kube-score_${KUBE_SCORE_VERSION#v}_linux_${arch}"; \
    install -m 0755 "$tmp/kube-score" /usr/local/bin/kube-score; \
    kube-score version; \
    rm -rf "$tmp"


# pluto
ARG PLUTO_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/pluto.tar.gz" \
        "https://github.com/FairwindsOps/pluto/releases/download/${PLUTO_VERSION}/pluto_${PLUTO_VERSION#v}_linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/pluto.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/pluto" /usr/local/bin/pluto; \
    pluto version; \
    pluto completion bash > /usr/share/bash-completion/completions/pluto; \
    rm -rf "$tmp"


# kubent
ARG KUBENT_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/kubent.tar.gz" \
        "https://github.com/doitintl/kube-no-trouble/releases/download/${KUBENT_VERSION}/kubent-${KUBENT_VERSION}-linux-${arch}.tar.gz"; \
    tar -xzf "$tmp/kubent.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/kubent" /usr/local/bin/kubent; \
    kubent --version; \
    rm -rf "$tmp"


# dyff
ARG DYFF_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/dyff.tar.gz" \
        "https://github.com/homeport/dyff/releases/download/${DYFF_VERSION}/dyff_${DYFF_VERSION#v}_linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/dyff.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/dyff" /usr/local/bin/dyff; \
    dyff version; \
    dyff completion bash > /usr/share/bash-completion/completions/dyff; \
    rm -rf "$tmp"


# kyverno cli, optional
# ARG KYVERNO_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     case "$arch" in \
#         amd64) arch=x86_64 ;; \
#     esac; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/kyverno.tar.gz" \
#         "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/kyverno-cli_${KYVERNO_VERSION}_linux_${arch}.tar.gz"; \
#     tar -xzf "$tmp/kyverno.tar.gz" -C "$tmp"; \
#     install -m 0755 "$tmp/kyverno" /usr/local/bin/kyverno; \
#     kyverno version; \
#     kyverno completion bash > /usr/share/bash-completion/completions/kyverno; \
#     rm -rf "$tmp"


# kyverno chainsaw, optional
# ARG CHAINSAW_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/chainsaw.tar.gz" \
#         "https://github.com/kyverno/chainsaw/releases/download/${CHAINSAW_VERSION}/chainsaw_linux_${arch}.tar.gz"; \
#     tar -xzf "$tmp/chainsaw.tar.gz" -C "$tmp"; \
#     install -m 0755 "$tmp/chainsaw" /usr/local/bin/chainsaw; \
#     chainsaw version; \
#     chainsaw completion bash > /usr/share/bash-completion/completions/chainsaw; \
#     rm -rf "$tmp"


# REGISTRIES AND SECURITY

# skopeo
RUN apk add --no-cache skopeo


# crane
ARG CRANE_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    case "$arch" in \
        amd64) arch=x86_64 ;; \
    esac; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/crane.tar.gz" \
        "https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/go-containerregistry_Linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/crane.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/crane" /usr/local/bin/crane; \
    crane version; \
    crane completion bash > /usr/share/bash-completion/completions/crane; \
    rm -rf "$tmp"


# oras
ARG ORAS_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/oras.tar.gz" \
        "https://github.com/oras-project/oras/releases/download/${ORAS_VERSION}/oras_${ORAS_VERSION#v}_linux_${arch}.tar.gz"; \
    tar -xzf "$tmp/oras.tar.gz" -C "$tmp"; \
    install -m 0755 "$tmp/oras" /usr/local/bin/oras; \
    oras version; \
    oras completion bash > /usr/share/bash-completion/completions/oras; \
    rm -rf "$tmp"


# regctl, optional
# ARG REGCTL_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/regctl" \
#         "https://github.com/regclient/regclient/releases/download/${REGCTL_VERSION}/regctl-linux-${arch}"; \
#     install -m 0755 "$tmp/regctl" /usr/local/bin/regctl; \
#     regctl version; \
#     regctl completion bash > /usr/share/bash-completion/completions/regctl; \
#     rm -rf "$tmp"


# cosign, optional
# ARG COSIGN_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/cosign" \
#         "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-${arch}"; \
#     install -m 0755 "$tmp/cosign" /usr/local/bin/cosign; \
#     cosign version; \
#     cosign completion bash > /usr/share/bash-completion/completions/cosign; \
#     rm -rf "$tmp"


# syft, optional
# ARG SYFT_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/syft.tar.gz" \
#         "https://github.com/anchore/syft/releases/download/${SYFT_VERSION}/syft_${SYFT_VERSION#v}_linux_${arch}.tar.gz"; \
#     tar -xzf "$tmp/syft.tar.gz" -C "$tmp"; \
#     install -m 0755 "$tmp/syft" /usr/local/bin/syft; \
#     syft version; \
#     syft completion bash > /usr/share/bash-completion/completions/syft; \
#     rm -rf "$tmp"


# trivy, optional
# ARG TRIVY_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     case "$arch" in \
#         amd64) arch=64bit ;; \
#         arm64) arch=ARM64 ;; \
#     esac; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/trivy.tar.gz" \
#         "https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_${TRIVY_VERSION#v}_Linux-${arch}.tar.gz"; \
#     tar -xzf "$tmp/trivy.tar.gz" -C "$tmp"; \
#     install -m 0755 "$tmp/trivy" /usr/local/bin/trivy; \
#     trivy --version; \
#     trivy completion bash > /usr/share/bash-completion/completions/trivy; \
#     rm -rf "$tmp"


# BACKUP AND OBJECT STORAGE

# restic
ARG RESTIC_VERSION
RUN set -eu; \
    apk add --no-cache bzip2; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/restic.bz2" \
        "https://github.com/restic/restic/releases/download/${RESTIC_VERSION}/restic_${RESTIC_VERSION#v}_linux_${arch}.bz2"; \
    bunzip2 "$tmp/restic.bz2"; \
    install -m 0755 "$tmp/restic" /usr/local/bin/restic; \
    restic version; \
    restic generate --bash-completion /usr/share/bash-completion/completions/restic; \
    rm -rf "$tmp"


# rclone
ARG RCLONE_VERSION
RUN set -eu; \
    arch="$(cat /tmp/tool-arch)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 \
        -o "$tmp/rclone.zip" \
        "https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-${arch}.zip"; \
    unzip -q "$tmp/rclone.zip" -d "$tmp"; \
    install -m 0755 "$tmp/rclone-${RCLONE_VERSION}-linux-${arch}/rclone" /usr/local/bin/rclone; \
    unset RCLONE_VERSION; \
    rclone version; \
    rclone completion bash /usr/share/bash-completion/completions/rclone; \
    rm -rf "$tmp"


# velero cli, optional
# ARG VELERO_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/velero.tar.gz" \
#         "https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-${arch}.tar.gz"; \
#     tar -xzf "$tmp/velero.tar.gz" -C "$tmp"; \
#     install -m 0755 "$tmp/velero-${VELERO_VERSION}-linux-${arch}/velero" /usr/local/bin/velero; \
#     velero version --client-only; \
#     velero completion bash > /usr/share/bash-completion/completions/velero; \
#     rm -rf "$tmp"


# OPTIONAL AUTOMATION

# opentofu, optional
# ARG OPENTOFU_VERSION
# RUN set -eu; \
#     arch="$(cat /tmp/tool-arch)"; \
#     tmp="$(mktemp -d)"; \
#     curl -fsSL --retry 3 \
#         -o "$tmp/tofu.tar.gz" \
#         "https://github.com/opentofu/opentofu/releases/download/${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION#v}_linux_${arch}.tar.gz"; \
#     tar -xzf "$tmp/tofu.tar.gz" -C "$tmp"; \
#     install -m 0755 "$tmp/tofu" /usr/local/bin/tofu; \
#     tofu version; \
#     printf '%s\n' 'complete -o nospace -C /usr/local/bin/tofu tofu' > /usr/share/bash-completion/completions/tofu; \
#     rm -rf "$tmp"


# python development, optional
# RUN apk add --no-cache \
#     python3 \
#     python3-dev \
#     py3-pip \
#     py3-virtualenv \
#     build-base


# ansible, optional
# RUN apk add --no-cache \
#     python3 \
#     ansible


# aws cli, optional
# RUN apk add --no-cache aws-cli aws-cli-bash-completion \
#     && ln -s aws_bash_completer /usr/share/bash-completion/completions/aws \
#     && aws --version


# USER SETUP
ARG USER_NAME
ARG USER_UID
ARG USER_GID

# ownership applies inside the image, not to host bind mounts
RUN set -eu; \
    addgroup -g "${USER_GID}" "${USER_NAME}"; \
    adduser -D -u "${USER_UID}" -G "${USER_NAME}" \
        -h "/home/${USER_NAME}" -s /bin/bash "${USER_NAME}"; \
    mkdir -p /config /state /workspace; \
    chown -R "${USER_UID}:${USER_GID}" "/home/${USER_NAME}" /state /workspace


# CLEANUP
RUN rm -f /tmp/tool-arch \
    && printf '' > /etc/motd


# RUNTIME
ENV HOME="/home/${USER_NAME}"
USER ${USER_NAME}
WORKDIR /workspace
CMD ["sleep", "infinity"]
