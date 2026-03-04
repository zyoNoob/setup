# Ubuntu Server Compatibility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `setup.sh` and its dotfiles work on both Ubuntu Desktop and Ubuntu Server (headless) using guard-first architecture.

**Architecture:** Add `is_server()` detection function (systemd default target), wrap desktop-only blocks with `! is_server` guards (same pattern as existing `is_wsl()`), split dotfiles into `dotfiles-common/` + `dotfiles-desktop/` stow packages, add server-specific NVIDIA path using `nvidia-smi`.

**Tech Stack:** Bash, GNU Stow, systemd, nvidia-smi

**Design Doc:** `docs/plans/2026-03-04-ubuntu-server-compatibility-design.md`

---

### Task 1: Add `is_server()` and update NVIDIA detection helpers

**Files:**
- Modify: `setup.sh:114-134` (after `is_wsl()`, before `is_installed()`)

**Step 1: Add `is_server()` function after `is_wsl()` (after line 120)**

Insert after the closing `}` of `is_wsl()` at line 120:

```bash
is_server() {
    local default_target
    default_target=$(systemctl get-default 2>/dev/null || echo "unknown")
    case "$default_target" in
        multi-user.target | rescue.target ) return 0 ;;
        * ) return 1 ;;
    esac
}
```

**Step 2: Update `has_nvidia_driver()` and add `has_nvidia_gui()`**

Current `has_nvidia_driver()` at line 132-134:
```bash
has_nvidia_driver() {
    command -v nvidia-settings &> /dev/null
}
```

Replace with:
```bash
has_nvidia_driver() {
    command -v nvidia-settings &> /dev/null || command -v nvidia-smi &> /dev/null
}

has_nvidia_gui() {
    command -v nvidia-settings &> /dev/null
}
```

**Step 3: Commit**

```bash
git add setup.sh
git commit -m "feat: add is_server() detection and split NVIDIA helpers

Add systemd-based server detection (multi-user.target).
Split has_nvidia_driver() to also check nvidia-smi for headless
servers, add has_nvidia_gui() for desktop-specific paths."
```

---

### Task 2: Gate `initial_system_setup()` Firefox block

**Files:**
- Modify: `setup.sh:222` (the Firefox reinstall block)

**Step 1: Add `is_server` guard to Firefox block**

Current line 222:
```bash
    if ! is_wsl; then
```

Replace with:
```bash
    if ! is_wsl && ! is_server; then
```

The `else` clause at line 278-280 stays as-is since it handles the WSL skip message. Add a server-specific skip before it. The structure becomes:

```bash
    if ! is_wsl && ! is_server; then
        # ... existing Firefox snap removal + Mozilla repo code (lines 223-277) ...
    elif is_server; then
        print_status "firefox reinstallation" "skip (server)"
    else
        print_status "firefox reinstallation" "skip (WSL detected)"
    fi
```

**Step 2: Commit**

```bash
git add setup.sh
git commit -m "feat: skip Firefox reinstall on server"
```

---

### Task 3: Split `install_essential_packages()` package arrays

**Files:**
- Modify: `setup.sh:325-382` (packages_core array and install loop)

**Step 1: Remove desktop-only packages from `packages_core`**

Remove these from the `packages_core` array (lines 350-376):
- `maim` (line 350)
- `xclip` (line 351)
- `xdotool` (line 352)
- `transmission` (line 354)
- `policykit-1-gnome` (line 355)
- `network-manager-gnome` (line 356)
- `i3` (line 362)
- `i3blocks` (line 363)
- `pavucontrol` (line 364)
- `pulsemixer` (line 365)
- `feh` (line 366)
- `dunst` (line 367)
- `rofi` (line 368)
- `picom` (line 369)
- `polybar` (line 370)
- `wireplumber` (line 375)
- `libfuse2` (line 376)

Also remove `flatpak` (line 341) from `packages_core` since the entire flatpak section is desktop-only.

**Step 2: Add `packages_desktop` array and conditional install**

After the `packages_core` install loop (after the `done` at line 382), add:

```bash
    # Desktop-only packages
    if ! is_server; then
        local packages_desktop=(
            flatpak
            maim
            xclip
            xdotool
            transmission
            policykit-1-gnome
            network-manager-gnome
            i3
            i3blocks
            pavucontrol
            pulsemixer
            feh
            dunst
            rofi
            picom
            polybar
            wireplumber
            libfuse2
        )
        for pkg in "${packages_desktop[@]}"; do
            install_package "$pkg"
        done
    else
        print_status "desktop packages (18 packages)" "skip (server)"
    fi
```

**Step 3: Commit**

```bash
git add setup.sh
git commit -m "feat: split essential packages into core and desktop arrays

Desktop-only packages (i3, rofi, picom, polybar, etc.) are now
gated by is_server() and skipped on headless installs."
```

---

### Task 4: Gate brightnessctl and flatpak sections

**Files:**
- Modify: `setup.sh:396-476` (brightnessctl + flatpak + flatpak apps)

**Step 1: Gate brightnessctl (lines 396-403)**

Wrap the existing brightnessctl block:

```bash
    # Install brightnessctl (desktop only)
    if ! is_server; then
        if [ ! -x "$(command -v brightnessctl)" ]; then
            install_package "brightnessctl"
            run_silent sudo chmod +s /usr/bin/brightnessctl
            print_status "install brightnessctl"
        else
            print_status "install brightnessctl" skip
        fi
    else
        print_status "install brightnessctl" "skip (server)"
    fi
```

**Step 2: Gate flatpak section (lines 423-476)**

Wrap the entire flatpak configuration + app installations:

```bash
    # Configure flatpak and install desktop apps (desktop only)
    if ! is_server; then
        # Configure flatpak
        if ! flatpak remotes | grep -q flathub; then
            # ... existing flatpak config code ...
        fi

        # Install Flatseal ...
        # Install Discord ...
        # Install Bolt ...
        # Install Vibrant Linux ...
    else
        print_status "flatpak and desktop apps" "skip (server)"
    fi
```

**Step 3: Commit**

```bash
git add setup.sh
git commit -m "feat: gate brightnessctl and flatpak apps for server"
```

---

### Task 5: Gate `setup_desktop_environment()` for server

**Files:**
- Modify: `setup.sh:483-709`

**Step 1: Add server early-return at top of function**

After the log header (line 486), before the `if ! is_wsl` check (line 489), add:

```bash
    if is_server; then
        print_status "desktop environment setup" "skip (server)"
        return
    fi
```

This causes the entire function to be skipped on server, including NVIDIA coolbits/overclock calls at lines 682-683.

**Step 2: Commit**

```bash
git add setup.sh
git commit -m "feat: skip entire desktop environment setup on server"
```

---

### Task 6: Add server NVIDIA guard to coolbits/overclock + create `setup_nvidia_server()`

**Files:**
- Modify: `setup.sh:715-832` (coolbits + overclock functions)
- Add new function after line 832

**Step 1: Add `is_server` guard to `setup_nvidia_coolbits()` (after line 723)**

Current lines 720-723:
```bash
    if is_wsl; then
        print_status "nvidia coolbits" "skip (WSL detected)"
        return
    fi
```

Add after that block (before line 725):
```bash
    if is_server; then
        print_status "nvidia coolbits" "skip (server)"
        return
    fi
```

**Step 2: Add `is_server` guard to `setup_nvidia_overclock()` (after line 767)**

Same pattern — add after the WSL guard:
```bash
    if is_server; then
        print_status "nvidia overclock" "skip (server)"
        return
    fi
```

**Step 3: Update both functions to use `has_nvidia_gui()` instead of `has_nvidia_driver()`**

In `setup_nvidia_coolbits()` line 726:
```bash
    # Before:
    if ! has_nvidia_driver; then
    # After:
    if ! has_nvidia_gui; then
```

In `setup_nvidia_overclock()` line 770:
```bash
    # Before:
    if ! has_nvidia_driver; then
    # After:
    if ! has_nvidia_gui; then
```

**Step 4: Create `setup_nvidia_server()` function after `setup_nvidia_overclock()` (after line 832)**

```bash
# ========================================
# NVIDIA Server Configuration
# ========================================

setup_nvidia_server() {
    log_to_both "--------------------------------"
    log_to_both "# NVIDIA Server Configuration"
    log_to_both "--------------------------------"

    if is_wsl; then
        print_status "nvidia server setup" "skip (WSL detected)"
        return
    fi

    if ! is_server; then
        print_status "nvidia server setup" "skip (not a server)"
        return
    fi

    # Check if nvidia driver is installed (via nvidia-smi on servers)
    if ! command -v nvidia-smi &> /dev/null; then
        print_status "nvidia server setup" "skip (no nvidia driver detected)"
        return
    fi

    # Enable persistence mode
    run_silent sudo nvidia-smi -pm 1
    print_status "enable nvidia persistence mode"

    # Create sudoers rule for passwordless nvidia-smi
    local SUDOERS_FILE="/etc/sudoers.d/nvidia-oc"
    local CURRENT_USER
    CURRENT_USER=$(logname 2>/dev/null || echo "$SUDO_USER" || echo "$USER")
    local SUDOERS_RULE="$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/nvidia-smi"

    if [ ! -f "$SUDOERS_FILE" ] || ! grep -qF "$SUDOERS_RULE" "$SUDOERS_FILE"; then
        echo "$SUDOERS_RULE" | sudo tee "$SUDOERS_FILE" > /dev/null
        sudo chmod 0440 "$SUDOERS_FILE"
        if sudo visudo -c -f "$SUDOERS_FILE" &> /dev/null; then
            print_status "create nvidia-smi sudoers rule"
        else
            sudo rm -f "$SUDOERS_FILE"
            print_status "create nvidia-smi sudoers rule (INVALID - removed)"
            return
        fi
    else
        print_status "create nvidia-smi sudoers rule" skip
    fi

    # Create the server overclock script (always overwrite to ensure latest values)
    local OC_SCRIPT="/usr/local/bin/nvidia-oc-server.sh"
    sudo tee "$OC_SCRIPT" > /dev/null <<'OCSCRIPT'
#!/bin/bash

logger -t nvidia-oc "Applying server GPU configuration"

# Enable persistence mode
if ! nvidia-smi -pm 1 &> /dev/null; then
    logger -t nvidia-oc "ERROR: Failed to enable persistence mode"
    exit 1
fi

# Lock GPU clocks (adjust min,max values as needed)
# nvidia-smi --lock-gpu-clocks=<min>,<max>
# nvidia-smi --lock-memory-clocks=<freq>

# Set power limit (in watts, adjust as needed)
# nvidia-smi -pl <watts>

logger -t nvidia-oc "Server GPU configuration applied"
nvidia-smi --query-gpu=name,clocks.current.graphics,clocks.current.memory,power.draw --format=csv,noheader 2>/dev/null | \
    while IFS= read -r line; do logger -t nvidia-oc "GPU status: $line"; done
OCSCRIPT
    run_silent sudo chmod +x "$OC_SCRIPT"
    print_status "create nvidia server overclock script"

    # Create systemd oneshot service
    local SERVICE_FILE="/etc/systemd/system/nvidia-oc.service"
    if [ ! -f "$SERVICE_FILE" ]; then
        sudo tee "$SERVICE_FILE" > /dev/null <<EOL
[Unit]
Description=NVIDIA GPU Server Configuration
After=nvidia-persistenced.service
Wants=nvidia-persistenced.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nvidia-oc-server.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL
        run_silent sudo systemctl daemon-reload
        run_silent sudo systemctl enable nvidia-oc.service
        print_status "create nvidia server overclock service"
    else
        print_status "create nvidia server overclock service" skip
    fi
}
```

**Step 5: Commit**

```bash
git add setup.sh
git commit -m "feat: add server NVIDIA setup with nvidia-smi systemd service

Desktop NVIDIA functions now skip on server. New setup_nvidia_server()
uses nvidia-smi for persistence mode and GPU config via systemd oneshot."
```

---

### Task 7: Gate desktop items in `setup_development_tools()`

**Files:**
- Modify: `setup.sh:843-861` (VS Code), `setup.sh:1029-1044` (uv tools), `setup.sh:1190-1210` (GStreamer), `setup.sh:1231-1242` (VM tools)

**Step 1: Gate VS Code with `is_server` (line 844)**

Current:
```bash
    if ! is_wsl; then
```

Replace:
```bash
    if ! is_wsl && ! is_server; then
```

Update the else at line 859-861:
```bash
    else
        if is_server; then
            print_status "install code" "skip (server)"
        else
            print_status "install code" "skip (WSL detected)"
        fi
    fi
```

**Step 2: Gate `netron` in uv tools (lines 1029-1044)**

Split the uv_tools array. Replace the entire block:

```bash
    # UV tool installs
    local uv_tools=(
        "smassh"
        "gdown"
        "huggingface_hub[cli]"
    )

    # Desktop-only UV tools
    if ! is_server; then
        uv_tools+=("netron")
    else
        print_status "uv install netron" "skip (server)"
    fi

    for tool in "${uv_tools[@]}"; do
        if ! $HOME/.local/bin/uv tool list | grep -q "^${tool%%\[*}"; then
            run_silent $HOME/.local/bin/uv tool install "$tool"
            print_status "uv install $tool"
        else
            print_status "uv install $tool" skip
        fi
    done
```

**Step 3: Split GStreamer packages (lines 1190-1210)**

Replace the single `gstreamer_packages` array with core + desktop:

```bash
    # Install GStreamer packages
    local gstreamer_packages=(
        libgstreamer1.0-dev
        libgstreamer-plugins-base1.0-dev
        libgstreamer-plugins-bad1.0-dev
        gstreamer1.0-plugins-base
        gstreamer1.0-plugins-good
        gstreamer1.0-plugins-bad
        gstreamer1.0-plugins-ugly
        gstreamer1.0-libav
        gstreamer1.0-tools
        gstreamer1.0-alsa
        gstreamer1.0-gl
        gstreamer1.0-pulseaudio
    )
    for pkg in "${gstreamer_packages[@]}"; do
        install_package "$pkg"
    done

    # GStreamer GUI packages (desktop only)
    if ! is_server; then
        local gstreamer_desktop_packages=(
            gstreamer1.0-x
            gstreamer1.0-gtk3
            gstreamer1.0-qt5
        )
        for pkg in "${gstreamer_desktop_packages[@]}"; do
            install_package "$pkg"
        done
    else
        print_status "gstreamer desktop packages" "skip (server)"
    fi
```

**Step 4: Gate `virt-manager` in VM packages (lines 1231-1242)**

Split the array:

```bash
    # Install VM tools
    local vm_packages=(
        libvirt-daemon-system
        libvirt-clients
        qemu-kvm
        qemu-utils
        ovmf
    )
    for pkg in "${vm_packages[@]}"; do
        install_package "$pkg"
    done

    # virt-manager GUI (desktop only, servers use virsh)
    if ! is_server; then
        install_package "virt-manager"
    else
        print_status "install virt-manager" "skip (server)"
    fi

    run_silent sudo systemctl enable --now libvirtd
```

**Step 5: Commit**

```bash
git add setup.sh
git commit -m "feat: gate desktop dev tools (VS Code, netron, virt-manager, GStreamer GUI)"
```

---

### Task 8: Gate desktop items in `setup_shell_environment()`

**Files:**
- Modify: `setup.sh:1267-1292` (Ghostty), `setup.sh:1294-1310` (Kitty), `setup.sh:1366-1368` (gvfs)

**Step 1: Gate Ghostty with `is_server` (line 1268)**

Current:
```bash
    if is_wsl; then
```

Replace:
```bash
    if is_wsl || is_server; then
```

Update message at line 1269:
```bash
        print_status "install ghostty" "skip (WSL/server detected)"
```

**Step 2: Gate Kitty with `is_server` (line 1295)**

Same pattern:
```bash
    if is_wsl || is_server; then
        print_status "install kitty" "skip (WSL/server detected)"
```

**Step 3: Gate gvfs packages (lines 1366-1368)**

Wrap with:
```bash
    # gvfs - required for gvfs.yazi plugin (mount devices, MTP, SMB, etc.)
    if ! is_server; then
        install_package "gvfs"
        install_package "gvfs-backends"
    else
        print_status "install gvfs" "skip (server)"
        print_status "install gvfs-backends" "skip (server)"
    fi
```

**Step 4: Commit**

```bash
git add setup.sh
git commit -m "feat: skip Ghostty, Kitty, gvfs on server installs"
```

---

### Task 9: Gate `create_tui_desktop_entries()` and fix `final_setup()`

**Files:**
- Modify: `setup.sh:1535-1682` (desktop entries)
- Modify: `setup.sh:1764-1789` (final_setup)

**Step 1: Add server early-return to `create_tui_desktop_entries()`**

After the log header (line 1538), add:

```bash
    if is_server; then
        print_status "desktop entries" "skip (server)"
        return
    fi
```

**Step 2: Fix `final_setup()` server path**

Replace lines 1777-1788 with:

```bash
    # Final actions
    if is_wsl || is_server; then
        print_status "setup complete"
    else
        if [ "$XDG_SESSION_DESKTOP" = "i3" ] || [ "$DESKTOP_SESSION" = "i3" ]; then
            run_silent i3-msg reload
            print_status "setup complete"
        else
            run_silent gnome-session-quit --no-prompt
            print_status "setup complete"
        fi
    fi
```

**Step 3: Commit**

```bash
git add setup.sh
git commit -m "fix: prevent gnome-session-quit crash on server, skip desktop entries"
```

---

### Task 10: Update `main()` with environment logging and server flow

**Files:**
- Modify: `setup.sh:1795-1809`

**Step 1: Replace current `main()` (lines 1795-1809)**

```bash
main() {
    print_status "Starting setup..."

    # Log detected environment
    if is_wsl; then
        log_to_both "Environment: WSL"
    elif is_server; then
        log_to_both "Environment: Ubuntu Server (headless)"
    else
        log_to_both "Environment: Ubuntu Desktop"
    fi

    initial_system_setup
    install_essential_packages
    configure_dotfiles_and_utils
    setup_development_tools

    if ! is_server; then
        setup_desktop_environment
        create_tui_desktop_entries
    else
        setup_nvidia_server
        print_status "desktop environment setup" "skip (server)"
        print_status "desktop entries" "skip (server)"
    fi

    setup_shell_environment
    final_setup
}
```

**Step 2: Commit**

```bash
git add setup.sh
git commit -m "feat: update main() with environment detection and server-aware flow"
```

---

### Task 11: Restructure dotfiles into `dotfiles-common/` and `dotfiles-desktop/`

This is the largest single task. It involves moving files between directories using `git mv`.

**Files:**
- Restructure: `dotfiles/` → `dotfiles-common/` + `dotfiles-desktop/`

**Step 1: Create the `dotfiles-common` directory structure**

```bash
mkdir -p dotfiles-common/.config
```

**Step 2: Move server-compatible dotfiles to `dotfiles-common/`**

```bash
# Root-level dotfiles
git mv dotfiles/.zshrc dotfiles-common/.zshrc
git mv dotfiles/.zshenv dotfiles-common/.zshenv
git mv dotfiles/.env dotfiles-common/.env
git mv dotfiles/.profile dotfiles-common/.profile
git mv dotfiles/.gitconfig dotfiles-common/.gitconfig
git mv dotfiles/.ripgreprc dotfiles-common/.ripgreprc

# .config subdirectories
git mv dotfiles/.config/nvim dotfiles-common/.config/nvim
git mv dotfiles/.config/tmux dotfiles-common/.config/tmux
git mv dotfiles/.config/btop dotfiles-common/.config/btop
git mv dotfiles/.config/bat dotfiles-common/.config/bat
git mv dotfiles/.config/yazi dotfiles-common/.config/yazi
git mv dotfiles/.config/television dotfiles-common/.config/television
git mv dotfiles/.config/nyaa dotfiles-common/.config/nyaa
git mv dotfiles/.config/nvtop dotfiles-common/.config/nvtop
git mv dotfiles/.config/mods dotfiles-common/.config/mods
git mv dotfiles/.config/fastfetch dotfiles-common/.config/fastfetch
```

**Step 3: Rename remaining `dotfiles/` to `dotfiles-desktop/`**

```bash
git mv dotfiles dotfiles-desktop
```

Everything left in `dotfiles/` is desktop-only:
- `.Xresources`, `.xsessionrc`, `.gtkrc-2.0`
- `.icons/`
- `.mozilla/`
- `.config/i3/`, `.config/i3blocks/`, `.config/polybar/`, `.config/rofi/`
- `.config/picom/`, `.config/dunst/`, `.config/kitty/`, `.config/ghostty/`
- `.config/autostart/`, `.config/greenclip.toml`
- `.config/gtk-3.0/`, `.config/gtk-4.0/`
- `.config/pipewire/`, `.config/monitors.xml`
- `.config/virtualhere/`, `.config/transmission/`
- `.config/scripts/`

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor: split dotfiles into common and desktop stow packages

dotfiles-common/ contains server-compatible configs (zsh, nvim, tmux, etc.)
dotfiles-desktop/ contains desktop-only configs (i3, kitty, GTK, etc.)"
```

---

### Task 12: Update `configure_dotfiles_and_utils()` for split stow

**Files:**
- Modify: `setup.sh:1688-1741`

**Step 1: Replace stow command (line 1696-1697)**

Current:
```bash
    run_silent stow --no-folding --adopt --override=.* -v -t "$HOME" dotfiles
    print_status "stow dotfiles"
```

Replace with:
```bash
    # Stow common dotfiles (all environments)
    run_silent stow --no-folding --adopt --override=.* -v -t "$HOME" dotfiles-common
    print_status "stow dotfiles-common"

    # Stow desktop dotfiles (desktop only)
    if ! is_server; then
        run_silent stow --no-folding --adopt --override=.* -v -t "$HOME" dotfiles-desktop
        print_status "stow dotfiles-desktop"
    else
        print_status "stow dotfiles-desktop" "skip (server)"
    fi
```

**Step 2: Gate Firefox profile section with `is_server` (lines 1703-1731)**

Current line 1704:
```bash
    if ! is_wsl; then
```

Replace:
```bash
    if ! is_wsl && ! is_server; then
```

**Step 3: Commit**

```bash
git add setup.sh
git commit -m "feat: conditional stow for common vs desktop dotfiles"
```

---

### Task 13: Guard `.env` i3 socket line

**Files:**
- Modify: `dotfiles-common/.env:17-19`

**Step 1: Add `command -v i3` guard**

Current (lines 16-19):
```bash
# Setting socket for i3 IPC
if [ -n "$ZSH_VERSION" ]; then
    export I3SOCK="$(i3 --get-socket)"
fi
```

Replace with:
```bash
# Setting socket for i3 IPC
if [ -n "$ZSH_VERSION" ] && command -v i3 &>/dev/null; then
    export I3SOCK="$(i3 --get-socket)"
fi
```

**Step 2: Commit**

```bash
git add dotfiles-common/.env
git commit -m "fix: guard i3 socket export to prevent error on server"
```

---

### Task 14: Add tmux SSH auto-attach to `.zshrc`

**Files:**
- Modify: `dotfiles-common/.zshrc:147-154`

**Step 1: Update tmux auto-attach condition**

Current (lines 147-154):
```bash
# Only auto-start tmux if:
# 1. The shell is interactive.
# 2. You are not already inside a tmux session.
# 3. No command was passed to the shell.
# 4. The terminal is kitty or ghostty.
if [[ $- == *i* ]] && [ -z "$TMUX" ] && [ $# -eq 0 ] && [[ "$TERM" == "xterm-kitty" || "$TERM" == "xterm-ghostty" ]]; then
    tmux attach -t default || tmux new -s default
fi
```

Replace with:
```bash
# Only auto-start tmux if:
# 1. The shell is interactive.
# 2. You are not already inside a tmux session.
# 3. No command was passed to the shell.
# 4. The terminal is kitty/ghostty, or this is an SSH session.
if [[ $- == *i* ]] && [ -z "$TMUX" ] && [ $# -eq 0 ]; then
    if [[ "$TERM" == "xterm-kitty" || "$TERM" == "xterm-ghostty" ]] || [ -n "$SSH_CONNECTION" ]; then
        tmux attach -t default || tmux new -s default
    fi
fi
```

**Step 2: Commit**

```bash
git add dotfiles-common/.zshrc
git commit -m "feat: auto-attach tmux on SSH sessions"
```

---

### Task 15: Update reference to dotfiles path in `setup_desktop_environment()`

**Files:**
- Modify: `setup.sh:490` (set_monitors.sh path reference)

**Step 1: Update `set_monitors.sh` path**

Since `set_monitors.sh` moved from `dotfiles/.config/scripts/` to `dotfiles-desktop/.config/scripts/`, update line 490:

Current:
```bash
        run_silent sudo "$SETUP_DIR/dotfiles/.config/scripts/set_monitors.sh"
```

Replace:
```bash
        run_silent sudo "$SETUP_DIR/dotfiles-desktop/.config/scripts/set_monitors.sh"
```

**Step 2: Search for any other references to `dotfiles/` path in setup.sh**

Check for any other hardcoded `$SETUP_DIR/dotfiles/` references that need updating. Known references:
- Line 490: `set_monitors.sh` — updated above

**Step 3: Commit**

```bash
git add setup.sh
git commit -m "fix: update dotfiles path references after split"
```

---

### Task 16: Final verification and cleanup

**Step 1: Verify no broken references**

Search for any remaining references to the old `dotfiles/` path:

```bash
grep -rn '"$SETUP_DIR/dotfiles/' setup.sh
grep -rn '$SETUP_DIR/dotfiles/' setup.sh
```

These should return zero results (all should be `dotfiles-common/` or `dotfiles-desktop/` now).

**Step 2: Verify directory structure**

```bash
ls -la dotfiles-common/
ls -la dotfiles-desktop/
# Ensure dotfiles/ no longer exists
ls -la dotfiles/ 2>&1  # should show "No such file or directory"
```

**Step 3: Verify stow works for both packages**

```bash
cd /home/zyon/workspace/setup
stow --no-folding --simulate -v -t "$HOME" dotfiles-common 2>&1 | head -20
stow --no-folding --simulate -v -t "$HOME" dotfiles-desktop 2>&1 | head -20
```

Both should show `LINK:` lines without errors.

**Step 4: Review the full diff**

```bash
git diff main..HEAD --stat
```

**Step 5: Commit any final fixes**

```bash
git add -A
git commit -m "chore: final cleanup for Ubuntu Server compatibility"
```
