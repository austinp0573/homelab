# ubuntu-cloud-image-setup

Setup scripts for an Ubuntu Server 26.04.1 cloud image.

## setup

```bash
cp .env.example .env
chmod 600 .env
# edit .env as needed
sudo ./setup.sh
```

## files

- `core/` base setup scripts run automatically in order:
  - `81-speedtest-go.sh`: installs speedtest-go binary
  - `90-zram-swap.sh`: configures zram swap and swapfile
- `optional/` extra enhancements and utilities:
  - `70-vim-nox.sh`: installs vim-nox and configures system-wide vimrc
  - `75-bat.sh`: installs bat from github releases
  - `80-shell-ux.sh`: installs shell aliases, prompt, and welcome banner
  - `91-nerdctl-full-setup.sh`: installs full nerdctl + containerd stack
- `lib/common.sh`: shared helpers

## individual scripts

Scripts can be run on their own after `.env` exists:

```bash
sudo bash core/81-speedtest-go.sh
sudo bash core/90-zram-swap.sh
sudo bash optional/70-vim-nox.sh
sudo bash optional/75-bat.sh
sudo bash optional/80-shell-ux.sh
sudo bash optional/91-nerdctl-full-setup.sh
```
