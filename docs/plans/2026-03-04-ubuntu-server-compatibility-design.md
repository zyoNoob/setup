# Ubuntu Server Compatibility Design

**Date:** 2026-03-04
**Status:** Approved
**Approach:** Guard-First (add `is_server()` guards around desktop-only code)

## Problem

The `setup.sh` script only supports Ubuntu Desktop. Running it on Ubuntu Server (live server / headless) causes crashes (`gnome-session-quit`, `xrandr`, `i3 --get-socket`), installs ~30 unnecessary GUI packages, and stows desktop-only dotfiles.

## Detection

Add `is_server()` function using systemd default target:

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

Rationale: Ubuntu Desktop and Server share the same kernel (`uname -r` is identical). The difference is userspace — `graphical.target` vs `multi-user.target`. This is the most reliable persistent check.

Also split NVIDIA detection:

```bash
has_nvidia_driver() {
    command -v nvidia-settings &>/dev/null || command -v nvidia-smi &>/dev/null
}

has_nvidia_gui() {
    command -v nvidia-settings &>/dev/null
}
```

## Skip Message Convention

Desktop-only items on server print: `print_status "action name" "skip (server)"` — matching existing `"skip (WSL detected)"` pattern.

## Function-Level Changes

### `initial_system_setup()`

- Gate Firefox snap removal + Mozilla repo block with `! is_server` (in addition to existing `! is_wsl`)

### `install_essential_packages()`

Split `packages_core` array:

**Keep in `packages_core` (server-compatible):**
curl, gcc, g++, libclang-dev, clang, build-essential, pkg-config, stow, cmake, libssl-dev, libcurl4-openssl-dev, python3, python3-dev, python3-pip, python3-numpy, flatpak, htop, btop, speedtest-cli, net-tools, screen, unzip, 7zip, keychain, rename, openssh-server, zsh, tmux, silversearcher-ag, tree, avahi-daemon, avahi-utils, iperf3, aria2

**New `packages_desktop` array (gated by `! is_server`):**
i3, i3blocks, rofi, picom, polybar, dunst, feh, maim, xclip, xdotool, pavucontrol, pulsemixer, policykit-1-gnome, network-manager-gnome, wireplumber, transmission, libfuse2

**Additional gates:**
- Flatpak section (lines 423-476): gate with `! is_server`
- brightnessctl (lines 396-403): gate with `! is_server`

### `setup_desktop_environment()`

Add early return for server:
```bash
if is_server; then
    print_status "desktop environment setup" "skip (server)"
    return
fi
```

The existing `is_wsl` check remains.

### `setup_nvidia_coolbits()` + `setup_nvidia_overclock()`

Gate with `is_server` — skip on server. These use X11-dependent `nvidia-settings`.

### New: `setup_nvidia_server()`

Server-specific NVIDIA GPU management using `nvidia-smi`:
- Detect via `nvidia-smi` (not `nvidia-settings`)
- Enable persistence mode: `nvidia-smi -pm 1`
- Set clock offsets: `nvidia-smi --lock-gpu-clocks` / `--lock-memory-clocks`
- Deploy as systemd oneshot service (`After=nvidia-persistenced.service`)
- Sudoers rule for `nvidia-smi` instead of `nvidia-settings`

### `setup_development_tools()`

- VS Code: add `! is_server` to existing `! is_wsl` gate
- `netron` uv tool: gate with `! is_server`
- `virt-manager`: gate with `! is_server` (servers use `virsh`)
- GStreamer GUI packages (`gstreamer1.0-gtk3`, `gstreamer1.0-qt5`, `gstreamer1.0-x`): gate with `! is_server`

### `setup_shell_environment()`

**Gated by `! is_server`:**
- Ghostty (GPU terminal, needs display)
- Kitty (GPU terminal, needs display)
- gvfs, gvfs-backends (GNOME desktop automounting)

**Installed on ALL environments (including server):**
- All TUI apps: yazi, nyaa, manga-tui, spotify_player, bluetui, television
- All CLI tools: ripgrep, fd, zoxide, bat, ouch, fastfetch, nvtop
- TPM (tmux plugin manager)
- Oh My Zsh + all plugins

### `create_tui_desktop_entries()`

Early return on server — `.desktop` files are never used headlessly.

### `configure_dotfiles_and_utils()`

Replace single `stow dotfiles` with:
```bash
stow --no-folding --adopt --override=.* -v -t "$HOME" dotfiles-common
if ! is_server; then
    stow --no-folding --adopt --override=.* -v -t "$HOME" dotfiles-desktop
fi
```

Gate Firefox profile creation with `! is_server`.

### `final_setup()`

Add server path — just switch to zsh and print complete. No `i3-msg reload` or `gnome-session-quit`.

### `main()`

```bash
main() {
    print_status "Starting setup..."

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

## Dotfiles Restructure

### `dotfiles-common/` (stowed everywhere)

```
dotfiles-common/
├── .zshrc              # with tmux SSH auto-attach
├── .zshenv
├── .env                # with i3 guard
├── .profile
├── .gitconfig
├── .ripgreprc
└── .config/
    ├── nvim/
    ├── tmux/tmux.conf
    ├── btop/
    ├── bat/
    ├── yazi/
    ├── television/
    ├── nyaa/config.toml
    ├── nvtop/interface.ini
    ├── mods/mods.yml
    └── fastfetch/config.jsonc
```

### `dotfiles-desktop/` (desktop only)

```
dotfiles-desktop/
├── .Xresources
├── .xsessionrc
├── .gtkrc-2.0
└── .config/
    ├── i3/config
    ├── i3blocks/config
    ├── polybar/
    ├── rofi/
    ├── picom/picom.conf
    ├── dunst/dunstrc
    ├── kitty/
    ├── ghostty/config
    ├── autostart/picom.desktop
    ├── greenclip.toml
    ├── gtk-3.0/settings.ini
    ├── gtk-4.0/settings.ini
    ├── pipewire/
    ├── monitors.xml
    ├── virtualhere/vhuit.ini
    ├── transmission/settings.json
    └── scripts/
        ├── set_monitors.sh
        ├── export_monitors.sh
        ├── set_mouse.sh
        ├── lock.sh
        ├── screenshot.sh
        ├── scratchpad.sh
        └── generic_scratchpad.sh
```

## Dotfile Content Changes

### `.env` — Guard i3 socket

```bash
# Before:
if [ -n "$ZSH_VERSION" ]; then
    export I3SOCK="$(i3 --get-socket)"
fi

# After:
if [ -n "$ZSH_VERSION" ] && command -v i3 &>/dev/null; then
    export I3SOCK="$(i3 --get-socket)"
fi
```

### `.zshrc` — Tmux auto-attach on SSH

```bash
# Before:
if [[ $- == *i* ]] && [ -z "$TMUX" ] && [ $# -eq 0 ] && [[ "$TERM" == "xterm-kitty" || "$TERM" == "xterm-ghostty" ]]; then
    tmux attach -t default || tmux new -s default
fi

# After:
if [[ $- == *i* ]] && [ -z "$TMUX" ] && [ $# -eq 0 ]; then
    if [[ "$TERM" == "xterm-kitty" || "$TERM" == "xterm-ghostty" ]] || [ -n "$SSH_CONNECTION" ]; then
        tmux attach -t default || tmux new -s default
    fi
fi
```

### `fastfetch/config.jsonc`

No changes. GUI modules show N/A on server — cosmetic only.
