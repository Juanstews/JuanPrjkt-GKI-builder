#!/system/bin/sh
# herald-daemon.sh — userspace property relay for Herald
#
# Polls /sys/kernel/herald/queue/*/ for pending property changes
# and applies them with setprop(1).  Designed to run as a oneshot
# service in init.rc or a background service.
#
# Usage:
#   start herald-daemon          # in init.rc
#   or: nohup sh herald-daemon.sh &
#
# Init.rc snippet:
#   service herald-daemon /system/bin/sh /data/local/tmp/herald-daemon.sh
#       class main
#       user root
#       group root
#       oneshot
#       disabled
#   on boot
#       start herald-daemon
#
# Author: GrayRavens

HERALD_QUEUE="/sys/kernel/herald/queue"
POLL_INTERVAL=2  # seconds between polls

# Wait for Herald sysfs to appear (kernel module may load after init)
while [ ! -d "$HERALD_QUEUE" ]; do
    sleep 1
done

log -t herald-daemon "Herald queue detected — starting poll loop"

while true; do
    for entry in "$HERALD_QUEUE"/*/; do
        # Skip if no entries
        [ "$entry" = "$HERALD_QUEUE/*/" ] && break
        
        name=$(cat "${entry}name" 2>/dev/null) || continue
        val=$(cat "${entry}value" 2>/dev/null) || continue
        
        # Skip if empty
        [ -z "$name" ] && continue
        [ -z "$val" ] && continue
        
        log -t herald-daemon "setprop $name = $val"
        setprop "$name" "$val"
        
        # Mark as consumed — Herald will clean up the entry
        echo 1 > "${entry}commit" 2>/dev/null
    done
    
    sleep "$POLL_INTERVAL"
done
