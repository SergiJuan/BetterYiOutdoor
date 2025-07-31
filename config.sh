#!/bin/sh

# Path to log file
LOGFILE=/tmp/sd/wifi/boot.log
echo "[`date`] Starting config.sh..." >> $LOGFILE

# Set LD_LIBRARY_PATH for required shared libraries
export LD_LIBRARY_PATH=/lib:/home/lib:/home/rt/lib:/home/app/locallib:/var/tmp/sd/lib:/tmp/sd/lib:$LD_LIBRARY_PATH
echo "[`date`] LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> $LOGFILE

# Function to kill unnecessary cloud-related processes
kill_cloud () {
    echo "[`date`] Killing cloud processes..." >> $LOGFILE
    killall watch_process 2>/dev/null
    killall watchdog 2>/dev/null
    killall log_server 2>/dev/null
    killall cloud 2>/dev/null
    killall p2p_tnp 2>/dev/null
    killall mp4record 2>/dev/null
    killall oss 2>/dev/null
    killall rmm 2>/dev/null
    killall arp_test 2>/dev/null
}

# Backup firmware if it doesn't already exist
if [ ! -f /var/tmp/sd/backup/mtdblock0.bin ]; then
    echo "[`date`] Running firmware backup..." >> $LOGFILE
    /var/tmp/sd/wifi/make_backup.sh 2>&1 >> $LOGFILE &
    kill_cloud
fi

# Run additional background processes
/var/tmp/sd/wifi/fork_process.sh 2>&1 >> $LOGFILE &
kill_cloud

# Determine the default DHCP script location
DEFAULT_SCRIPT=/backup/script/default.script
if [ -f /home/app/script/default.script ]; then
    DEFAULT_SCRIPT=/home/app/script/default.script
fi

# Static network configuration
IP="192.168.1.123"
NETMASK="255.255.255.0"
GATEWAY="192.168.1.1"

# Launch wpa_supplicant if config exists
if [ -f /var/tmp/sd/Factory/wpa_supplicant.conf ]; then
    echo "[`date`] Running wpa_supplicant..." >> $LOGFILE
    wpa_supplicant -c/var/tmp/sd/Factory/wpa_supplicant.conf -g/var/tmp/wpa_supplicant-global -Dwext -iwlan0 -B
    sleep 3s
fi

# Attempt to assign static IP
echo "[`date`] Assigning static IP $IP..." >> $LOGFILE
ifconfig wlan0 $IP netmask $NETMASK up
route add default gw $GATEWAY wlan0

# Check if the gateway is reachable
ping -c 3 -W 2 $GATEWAY > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "[`date`] Static IP successfully assigned and gateway is reachable." >> $LOGFILE
else
    echo "[`date`] Static IP failed, falling back to DHCP..." >> $LOGFILE
    udhcpc -i wlan0 -b -s "$DEFAULT_SCRIPT" &
    sleep 15
fi

# Log final IP information
echo "[`date`] Checking assigned IP on wlan0..." >> $LOGFILE
ifconfig wlan0 >> $LOGFILE

# Start Telnet server on port 9999 if not already running
echo "[`date`] Starting Telnet on port 9999..." >> $LOGFILE
/bin/busybox telnetd -l /bin/ash -p 9999 >> $LOGFILE 2>&1 &
echo "[`date`] Telnet started." >> $LOGFILE

cd /var/tmp/sd/

# IR-CUT support setup (if present)
if [ -d /var/tmp/sd/Yi/ko ]; then
    echo "[`date`] Setting up IR-CUT support..." >> $LOGFILE
    rm -rf /var/tmp/sd/localko
    cp -R /home/app/localko . 2>/dev/null
    mkdir -p /home/app/localko
    cp /var/tmp/sd/Yi/ko/* /home/app/localko
    mount --bind /var/tmp/sd/localko /home/app/localko
    if [ -x /var/tmp/sd/Yi/load_cpld_ssp ]; then
        /var/tmp/sd/Yi/load_cpld_ssp
        echo "[`date`] load_cpld_ssp executed." >> $LOGFILE
    fi
fi

# Stream and RTSP binaries
STREAM_BIN="/tmp/sd/stream"
RTSP_BIN="/tmp/sd/rRTSPServer"
RTSP_PORT=8556

# Start stream process
if [ -f $STREAM_BIN ]; then
    echo "[`date`] Executing $STREAM_BIN..." >> $LOGFILE
    chmod +x $STREAM_BIN
    if [ -f "/tmp/sd/invert_adc" ]; then
        $STREAM_BIN 1 >> $LOGFILE 2>&1 &
    else
        $STREAM_BIN >> $LOGFILE 2>&1 &
    fi
    sleep 2
    if pgrep -f stream >/dev/null; then
        echo "[`date`] stream started successfully." >> $LOGFILE
    else
        echo "[`date`] Error: stream failed to start." >> $LOGFILE
    fi
else
    echo "[`date`] $STREAM_BIN not found." >> $LOGFILE
fi

# Wait a few seconds to ensure FIFO is ready before launching RTSP server
echo "[`date`] Waiting 7s to ensure FIFO is ready..." >> $LOGFILE
sleep 7

# Start rRTSPServer if not already running
if pgrep -f rRTSPServer >/dev/null; then
    echo "[`date`] rRTSPServer is already running." >> $LOGFILE
else
    if [ -f $RTSP_BIN ]; then
        echo "[`date`] Executing $RTSP_BIN..." >> $LOGFILE
        chmod +x $RTSP_BIN
        $RTSP_BIN -r high -p $RTSP_PORT -d >> $LOGFILE 2>&1 &
        sleep 2
        if pgrep -f rRTSPServer >/dev/null; then
            echo "[`date`] rRTSPServer started successfully." >> $LOGFILE
            echo "[`date`] URL: rtsp://$(ip addr show wlan0 | awk '/inet / {print $2}' | cut -d/ -f1):$RTSP_PORT/ch0_0.h264" >> $LOGFILE
        else
            echo "[`date`] Error: rRTSPServer failed to start." >> $LOGFILE
        fi
    else
        echo "[`date`] $RTSP_BIN not found." >> $LOGFILE
    fi
fi

# Wait for PTZ initialization (for compatible models)
echo "[`date`] Waiting 30s for PTZ movement to complete..." >> $LOGFILE
sleep 30s
killall dispatch 2>/dev/null
killall init.sh 2>/dev/null

echo "[`date`] config.sh fully executed." >> $LOGFILE
