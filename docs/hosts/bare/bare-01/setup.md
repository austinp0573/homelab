# bare-01

### Ubuntu24.04-server

## Set cpu to performance

```bash
sudo apt update
sudo apt install linux-tools-common linux-tools-$(uname -r)

# get info
sudo cpupower frequency-info

# change governor
sudo cpupower frequency-set -g performance
# other options are available 
# which can be seen in frequency-info
```

