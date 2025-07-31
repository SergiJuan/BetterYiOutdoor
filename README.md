# BetterYiOutdoor
Improved Payload for Yi Outdoor Cameras (Firmware 7.1.00.19A+)

Based on the original discovery by [@rage2dev](https://github.com/rage2dev/YiOutdoor) and inspired by the [@cjj25](https://github.com/cjj25/Yi-RTS3903N-RTSPServer) project, this project provides an improved method to restore **Telnet root access** and enable **RTSP streaming** on **Yi Outdoor cameras** (and some rebrands like Victure or Tuya) running firmware **7.1.00.19A_201910181012** or later.

Yi disabled `telnetd` and serial (TTY) access in newer firmware updates. This payload leverages a **less restricted boot script path** to bypass those limitations without requiring any hardware modification or firmware downgrade.

---

## 🔍 Background

### Problem:
- Since firmware version `7.1.00.19A_201910181012`, Yi cameras no longer start `telnetd`.
- Serial console (`tty`) is also disabled.
- The legacy method using `sdroot/Factory/factory_test.sh` is blocked by `/dispatch`, which prevents WLAN from coming up.

### Original Insight by @rage2dev:
- On boot, the camera runs `/jffs2-root/fs_1/script/wifidhcp.sh`
- This script checks for the file `sdroot/wifi/config.sh` and executes it if present.

---

## ✅ Solution

By placing a custom `config.sh` inside the `wifi` folder on the SD card, we can:
- Kill cloud and P2P processes
- Obtain a static IP or fallback to DHCP
- Launch a Telnet server on port `9999` with root access
- Optionally launch `stream` and `rRTSPServer` binaries
- Enable IR-CUT hardware modules

---

## 🛠 Features (vs original payload)

| Feature                        | @rage2dev | BetterYiOutdoor |
|-------------------------------|-----------|-----------------|
| Telnet root access            | ✅        | ✅              |
| DHCP via `udhcpc`             | ✅        | ✅ (fallback)   |
| Static IP support             | ❌        | ✅              |
| Cloud process killer          | ❌        | ✅              |
| Automatic NAND backup         | ❌        | ✅              |
| RTSP server autostart         | ❌        | ✅              |
| Stream binary control         | ❌        | ✅              |
| IR-CUT loader support         | ❌        | ✅              |
| Boot log to SD                | ❌        | ✅              |

---

## ⚙️ Installation

1. Format a **MicroSD card** (minimum 2GB, recommended 64GB) as **FAT32**

2. Extract the contents of this repository (or your custom payload) directly to the **root** of the SD card.  
   The structure should look like:

   ```
   /wifi/
   /Yi/ko/             (optional - IR-CUT driver support)
   config.sh           (inside /wifi/)
   stream              (at root level)
   rRTSPServer         (at root level)
   load_cpld_ssp       (optional, if needed for IR-CUT)
   wpa_supplicant.conf (WiFi config)
   ```

3. If you're using Wi-Fi and your camera doesn’t have credentials saved, place your `wpa_supplicant.conf` in:
   ```
   /Factory/wpa_supplicant.conf
   ```
   You can use the `wpa_supplicant_sample.conf` provided and edit:
   ```conf
   ssid="SSID_NAME_OF_WIFI"
   psk="WIFI_SECRET_KEY"
   ```
   Then rename the file to `wpa_supplicant.conf`.

4. Insert the SD card into your Yi Outdoor or compatible camera  

5. Power on / reboot the camera

6. Wait ~30 seconds for initialization, then connect via **Telnet**:
   ```
   telnet <camera-ip> 9999
   ```

7. RTSP video stream will be available at:
   ```
   rtsp://<camera-ip>:8556/ch0_0.h264
   ```

   > Check `boot.log` on the SD card to confirm if `rRTSPServer` started successfully.

---

## 📜 Example `config.sh`

See [`wifi/config.sh`](./wifi/config.sh) for the full version, but here's a summary of what it does:

- Sets `LD_LIBRARY_PATH` correctly
- Terminates cloud processes (like `cloud`, `p2p_tnp`, `watch_process`, etc.)
- Executes a backup script if no backup exists yet
- Launches background process handlers
- Tries static IP, falls back to DHCP if ping to gateway fails
- Starts Telnet on port 9999
- Loads IR-CUT modules and mounts drivers if found
- Starts the `stream` binary and `rRTSPServer`
- Logs all output to `wifi/boot.log` for debugging
- Waits 30s and kills leftover startup scripts (`dispatch`, `init.sh`)

---

## 📷 Tested Compatibility

This payload has been successfully tested on the following configuration:

- **Camera model**: Victure SC210  
- **Firmware**: `7.1.00.19A_201910181012`  
- **SD card**: SanDisk 64 GB (formatted as FAT32)

> Note: Not all SD cards or cameras behave identically. If the script fails to execute, try reformatting the SD card or using a smaller capacity (e.g. 32 GB).


---

## 📝 Notes

- This does **not** require firmware flashing or soldering
- The camera must be connected via **WiFi**
- Make sure:
  - The SD card is FAT32
  - `config.sh` uses Unix line endings (LF)
  - Binaries like `stream` and `rRTSPServer` are present and executable
  - The required libraries from the original project [@cjj25](https://github.com/cjj25/Yi-RTS3903N-RTSPServer) are also present, as they are necessary for the binaries to run  
  - All files and folders must be placed in their respective paths, exactly as structured in the original project

---


## 👥 Credits

- [@rage2dev](https://github.com/rage2dev) — original discovery of `config.sh` path
- [@cjj25](https://github.com/cjj25/) — provided the compiled `stream` and `rRTSPServer` binaries and original payload structure
