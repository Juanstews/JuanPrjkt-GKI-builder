#!/system/bin/sh
# herald-daemon.sh — userspace property relay for Herald
#
# Polls /sys/kernel/herald/queue/*/ for pending property changes
# and applies them with setprop(1).  Runs as a continuous daemon
# so Herald can publish at any time; the oneshot flag in init.rc
# simply means init won't restart us if we crash.
#
# Started by init.herald.rc after sys.boot_completed=1.
#
# Author: GrayRavens

HERALD_QUEUE="/sys/kernel/herald/queue"
POLL_INTERVAL=2  # seconds between polls
WAIT_TIMEOUT=30  # max seconds to wait for Herald sysfs

# Wait for Herald sysfs to appear (kernel module may load after init)
# Time out after WAIT_TIMEOUT seconds so we don't hang silently
_wait=0
while [ ! -d "$HERALD_QUEUE" ]; do
    _wait=$((_wait + 1))
    if [ "$_wait" -ge "$WAIT_TIMEOUT" ]; then
        log -t herald-daemon "Herald queue not found after ${WAIT_TIMEOUT}s — exiting"
        exit 1
    fi
    sleep 1
done

log -t herald-daemon "Herald queue detected — processing"

while true; do
    for entry in "$HERALD_QUEUE"/*/; do
        # Skip if no entries
        [ "$entry" = "$HERALD_QUEUE/*/" ] && break

        name=$(cat "${entry}name" 2>/dev/null) || continue
        val=$(cat "${entry}value" 2>/dev/null) || continue

        # Skip if empty
        [ -z "$name" ] && continue
        [ -z "$val" ] && continue

        if setprop "$name" "$val"; then
            log -t herald-daemon "setprop OK: $name = $val"
            # Only commit after successful setprop — prevents data loss
            echo 1 > "${entry}commit" 2>/dev/null
        else
            log -t herald-daemon "setprop FAILED: $name = $val (will retry)"
        fi
    done

    sleep "$POLL_INTERVAL"
done
