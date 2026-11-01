#!/usr/bin/env bash
# Read-only. Run as the game-server account; no sudo, installs or settings changes.
# Usage: bash collect-linux-performance.sh SERVER_PID [duration_seconds] [interval_seconds]
# Redirect stdout to a report. No environment, command arguments, SQL or payloads.
set -u
pid=${1:-}; duration=${2:-60}; interval=${3:-2}
if [[ ! $pid =~ ^[1-9][0-9]*$ || ! -d /proc/$pid ]]; then
 printf 'Usage: %s SERVER_PID [10..300 seconds] [1..30 interval]\n' "$0" >&2; exit 2
fi
if [[ ! $duration =~ ^[0-9]+$ || ! $interval =~ ^[0-9]+$ ]] ||
 (( duration < 10 || duration > 300 || interval < 1 || interval > 30 )); then
 printf 'Invalid sampling range.\n' >&2; exit 2
fi
read_stat() { if [[ -r $1 ]]; then printf '\n--- %s ---\n' "$1"; cat -- "$1"; fi; }
process_start() { local line; IFS= read -r line < "/proc/$pid/stat" || return; printf '%s\n' "${line##*) }" | awk '{print $20}'; }
original_start=$(process_start)
printf 'Linux game-server observation; UTC timestamps; pid=%s duration=%ss interval=%ss\n' "$pid" "$duration" "$interval"
printf 'Read-only /proc snapshots. Sampling itself has overhead. Counters are cumulative; compare deltas. Network/disk/CPU figures can include other workloads. No FPS, GPU or remote latency measurement.\n'
uname -srm
getconf CLK_TCK
getconf _NPROCESSORS_ONLN
read_stat "/proc/$pid/limits"
# Only resource-control files from the selected process' cgroup, never its env.
cgroup=$(awk -F: '$1=="0" {print $3;exit}' "/proc/$pid/cgroup" 2>/dev/null || true)
if [[ -n $cgroup && $cgroup != *..* && -d /sys/fs/cgroup$cgroup ]]; then
 for name in cpu.max cpu.stat cpu.pressure memory.max memory.current memory.events io.max io.stat cpuset.cpus.effective; do
  read_stat "/sys/fs/cgroup$cgroup/$name"
 done
fi
start=$SECONDS
while (( SECONDS-start <= duration )); do
 if [[ ! -d /proc/$pid ]]; then printf '\nSelected process exited; sampling stopped.\n'; break; fi
 if [[ $(process_start) != "$original_start" ]]; then printf '\nPID was reused; sampling stopped.\n'; break; fi
 printf '\n=== sample UTC %s elapsed=%ss ===\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$((SECONDS-start))"
 ps -L -p "$pid" -o pid,tid,psr,pcpu,stat,wchan:24,comm
 read_stat "/proc/$pid/stat"
 read_stat "/proc/$pid/schedstat"
 read_stat "/proc/$pid/io"
 for item in /proc/pressure/cpu /proc/pressure/io /proc/pressure/memory /proc/loadavg /proc/stat /proc/diskstats "/proc/$pid/net/snmp" "/proc/$pid/net/netstat"; do read_stat "$item"; done
 awk '/^(VmRSS|VmSize|VmSwap|Threads|voluntary_ctxt_switches|nonvoluntary_ctxt_switches|Cpus_allowed_list):/ {print}' "/proc/$pid/status"
 awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree|Dirty|Writeback):/ {print}' /proc/meminfo
 for item in "/proc/$pid"/task/*/schedstat; do read_stat "$item"; done
 if [[ -n $cgroup && $cgroup != *..* ]]; then
  for name in cpu.stat cpu.pressure memory.current memory.events io.stat; do read_stat "/sys/fs/cgroup$cgroup/$name"; done
 fi
 (( SECONDS-start+interval > duration )) && break
 sleep "$interval"
done
