FROM node:24-trixie-slim

ARG PUID=1000
ARG PGID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        wget \
        git \
        openssh-client \
        sudo \
        jq \
        ripgrep \
        fd-find \
        findutils \
        coreutils \
        less \
        tree \
        file \
        procps \
        psmisc \
        iproute2 \
        iputils-ping \
        dnsutils \
        netcat-openbsd \
        lsof \
        strace \
        rsync \
        build-essential \
        pkg-config \
        python3 \
        python3-pip \
        python3-venv \
        pipx \
        golang-go \
        rustc \
        cargo \
        shellcheck \
        vim-tiny \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd

# Pi itself explicitly supports installation with --ignore-scripts.
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@latest \
    && npm cache clean --force

# Install the selected third-party Pi packages into the image.
#
# These are deliberately installed normally rather than globally forcing
# --ignore-scripts. Pi packages can have runtime/native dependencies that
# require their normal npm lifecycle installation.
COPY packages/package.json /opt/pi-packages/package.json

RUN cd /opt/pi-packages \
    && npm install \
        --omit=dev \
        --no-audit \
        --no-fund \
    && npm cache clean --force

# The official Node image already contains a "node" user/group.
# Remove them so we can create the Pi account using the host UID/GID.
RUN set -eux; \
    userdel -r node 2>/dev/null || true; \
    groupdel node 2>/dev/null || true; \
    test "${PUID}" != "0"; \
    test "${PGID}" != "0"; \
    groupadd --gid "${PGID}" pi; \
    useradd \
        --uid "${PUID}" \
        --gid "${PGID}" \
        --create-home \
        --shell /bin/bash \
        pi; \
    printf 'pi ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/pi; \
    chmod 0440 /etc/sudoers.d/pi; \
    mkdir -p \
        /home/pi/.pi/agent \
        /home/pi/.config \
        /workspace; \
    chown -R pi:pi \
        /home/pi \
        /workspace

ENV HOME=/home/pi \
    XDG_CONFIG_HOME=/home/pi/.config \
    PI_CODING_AGENT_DIR=/home/pi/.pi/agent \
    PI_TELEMETRY=0 \
    EDITOR=vim \
    VISUAL=vim

USER pi

WORKDIR /workspace

CMD ["sleep", "infinity"]
