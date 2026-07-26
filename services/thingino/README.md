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

---

## New camera with the sc2336 Sensor

Efforts to replicate the setup with the 2 older cameras (acquired in mid 2025) were unsuccessful

Investigation indicates that is because the **sc2336** modules requires more memory at start up to function
- `rmem` must remain at `16M`.

So, instead of the `fw_setenv` commands above, the following should be used on this camera:

- **NOTE**:
    - In order for it to function with the following settings, the stream output will need to be adjusted first:
        - **RTSP Sub-stream:** Turn it completely **OFF**
        - **RTSP Main Stream:**
            - **Width:** 1280
            - **Height:** 720
            - **FPS:** 5
            - **GOP & Max GOP:** 10
            - **Mode:** CBR
            - **Bitrate:** 300
            - **Profile:** 2
            - **Buffers:** -1
            - **Audio in Stream:** OFF


1. Change those configurations
2. Save
3. Reboot
4. SSH in
5. Run the following:

```bash
fw_setenv osmem 48M@0x0
fw_setenv rmem 16M@0x3000000
reboot
```

(a handy calculator for the `mem` values is provided by the [Thingino IPC Memory Calculator](https://thingino.com/ramcalc))


&nbsp;

**466f724a616e6574**
