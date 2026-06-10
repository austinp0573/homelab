# Thingino firmware cameras

In order for the cameras to be able to maintain stability with:
- Wireguard enabled
- Motion-detect enabled
- Ntfy enabled

You need to really reduce the stream resolution:
- stable right now at 640x360
- 10fps
- GOP 20
- CBR
- Bitrate: 1000

### SSH into the cameras and run:

```sh 
fw_setenv osmem 54M@0x0
fw_setenv rmem 10M@0x3600000
reboot
```

This appears to stabilize things.

## TODO

- Attempt to raise the resolution and see if everything remains stable