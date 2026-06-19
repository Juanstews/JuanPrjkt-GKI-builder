#!/usr/bin/env bash
# selinux.sh
# SELinux rule injections for GrayRavens Vindicator drivers + NTSYNC
# Sourced by build.sh — must be called from inside $KSRC
# Author: GrayRavens Team

SELINUX_RULES_C="drivers/kernelsu/selinux/rules.c"

# Sanity check — gracefully skip if KernelSU isn't installed
if [[ ! -f "$SELINUX_RULES_C" ]]; then
    echo "selinux.sh: $SELINUX_RULES_C not found — KernelSU not installed, skipping SELinux injection."
    return 0
fi

inject_selinux() {
    local label="$1"
    local rules="$2"
    echo "Injecting ${label} SELinux rules..."
    sed -i "/rcu_assign_pointer(selinux_state.policy, pol);/i ${rules}" \
        "$SELINUX_RULES_C"
}

# ---------------------------------------------------------------------------
# NTSYNC — Allow kernel worker to chmod and relabel /dev/ntsync
#         Allow Winlator (untrusted_app) to use /dev/ntsync
# ---------------------------------------------------------------------------
inject_selinux "NTSYNC" \
' ksu_allow(db, "kernel", "device", "chr_file", "setattr");\n\
ksu_allow(db, "kernel", "device", "chr_file", "relabelfrom");\n\
ksu_allow(db, "kernel", "gpu_device", "chr_file", "relabelto");\n\
ksu_allow(db, "kernel", "gpu_device", "chr_file", "setattr");\n\
ksu_allow(db, "untrusted_app", "gpu_device", "chr_file", "read");\n\
ksu_allow(db, "untrusted_app", "gpu_device", "chr_file", "write");\n\
ksu_allow(db, "untrusted_app", "gpu_device", "chr_file", "open");\n\
ksu_allow(db, "untrusted_app", "gpu_device", "chr_file", "ioctl");\n\
ksu_allow(db, "untrusted_app", "gpu_device", "chr_file", "map");\n'

# ---------------------------------------------------------------------------
# Vindicator — sysfs enforcement framework
# The framework's enforce() callbacks re-apply tunables that vendor init
# keeps reverting. Needs broad sysfs dir/file access.
# ---------------------------------------------------------------------------
inject_selinux "Vindicator" \
' ksu_allow(db, "kernel", "sysfs", "dir", "search");\n\
ksu_allow(db, "kernel", "sysfs", "dir", "getattr");\n\
ksu_allow(db, "kernel", "sysfs", "file", "read");\n\
ksu_allow(db, "kernel", "sysfs", "file", "write");\n\
ksu_allow(db, "kernel", "sysfs", "file", "open");\n\
ksu_allow(db, "kernel", "sysfs", "file", "getattr");\n'

# ---------------------------------------------------------------------------
# Nocturne — screen-state power saving
# Writes to /dev/cpuset/background/cpus and system-background/cpus
# (cgroupfs) when the display turns off.
# ---------------------------------------------------------------------------
inject_selinux "Nocturne" \
' ksu_allow(db, "kernel", "cgroup", "dir", "search");\n\
ksu_allow(db, "kernel", "cgroup", "dir", "write");\n\
ksu_allow(db, "kernel", "cgroup", "dir", "getattr");\n\
ksu_allow(db, "kernel", "cgroup", "file", "read");\n\
ksu_allow(db, "kernel", "cgroup", "file", "write");\n\
ksu_allow(db, "kernel", "cgroup", "file", "open");\n\
ksu_allow(db, "kernel", "cgroup", "file", "getattr");\n'

# ---------------------------------------------------------------------------
# Equilibrium — profile-aware memory/swap tuning
# Writes /proc/sys/vm/dirty_ratio, dirty_background_ratio, and
# vfs_cache_pressure via filp_open + kernel_write on profile changes.
# ---------------------------------------------------------------------------
inject_selinux "Equilibrium" \
' ksu_allow(db, "kernel", "proc", "file", "write");\n\
ksu_allow(db, "kernel", "proc", "file", "open");\n\
ksu_allow(db, "kernel", "proc", "file", "getattr");\n'

# ---------------------------------------------------------------------------
# Herald — kernel-to-userspace property relay
# Exposes pending properties under /sys/kernel/herald/queue/*/.
# The kernel creates these (kernfs — no file open needed).
# Userspace daemon (system_app domain) reads them.
# ---------------------------------------------------------------------------
inject_selinux "Herald" \
' ksu_allow(db, "system_app", "sysfs_kernel", "dir", "search");\n\
ksu_allow(db, "system_app", "sysfs_kernel", "file", "read");\n\
ksu_allow(db, "system_app", "sysfs_kernel", "file", "open");\n\
ksu_allow(db, "system_app", "sysfs_kernel", "file", "getattr");\n'

echo "✅ All GrayRavens SELinux rules injected successfully"
