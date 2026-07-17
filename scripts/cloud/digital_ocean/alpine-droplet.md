# alpine on digital ocean

do doesn't ship alpine. x86_64 only.

easiest path: grab alpine's official **generic** cloud image and upload it as a custom image. no do-specific build on https://alpinelinux.org/cloud/ — generic + tiny-cloud auto-detects do via metadata (`tiny-cloud-digitalocean`).

must attach an ssh key when creating from a custom image. password auth is off and you can't reset root from the panel.

---

## ssh key

```bash
ssh-keygen -t ed25519 -f ~/.ssh/do_alpine -c "do alpine"
```

cli:

```bash
doctl auth init
doctl compute ssh-key import do-alpine --public-key-file ~/.ssh/do_alpine.pub
doctl compute ssh-key list
```

dashboard: settings → security → ssh keys → add ssh key. paste the `.pub`.

---

## image to use

from https://alpinelinux.org/cloud/ (or the cdn directly):

- provider: `generic`
- arch: `x86_64`
- firmware: `bios` (try this first; uefi is flaky on do custom images)
- bootstrap: `tiny-cloud` (not cloud-init)
- machine: `vm` (not metal)
- format: `qcow2`

example filename (bump version as needed):

```bash
# https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/cloud/
img=generic_alpine-3.24.1-x86_64-bios-tiny-r0.qcow2
url=https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/cloud/$img
```

---

## upload + create droplet

### cli

doctl imports by url (can't push a local file). alpine's cdn url is fine:

```bash
doctl compute image create alpine-generic \
  --image-url "$url" \
  --region nyc3 \
  --image-distribution unknown

doctl compute image list --public=false
```

wait until it's available, then:

```bash
# ids from: doctl compute ssh-key list / doctl compute image list --public=false
doctl compute droplet create alpine-1 \
  --region nyc3 \
  --size s-1vcpu-512mb-10gb \
  --image <image-id> \
  --ssh-keys <ssh-key-id> \
  --wait

doctl compute droplet list
ssh -i ~/.ssh/do_alpine root@<ip>
```

### dashboard

1. backups & snapshots → custom images → import via url (paste `$url`)  
   or upload image if you already downloaded the qcow2
2. distribution: unknown. pick a region.
3. create → droplets → custom images → pick it
4. ssh key required. create.
5. ssh in with that key

---

## if networking / keys don't show up

generic images are still marked alpha. fallbacks:

### bootstrap — convert a debian droplet in place

destructive. ssh key on the debian box or you're locked out.

```bash
doctl compute droplet create alpine-bootstrap \
  --region nyc3 \
  --size s-1vcpu-512mb-10gb \
  --image debian-12-x64 \
  --ssh-keys <ssh-key-id> \
  --wait

ssh -i ~/.ssh/do_alpine root@<ip>
```

on the droplet:

```bash
wget https://github.com/k4mrul/digitalocean-alpine/raw/master/digitalocean-alpine.sh
chmod +x digitalocean-alpine.sh
./digitalocean-alpine.sh
```

```bash
# local, if host key changed
ssh-keygen -r <ip>
ssh -i ~/.ssh/do_alpine root@<ip>
```

snapshot if you want to reuse it:

```bash
doctl compute droplet-action snapshot <droplet-id> --snapshot-name alpine-base
```

dashboard: create debian droplet with ssh key → run script → snapshot under images.

### build a do-tuned image yourself

only if the official generic image is broken for you:

```bash
sudo apt install -y qemu-utils bzip2 e2fsprogs
git clone --recurse-submodules https://github.com/benpye/alpine-droplet.git
cd alpine-droplet
sudo ./build-image.sh
```

host the resulting `*.qcow2.bz2` somewhere public (spaces), then same `doctl compute image create --image-url ...` as above.

---

## notes to self

- prefer official generic qcow2; skip building unless you have to
- bios + tiny + vm is the combo to try first
- if ssh dies mid-bootstrap, use the droplet console in the panel
