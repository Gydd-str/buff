#!/bin/bash

# Comprehensive USB Insertion Monitor
# Captures EVERYTHING that could cause USB insertion freeze/stall

set -e

MONITOR_DIR="/tmp/usb_monitor_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$MONITOR_DIR"
cd "$MONITOR_DIR"

echo "=== USB Comprehensive Monitor ==="
echo "Monitor directory: $MONITOR_DIR"
echo "Timestamp: $(date)"

# Configuration
SAMPLE_INTERVAL=0.1  # 100ms sampling
PRE_MONITOR_TIME=5   # seconds before insertion
POST_MONITOR_TIME=10 # seconds after insertion

# Cleanup function
cleanup() {
    echo -e "\n=== Stopping all monitors ==="
    jobs -p | xargs -r kill 2>/dev/null || true
    wait 2>/dev/null || true
    echo "All monitors stopped"
}
trap cleanup EXIT INT TERM

# Create subdirectories for organized data
mkdir -p {system,interrupts,memory,processes,usb,dma,kernel,io,power,modules,userspace,snapshots,timestamps}

echo "=== Starting comprehensive monitoring ==="
echo "Please wait $PRE_MONITOR_TIME seconds before plugging USB device..."

# ============================================================================
# SYSTEM MONITORS
# ============================================================================

# 1. CPU and Load monitoring
(while true; do
    echo "$(date '+%H:%M:%S.%3N'): $(cat /proc/loadavg)" 
    sleep $SAMPLE_INTERVAL
done) > system/loadavg.log &
LOAD_PID=$!

# 2. CPU usage per core
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    grep "^cpu" /proc/stat
    sleep $SAMPLE_INTERVAL
done) > system/cpu_stats.log &
CPU_PID=$!

# 3. Context switches and interrupts
(while true; do
    echo "$(date '+%H:%M:%S.%3N'): $(grep -E "(ctxt|intr|processes)" /proc/stat | tr '\n' ' ')"
    sleep $SAMPLE_INTERVAL
done) > system/context_switches.log &
CTX_PID=$!

# ============================================================================
# INTERRUPT MONITORING
# ============================================================================

# 4. Complete interrupt monitoring
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    cat /proc/interrupts
    echo ""
    sleep $SAMPLE_INTERVAL
done) > interrupts/all_interrupts.log &
IRQ_PID=$!

# 5. Specific USB interrupt monitoring with high-frequency sampling
(while true; do
    USB_IRQS=$(cat /proc/interrupts | grep -i -E "(usb|ehci|ohci|xhci|dwc)" | wc -l)
    echo "$(date '+%H:%M:%S.%3N'): $USB_IRQS USB IRQ lines active"
    cat /proc/interrupts | grep -i -E "(usb|ehci|ohci|xhci|dwc)" | while read line; do
        echo "$(date '+%H:%M:%S.%3N'): $line"
    done
    echo "---"
    sleep $SAMPLE_INTERVAL
done) > interrupts/usb_interrupts_detailed.log &
USB_IRQ_PID=$!

# 6. IRQ conflict and rate monitoring
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    cat /proc/interrupts | grep -E "(usb|ohci|ehci|xhci|dwc)" | \
    awk '{print $1, $2, $NF}' | while read irq count desc; do
        echo "IRQ $irq: $count events - $desc"
    done
    echo ""
    sleep $SAMPLE_INTERVAL
done) > interrupts/usb_irq_rates.log &
IRQ_RATE_PID=$!

# 6. Softirq monitoring
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    cat /proc/softirqs
    echo ""
    sleep $SAMPLE_INTERVAL
done) > interrupts/softirqs.log &
SOFT_PID=$!

# ============================================================================
# MEMORY AND DMA MONITORING
# ============================================================================

# 7. Memory info monitoring
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    cat /proc/meminfo
    echo ""
    sleep $SAMPLE_INTERVAL
done) > memory/meminfo.log &
MEM_PID=$!

# 8. DMA monitoring
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    [ -f /proc/dma ] && cat /proc/dma
    echo ""
    sleep $SAMPLE_INTERVAL
done) > memory/dma.log &
DMA_PID=$!

# 9. SLUB allocator info (if available)
(while true; do
    if [ -d /sys/kernel/slab ]; then
        echo "=== $(date '+%H:%M:%S.%3N') ==="
        find /sys/kernel/slab -name "*usb*" -o -name "*kmalloc*" | head -10 | while read slab; do
            if [ -f "$slab/objects" ]; then
                echo "$slab: $(cat $slab/objects 2>/dev/null || echo 'N/A')"
            fi
        done
        echo ""
    fi
    sleep $SAMPLE_INTERVAL
done) > memory/slab.log &
SLAB_PID=$!

# ============================================================================
# PROCESS MONITORING
# ============================================================================

# 10. Process state monitoring (focus on blocked processes)
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    ps aux | awk '$8 ~ /[DZ]/ {print $0}' | head -20
    echo ""
    sleep $SAMPLE_INTERVAL
done) > processes/blocked_processes.log &
PROC_PID=$!

# 11. Kernel thread monitoring
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    ps aux | awk '$1 ~ /\[.*\]/ {print $0}' | grep -E "(usb|irq|ksoftirq|migration)" | head -10
    echo ""
    sleep $SAMPLE_INTERVAL
done) > processes/kernel_threads.log &
KTHREAD_PID=$!

# 12. Scheduler information
(if [ -f /proc/schedstat ]; then
    while true; do
        echo "=== $(date '+%H:%M:%S.%3N') ==="
        cat /proc/schedstat
        echo ""
        sleep $SAMPLE_INTERVAL
    done
fi) > processes/schedstat.log &
SCHED_PID=$!

# ============================================================================
# USB SUBSYSTEM MONITORING
# ============================================================================

# 13. USB device enumeration
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    lsusb 2>/dev/null || echo "lsusb failed"
    echo ""
    sleep $SAMPLE_INTERVAL
done) > usb/lsusb.log &
LSUSB_PID=$!

# 14. USB sysfs monitoring
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    find /sys/bus/usb/devices -name "devnum" 2>/dev/null | wc -l | xargs echo "USB devices:"
    find /sys/bus/usb/devices -maxdepth 1 -type l 2>/dev/null | head -10
    echo ""
    sleep $SAMPLE_INTERVAL
done) > usb/sysfs.log &
SYSFS_PID=$!

# 15. udev event monitoring
udevadm monitor --timestamp --property > usb/udev_events.log &
UDEV_PID=$!

# 15a. usbmon kernel-level USB monitoring
(
    # Load usbmon module if not loaded
    modprobe usbmon 2>/dev/null || echo "usbmon module already loaded or built-in"
    
    # Check if usbmon is available
    if [ -d /sys/kernel/debug/usb/usbmon ]; then
        echo "=== USB Monitor (usbmon) Started ==="
        # Monitor all USB buses (0u = all buses)
        cat /sys/kernel/debug/usb/usbmon/0u 2>/dev/null > usb/usbmon_all_buses.log &
        USBMON_ALL_PID=$!
        
        # Monitor specific USB buses if they exist
        for bus in /sys/kernel/debug/usb/usbmon/[1-9]u; do
            if [ -r "$bus" ]; then
                bus_num=$(basename "$bus" | tr -d 'u')
                echo "Monitoring USB bus $bus_num"
                cat "$bus" > "usb/usbmon_bus${bus_num}.log" &
            fi
        done
    else
        echo "usbmon not available - may need to mount debugfs"
        echo "Try: mount -t debugfs none /sys/kernel/debug"
    fi
) > usb/usbmon_setup.log &

# 16. strace monitoring of udev processes
mkdir -p usb/strace
(
    # Find all udev-related processes
    UDEV_PIDS=$(pgrep -f "udev" || echo "")
    if [ -n "$UDEV_PIDS" ]; then
        echo "Found udev processes: $UDEV_PIDS"
        for pid in $UDEV_PIDS; do
            if [ -d "/proc/$pid" ]; then
                echo "Starting strace for udev PID $pid"
                strace -f -tt -T -e trace=all -o "usb/strace/udev_${pid}.strace" -p "$pid" 2>/dev/null &
            fi
        done
    else
        echo "No udev processes found for strace"
    fi
    
    # Also monitor systemd-udevd if it exists
    SYSTEMD_UDEV_PID=$(pgrep -f "systemd-udevd" || echo "")
    if [ -n "$SYSTEMD_UDEV_PID" ]; then
        echo "Found systemd-udevd PID: $SYSTEMD_UDEV_PID"
        strace -f -tt -T -e trace=all -o "usb/strace/systemd-udevd_${SYSTEMD_UDEV_PID}.strace" -p "$SYSTEMD_UDEV_PID" 2>/dev/null &
    fi
    
    # Monitor for new udev processes that might spawn
    while true; do
        NEW_UDEV_PIDS=$(pgrep -f "udev" | grep -v -F "$UDEV_PIDS" || echo "")
        if [ -n "$NEW_UDEV_PIDS" ]; then
            for new_pid in $NEW_UDEV_PIDS; do
                if [ -d "/proc/$new_pid" ] && [ ! -f "usb/strace/udev_${new_pid}.strace" ]; then
                    echo "Starting strace for new udev PID $new_pid"
                    strace -f -tt -T -e trace=all -o "usb/strace/udev_${new_pid}.strace" -p "$new_pid" 2>/dev/null &
                fi
            done
            UDEV_PIDS="$UDEV_PIDS $NEW_UDEV_PIDS"
        fi
        sleep 1
    done
) > usb/strace/strace_monitor.log 2>&1 &
STRACE_PID=$!

# ============================================================================
# KERNEL SUBSYSTEM MONITORING
# ============================================================================

# 17. Kernel ring buffer (dmesg) monitoring
dmesg -w > kernel/dmesg.log &
DMESG_PID=$!

# 17. Kernel lock statistics (if available)
(if [ -f /proc/lock_stat ]; then
    while true; do
        echo "=== $(date '+%H:%M:%S.%3N') ==="
        cat /proc/lock_stat | head -50
        echo ""
        sleep $SAMPLE_INTERVAL
    done
fi) > kernel/lock_stats.log &
LOCK_PID=$!

# 18. RCU statistics (if available)
(if [ -f /sys/kernel/debug/rcu/rcu_preempt/rcudata ]; then
    while true; do
        echo "=== $(date '+%H:%M:%S.%3N') ==="
        cat /sys/kernel/debug/rcu/*/rcudata 2>/dev/null | head -20
        echo ""
        sleep $SAMPLE_INTERVAL
    done
fi) > kernel/rcu_stats.log &
RCU_PID=$!

# ============================================================================
# I/O MONITORING
# ============================================================================

# 19. I/O statistics
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    cat /proc/diskstats
    echo ""
    sleep $SAMPLE_INTERVAL
done) > io/diskstats.log &
IO_PID=$!

# 20. Block device I/O
(if command -v iostat >/dev/null 2>&1; then
    iostat -x $SAMPLE_INTERVAL > io/iostat.log &
    IOSTAT_PID=$!
fi) &

# ============================================================================
# POWER MANAGEMENT MONITORING
# ============================================================================

# 21. CPU frequency and power states
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        echo "CPU freq: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 'N/A')"
    fi
    if [ -f /sys/power/state ]; then
        echo "Power state: $(cat /sys/power/state 2>/dev/null || echo 'N/A')"
    fi
    # USB power management
    find /sys/bus/usb/devices -name "power" -type d 2>/dev/null | head -5 | while read powerdir; do
        if [ -f "$powerdir/autosuspend_delay_ms" ]; then
            echo "USB autosuspend: $powerdir = $(cat $powerdir/autosuspend_delay_ms 2>/dev/null || echo 'N/A')"
        fi
    done
    echo ""
    sleep $SAMPLE_INTERVAL
done) > power/power_states.log &
POWER_PID=$!

# ============================================================================
# MODULE LOADING MONITORING  
# ============================================================================

# 24. Dynamic debug for module loading
(
    # Enable dynamic debug for module loading
    if [ -f /sys/kernel/debug/dynamic_debug/control ]; then
        echo 'module * +p' > /sys/kernel/debug/dynamic_debug/control 2>/dev/null || echo "Failed to enable module debug"
    fi
    
    # Monitor loaded modules
    while true; do
        echo "=== $(date '+%H:%M:%S.%3N') ==="
        lsmod | grep usb | head -20
        echo ""
        sleep $SAMPLE_INTERVAL
    done
) > modules/module_loading.log &
MODULE_PID=$!

# 25. Module information capture
(
    echo "=== USB Module Information ==="
    lsmod | grep usb | while read module size used deps; do
        echo "--- Module: $module ---"
        modinfo $module 2>/dev/null | grep -E "(filename|description|version|depends)" || echo "No info available"
        echo ""
    done
) > modules/module_info.log &

# ============================================================================
# USERSPACE MONITORING
# ============================================================================

# 26. Systemd/udev service monitoring
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    systemctl list-units | grep -i usb | head -10
    echo "--- udev service status ---"
    systemctl is-active systemd-udevd 2>/dev/null || echo "systemd-udevd not found"
    echo ""
    sleep $SAMPLE_INTERVAL
done) > userspace/systemd_usb.log &
SYSTEMD_PID=$!

# 27. Custom USB configurations monitoring
(
    echo "=== Custom USB Configurations ==="
    echo "--- /etc/udev/rules.d/ USB rules ---"
    grep -r "USB\|usb" /etc/udev/rules.d/ 2>/dev/null || echo "No custom USB rules found"
    echo ""
    echo "--- USB-related environment ---"
    env | grep -i usb || echo "No USB environment variables"
) > userspace/usb_config.log &

# 28. Real-time load monitoring (high frequency)
(while true; do
    echo "$(date '+%H:%M:%S.%3N'): $(cat /proc/loadavg)"
    sleep 0.05  # 50ms intervals for high precision
done) > userspace/realtime_load.log &
REALTIME_LOAD_PID=$!

# 29. USB controller detailed information
(
    echo "=== USB Controller Information ==="
    lspci -v | grep -A10 -i usb
    echo ""
    echo "=== USB Power States ==="
    find /sys -name "*usb*" -name "power" -type d 2>/dev/null | head -10 | while read powerdir; do
        echo "--- $powerdir ---"
        ls -la "$powerdir/" 2>/dev/null | head -5
        for file in autosuspend_delay_ms level control; do
            if [ -f "$powerdir/$file" ]; then
                echo "$file: $(cat $powerdir/$file 2>/dev/null || echo 'N/A')"
            fi
        done
        echo ""
    done
) > userspace/usb_controller_info.log &

# 30. Scheduler and RCU debugging
(
    # Enable scheduler debugging if available
    if [ -f /proc/sys/kernel/sched_debug ]; then
        echo 1 > /proc/sys/kernel/sched_debug 2>/dev/null || echo "Cannot enable sched_debug"
    fi
    
    while true; do
        echo "=== $(date '+%H:%M:%S.%3N') ==="
        # Check for lockups
        dmesg | tail -10 | grep -i -E "(rcu|softlockup|hardlockup|stall)" || echo "No lockup messages"
        echo ""
        sleep $SAMPLE_INTERVAL
    done
) > kernel/lockup_detection.log &
LOCKUP_PID=$!

# 31. Memory pressure and cache coherency
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    cat /proc/meminfo | grep -E "(Dirty|Writeback|Cached|Buffers|MemFree|MemAvailable)"
    echo "--- DMA coherency info ---"
    dmesg | tail -5 | grep -i -E "(dma|coherent)" || echo "No recent DMA messages"
    echo ""
    sleep $SAMPLE_INTERVAL
done) > memory/memory_pressure.log &
MEM_PRESSURE_PID=$!

# ============================================================================
# HARDWARE-SPECIFIC MONITORING
# ============================================================================

# 32. Hardware interrupt controller status
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    # Check for ARM GIC or x86 APIC information
    if [ -d /sys/kernel/debug/irq ]; then
        ls /sys/kernel/debug/irq/ | head -10
    fi
    if [ -f /proc/iomem ]; then
        grep -i -E "(usb|interrupt)" /proc/iomem | head -10
    fi
    echo ""
    sleep $SAMPLE_INTERVAL
done) > system/hardware_irq.log &
HW_IRQ_PID=$!

# 33. PCI subsystem monitoring
(while true; do
    echo "=== $(date '+%H:%M:%S.%3N') ==="
    lspci | grep -i usb
    echo ""
    sleep $SAMPLE_INTERVAL
done) > system/pci_usb.log &
PCI_PID=$!

# Store all PIDs for cleanup
ALL_PIDS="$LOAD_PID $CPU_PID $CTX_PID $IRQ_PID $USB_IRQ_PID $IRQ_RATE_PID $SOFT_PID $MEM_PID $DMA_PID $SLAB_PID $PROC_PID $KTHREAD_PID $SCHED_PID $LSUSB_PID $SYSFS_PID $UDEV_PID $STRACE_PID $DMESG_PID $LOCK_PID $RCU_PID $IO_PID $POWER_PID $HW_IRQ_PID $PCI_PID $MODULE_PID $SYSTEMD_PID $REALTIME_LOAD_PID $LOCKUP_PID $MEM_PRESSURE_PID"

echo "=== All monitors started ==="
echo "Monitor PIDs: $ALL_PIDS"

# Wait for pre-monitor time
echo "=== Collecting baseline data for $PRE_MONITOR_TIME seconds ==="
sleep $PRE_MONITOR_TIME

# Capture system state before USB insertion
echo "=== CAPTURING PRE-INSERTION STATE ==="
date '+%H:%M:%S.%3N' > timestamps/pre_insertion.txt

# Create baseline snapshots
cat /proc/interrupts > snapshots/interrupts_before.txt
cat /proc/meminfo > snapshots/meminfo_before.txt
ps aux > snapshots/processes_before.txt
lsusb > snapshots/lsusb_before.txt 2>/dev/null || echo "lsusb failed" > snapshots/lsusb_before.txt

echo ""
echo "========================================"
echo "    READY FOR USB DEVICE INSERTION"
echo "========================================"
echo ""
echo "Please plug in your USB device NOW"
echo "Press ENTER after the freeze/stall is over"
echo ""

# Wait for user to indicate insertion and freeze completion
read -p "Press ENTER when the freeze is over: " dummy

# Capture the exact moment
date '+%H:%M:%S.%3N' > timestamps/post_freeze.txt

echo "=== CAPTURING POST-FREEZE STATE ==="

# Post-insertion snapshots
cat /proc/interrupts > snapshots/interrupts_after.txt
cat /proc/meminfo > snapshots/meminfo_after.txt  
ps aux > snapshots/processes_after.txt
lsusb > snapshots/lsusb_after.txt 2>/dev/null || echo "lsusb failed" > snapshots/lsusb_after.txt

# Continue monitoring for post-analysis
echo "=== Continuing monitoring for $POST_MONITOR_TIME more seconds ==="
sleep $POST_MONITOR_TIME

# Final cleanup handled by trap
echo "=== Monitoring complete ==="

# Kill usbmon processes
pkill -f "cat /sys/kernel/debug/usb/usbmon" 2>/dev/null || true

# Generate analysis summary
echo "=== GENERATING ANALYSIS SUMMARY ==="

cat > analysis_summary.txt << 'EOF'
USB Freeze Analysis Summary
===========================

This directory contains comprehensive monitoring data for USB insertion freeze analysis.

Directory Structure:
- system/: CPU, load, context switches, hardware IRQ info
- interrupts/: All interrupt data, USB-specific IRQs, softirqs, IRQ rates
- memory/: Memory usage, DMA info, slab allocator data, pressure monitoring
- processes/: Process states, blocked processes, kernel threads
- usb/: USB enumeration, sysfs data, udev events, strace data
  - usb/strace/: strace output for all udev processes
- kernel/: dmesg output, lock stats, RCU data, lockup detection
- io/: I/O statistics and block device info
- power/: Power management and frequency scaling
- modules/: Module loading monitoring, dynamic debug, module info
- userspace/: systemd services, USB configs, real-time load monitoring
- snapshots/: Before/after system state snapshots
- timestamps/: Exact timing of events

Key Files to Analyze:
1. Check snapshots/interrupts_*.txt for IRQ count differences
2. Review usb/udev_events.log for enumeration timeline
3. Examine usb/strace/*.strace for udev system call patterns
4. Look at processes/blocked_processes.log during freeze window
5. Check interrupts/usb_irq_rates.log for IRQ storms or conflicts
6. Review modules/module_loading.log for synchronous module loading delays
7. Examine userspace/realtime_load.log for precise load spikes
8. Check kernel/lockup_detection.log for RCU stalls or softlockups
9. Review memory/memory_pressure.log for DMA coherency issues
10. Look at userspace/usb_controller_info.log for power state issues

Advanced Analysis Commands:
- Compare IRQ rates: diff snapshots/interrupts_before.txt snapshots/interrupts_after.txt
- Find freeze window: grep -A5 -B5 "$(cat timestamps/pre_insertion.txt | cut -d. -f1)" */*.log
- Check for module loading delays during freeze
- Look for blocked system calls in strace output during freeze window
- Analyze USB power state transitions

Analysis Commands:
- diff snapshots/interrupts_before.txt snapshots/interrupts_after.txt
- grep -A5 -B5 "$(cat timestamps/pre_insertion.txt | cut -d. -f1)" */*.log
- Look for patterns around insertion timestamp in all logs

EOF

echo "Analysis complete!"
echo "Data saved in: $MONITOR_DIR"
echo "Review analysis_summary.txt for guidance on analyzing the data"
echo ""
echo "Key next steps:"
echo "1. Check interrupt count differences in snapshots/"
echo "2. Look for blocked processes during freeze window"  
echo "3. Examine USB enumeration timeline in usb/udev_events.log"
echo "4. Review kernel messages in kernel/dmesg.log"