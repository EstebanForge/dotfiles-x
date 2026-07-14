#!/usr/bin/env bash

# Re-exec under Bash when invoked from another shell (e.g. zsh luks_tpm_enroll.sh).
source "$(dirname "$0")/lib/bash_compat.sh"

# LUKS2 -> TPM2 enrollment script for automatic unlock at boot.
#
# Seals a LUKS2 key into the machine's TPM2 chip via `systemd-cryptenroll`,
# then wires /etc/crypttab and rebuilds the initramfs so the volume unlocks
# without a passphrase on subsequent boots. The original passphrase slot is
# ALWAYS preserved as a recovery path.
#
# IMPORTANT: this key is sealed into the TPM2 chip, NOT into UEFI/BIOS.
# UEFI (and Secure Boot, if enabled) only provides PCR measurements that the
# TPM uses to decide whether to unseal the key. With Secure Boot disabled,
# PCR7 carries little meaning: auto-unlock works, but tamper protection is weak.
#
# High-blast-radius operations (header write, crypttab edit, initramfs rebuild)
# are gated behind explicit confirmation. A LUKS header backup is taken before
# any write, so the header can be restored if enrollment corrupts it.
#
# Usage:
#   ./scripts/luks_tpm_enroll.sh                 # status (read-only, default)
#   ./scripts/luks_tpm_enroll.sh status          # show device + enrollment state
#   ./scripts/luks_tpm_enroll.sh enroll          # enroll TPM2 (prompts to confirm)
#   ./scripts/luks_tpm_enroll.sh remove          # remove the TPM2 slot (prompts)
#   ./scripts/luks_tpm_enroll.sh enroll --yes    # skip confirmation prompt
#   sudo TPM2_PCRS="0+7" ./scripts/luks_tpm_enroll.sh enroll --yes
#
# Env vars:
#   TPM2_PCRS    PCR list for sealing (default: "7" = Secure Boot state).
#                Add e.g. "0+7+14" for firmware + secure-boot + shim/MOK.
#                More PCRs = stronger tamper detection, but breaks unlock
#                when those measurements change (firmware/kernel updates).
#   LUKS_DEVICE  Force a specific backing device (e.g. /dev/nvme0n1p3).
#                Auto-detected otherwise; required if >1 LUKS volume exists.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"

# --- Config -----------------------------------------------------------------

PCR_LIST="${TPM2_PCRS:-7}"
CONFIRM_YES=0
FORCE_DEVICE="${LUKES_DEVICE:-}"

# --- Helpers ----------------------------------------------------------------

die() { echo "ERROR: $*" >&2; exit 1; }

info() { echo ":: $*"; }
warn() { echo "WARN: $*" >&2; }

confirm() {
    # Prompt y/N before destructive steps. Bypassed by --yes.
    if [[ "$CONFIRM_YES" -eq 1 ]]; then
        return 0
    fi
    local reply
    read -r -p "$* [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "Must run as root (use sudo). TPM enrollment writes the LUKS header, /etc/crypttab, and the initramfs."
    fi
}

preflight() {
    info "Preflight checks..."
    local distro
    distro="$(detect_distro)"
    if [[ "$distro" == "macos" ]]; then
        die "macOS has no LUKS/TPM2 unlock. Linux only."
    fi

    command -v systemd-cryptenroll >/dev/null 2>&1 || die "systemd-cryptenroll not found. Install systemd (>=248)."
    command -v cryptsetup         >/dev/null 2>&1 || die "cryptsetup not found."
    command -v tpm2               >/dev/null 2>&1 || die "tpm2 command not found. Install tpm2-tools."

    # TPM2 chip present and managed by the kernel driver.
    [[ -e /sys/class/tpm/tpm0 ]] || die "No TPM2 device at /sys/class/tpm/tpm0. Is TPM enabled in UEFI?"

    local tpm_major
    tpm_major="$(cat /sys/class/tpm/tpm0/tpm_version_major 2>/dev/null || echo "?")"
    [[ "$tpm_major" == "2" ]] || die "Expected TPM2, found version ${tpm_major}. TPM2 required."

    # systemd-cryptenroll needs a LUKS2 header; LUKS1 is unsupported.
    local ver
    ver="$(cryptsetup luksDump "${1:-}" 2>/dev/null | awk '/^Version:/{print $2; exit}' || true)"
    [[ "$ver" == "2" ]] || die "LUKS2 required (found version '${ver:-unknown}'${1:+ for $1}). systemd-cryptenroll does not support LUKS1."

    echo "  TPM2:          present (v${tpm_major})"
    echo "  systemd:       $(systemctl --version | head -1)"
    echo "  cryptsetup:    $(cryptsetup --version)"
    command -v sbctl >/dev/null 2>&1 && echo "  sbctl:         available (use it to enable Secure Boot later)"
    echo "  PCRs to seal:  ${PCR_LIST}"
    echo
}

# Find the backing partition for a LUKS volume. Auto-detected from the active
# /dev/mapper/luks-* symlinks (root-free); falls back to scanning partitions with
# cryptsetup isLuks when root. LUKS_DEVICE forces a specific node. Dies if zero
# or >1 LUKS device and none forced.
detect_luks_device() {
    if [[ -n "$FORCE_DEVICE" ]]; then
        [[ -b "$FORCE_DEVICE" ]] || die "LUKS_DEVICE='$FORCE_DEVICE' is not a block device."
        echo "$FORCE_DEVICE"
        return 0
    fi
    local found="" mapper back
    # Preferred path: each active mapper node resolves to its backing partition.
    # lsblk's FSTYPE column is unreliable without root in flat (-l) mode, so we
    # walk the inverse tree (-s) and pick the parent of type 'part'. -r drops
    # the tree glyphs (└─) so NAME is a clean path.
    if compgen -G "/dev/mapper/luks-*" >/dev/null 2>&1; then
        while IFS= read -r mapper; do
            [[ -b "$mapper" ]] || continue
            back="$(lsblk -nrspo NAME,TYPE "$mapper" 2>/dev/null | awk '$2=="part"{print $1; exit}')"
            [[ -n "$back" ]] && found="${found:+$found\n}${back}"
        done < <(printf '%s\n' /dev/mapper/luks-*)
    fi
    # Fallback: header scan (needs root). Catches volumes not currently open.
    if [[ -z "$found" && "${EUID}" -eq 0 ]]; then
        local dev
        while IFS= read -r dev; do
            cryptsetup isLuks "$dev" 2>/dev/null && found="${found:+$found\n}${dev}"
        done < <(lsblk -nrpo NAME,TYPE 2>/dev/null | awk '$2=="part"{print $1}')
    fi
    [[ -z "$found" ]] && die "No LUKS volume detected. Set LUKS_DEVICE=/dev/xxx explicitly."
    local count
    count="$(printf '%s' "$found" | wc -l)"
    if [[ "$count" -gt 1 ]]; then
        die "Multiple LUKS volumes found:\n$(printf '%s' "$found")\nSet LUKS_DEVICE=/dev/xxx to choose one."
    fi
    printf '%s' "$found"
}

# Resolve mapper name (e.g. luks-<uuid>) for an active volume; empty if not open.
mapper_name_for() {
    local dev="$1" uuid
    uuid="$(cryptsetup luksUUID "$dev" 2>/dev/null || true)"
    [[ -n "$uuid" ]] || return 0
    if [[ -e "/dev/mapper/luks-${uuid}" ]]; then
        echo "luks-${uuid}"
    fi
}

luks_uuid_for() { cryptsetup luksUUID "$1" 2>/dev/null; }

# Returns 0 if a TPM2 token is already enrolled in the LUKS2 header.
has_tpm_token() {
    local dev="$1"
    cryptsetup luksDump "$dev" 2>/dev/null | grep -qE '^\s*Tokens:|tpm2' \
        && systemd-cryptenroll "$dev" 2>/dev/null | grep -qi tpm2
}

# Backup the LUKS2 header before any write. Idempotent-ish: always a fresh file.
backup_luks_header() {
    local dev="$1" uuid backup_dir
    uuid="$(luks_uuid_for "$dev")"
    backup_dir="/root/luks-backups"
    mkdir -p "$backup_dir"
    local ts file
    ts="$(date +%Y%m%d_%H%M%S)"
    file="${backup_dir}/luks-header-${uuid}-${ts}.img"
    info "Backing up LUKS header -> ${file}"
    cryptsetup luksHeaderBackup "$dev" --header-backup-file "$file"
    chmod 600 "$file"
    echo "  (Restore with: cryptsetup luksHeaderRestore $dev --header-backup-file $file)"
}

# Ensure /etc/crypttab has an entry for this volume using tpm2-device=auto.
# Creates the file if missing; replaces the matching line if options differ;
# leaves unrelated lines untouched.
ensure_crypttab_entry() {
    local dev="$1"
    local uuid mapper line
    uuid="$(luks_uuid_for "$dev")"
    mapper="$(mapper_name_for "$dev")"
    [[ -n "$mapper" ]] || mapper="luks-${uuid}"
    # key-file=none: systemd tries TPM2 token first, then falls back to passphrase.
    line="${mapper} UUID=${uuid} none tpm2-device=auto"

    local f="/etc/crypttab"
    if [[ ! -f "$f" ]]; then
        info "Creating ${f}"
        printf '%s\n' "$line" > "$f"
        return 0
    fi
    if grep -qE "^[[:space:]]*${mapper}[[:space:]]" "$f"; then
        if grep -qF "tpm2-device=auto" "$f"; then
            info "crypttab already has TPM2 entry for ${mapper}; leaving as-is."
            return 0
        fi
        info "Updating existing crypttab entry for ${mapper} to add tpm2-device=auto"
        cp -a "$f" "${f}.bak.$(date +%s)"
        awk -v mapper="$mapper" -v line="$line" '
            $1==mapper {print line; next}
            {print}
        ' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
    else
        info "Appending TPM2 entry to ${f} for ${mapper}"
        cp -a "$f" "${f}.bak.$(date +%s)"
        printf '%s\n' "$line" >> "$f"
    fi
}

# Remove tpm2-device option (or whole line if it was ours) from /etc/crypttab.
strip_tpm_from_crypttab() {
    local dev="$1" f="/etc/crypttab"
    [[ -f "$f" ]] || return 0
    local mapper
    mapper="$(mapper_name_for "$dev")"
    [[ -n "$mapper" ]] || return 0
    grep -qE "^[[:space:]]*${mapper}[[:space:]]" "$f" || return 0
    info "Stripping tpm2-device from crypttab entry for ${mapper}"
    cp -a "$f" "${f}.bak.$(date +%s)"
    # Drop only the option, keep the line so passphrase prompt still works.
    sed -i -E "s/[[:space:]]+tpm2-device=auto//g" "$f"
}

# Rebuild initramfs so the crypttab change is baked in. Distros differ.
rebuild_initramfs() {
    local distro
    distro="$(detect_distro)"
    info "Rebuilding initramfs (${distro})..."
    case "$distro" in
        rpm)
            # dracut reads /etc/crypttab at build time and embeds the unlock unit.
            command -v dracut >/dev/null 2>&1 || die "dracut not found."
            dracut --force
            ;;
        deb)
            command -v update-initramfs >/dev/null 2>&1 || die "update-initramfs not found."
            update-initramfs -u -k all
            ;;
        *)
            warn "Unknown distro; skipping initramfs rebuild. Rebuild it manually."
            ;;
    esac
}

# --- Subcommands ------------------------------------------------------------

cmd_status() {
    # Read-only: safe to run without root for inspection, but luksDump needs root.
    if [[ "${EUID}" -ne 0 ]]; then
        warn "Not root; some fields (LUKS header) require root. Re-run with sudo for full status."
    fi
    echo "=== LUKS TPM2 enrollment status ==="
    local dev
    dev="$(detect_luks_device 2>/dev/null || true)"
    if [[ -z "$dev" ]]; then
        echo "No LUKS device detected."
        return 0
    fi
    echo "Device:   ${dev}"
    local uuid mapper
    uuid="$(luks_uuid_for "$dev" 2>/dev/null || echo '?')"
    mapper="$(mapper_name_for "$dev" 2>/dev/null || true)"
    echo "UUID:     ${uuid}"
    [[ -n "$mapper" ]] && echo "Mapper:   /dev/mapper/${mapper}"

    if [[ "${EUID}" -eq 0 ]]; then
        echo
        if cryptsetup luksDump "$dev" 2>/dev/null | grep -qi 'Version.*2'; then
            echo "LUKS:     v2 (supported)"
        else
            echo "LUKS:     NOT v2 (unsupported by systemd-cryptenroll)"
        fi
        if systemd-cryptenroll "$dev" 2>/dev/null | grep -qi tpm2; then
            echo "TPM2:     ENROLLED (slot present)"
        else
            echo "TPM2:     not enrolled"
        fi
    fi

    echo
    local sb
    sb="$(bootctl status 2>/dev/null | awk '/Secure Boot:/{print $3,$4; exit}' || true)"
    echo "Secure Boot: ${sb:-unknown}"
    echo
    if [[ "${sb}" == disabled* ]]; then
        warn "Secure Boot is DISABLED. TPM auto-unlock works but PCR7 is nearly empty,"
        warn "so tamper protection is weak. Consider enabling Secure Boot (sbctl) then"
        warn "re-running 'enroll' so the key is sealed against real measurements."
    fi
}

cmd_enroll() {
    require_root
    local dev
    dev="$(detect_luks_device)"
    preflight "$dev"

    if has_tpm_token "$dev"; then
        info "TPM2 token already enrolled on ${dev}."
        confirm "Re-enroll (wipe and recreate the TPM2 slot)?" || { info "Aborting."; exit 0; }
    else
        echo
        echo "About to enroll TPM2 on ${dev} (sealed to PCRs: ${PCR_LIST})."
        echo "Your existing passphrase slot is preserved as recovery."
        confirm "Proceed?" || { info "Aborting."; exit 0; }
    fi

    backup_luks_header "$dev"

    info "Enrolling TPM2 token via systemd-cryptenroll..."
    # --wipe-slot=tpm2 makes this idempotent: replaces any prior TPM2 slot.
    systemd-cryptenroll \
        --wipe-slot=tpm2 \
        --tpm2-device=auto \
        --tpm2-pcrs="${PCR_LIST}" \
        "$dev"

    ensure_crypttab_entry "$dev"
    rebuild_initramfs

    echo
    info "Done. Reboot to verify passwordless unlock."
    echo "Recovery: your passphrase still works (fallback prompt)."
    echo "If unlock fails after a firmware/kernel change, re-run: sudo $0 enroll --yes"
}

cmd_remove() {
    require_root
    local dev
    dev="$(detect_luks_device)"
    preflight "$dev"
    if ! has_tpm_token "$dev"; then
        info "No TPM2 token enrolled on ${dev}. Nothing to remove."
        exit 0
    fi
    echo "About to WIPE the TPM2 slot on ${dev}."
    echo "Passphrase unlock remains intact."
    confirm "Proceed?" || { info "Aborting."; exit 0; }

    backup_luks_header "$dev"
    info "Wiping TPM2 slot..."
    systemd-cryptenroll --wipe-slot=tpm2 "$dev"
    strip_tpm_from_crypttab "$dev"
    rebuild_initramfs
    echo
    info "TPM2 enrollment removed. Boot will prompt for passphrase again."
}

usage() {
    cat <<'EOF'
LUKS2 -> TPM2 enrollment for passwordless boot unlock.

Usage:
  luks_tpm_enroll.sh                 # status (read-only, default)
  luks_tpm_enroll.sh status          # show device + enrollment state
  luks_tpm_enroll.sh enroll          # enroll TPM2 (prompts to confirm)
  luks_tpm_enroll.sh remove          # remove the TPM2 slot (prompts)
  luks_tpm_enroll.sh enroll --yes    # skip confirmation prompt
  sudo TPM2_PCRS="0+7+14" luks_tpm_enroll.sh enroll --yes

Options:
  --yes, -y        Skip confirmation prompts
  --device DEV     Force a specific backing device (else auto-detect)
  --pcrs LIST      PCR list to seal against (default: 7). Env: TPM2_PCRS
  --help, -h       Show this help

The original passphrase slot is ALWAYS preserved as recovery.
EOF
}

# --- Arg parsing ------------------------------------------------------------

SUBCMD="${1:-status}"
shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) CONFIRM_YES=1 ;;
        --device) FORCE_DEVICE="$2"; shift ;;
        --pcrs)   PCR_LIST="$2"; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

case "$SUBCMD" in
    status)  cmd_status ;;
    enroll)  cmd_enroll ;;
    remove)  cmd_remove ;;
    help|-h|--help) usage ;;
    *) die "Unknown command '$SUBCMD'. Try: status | enroll | remove" ;;
esac
