#!/bin/bash

# --------------------------------
# setup/setup.sh
# --------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Log file path
LOG_FILE="/tmp/setup_$(date +%Y%m%d_%H%M%S).log"

# Create log file
touch "$LOG_FILE"

# Logging functions
log_to_file() {
    echo "$(timestamp) | $*" >> "$LOG_FILE"
}

log_to_console() {
    echo "$*" >&1
}

log_to_both() {
    log_to_file "$*"
    log_to_console "$*"
}

# Silent execution - output only to log file
run_silent() {
    local cmd="$*"
    local output
    local exit_status

    # Capture both stdout and stderr
    output=$("$@" 2>&1)
    exit_status=$?

    # Always log the command and its output
    log_to_file "Command: $cmd"
    log_to_file "Output: $output"
    
    return $exit_status
}

# Verbose execution - output to both console and log
run_verbose() {
    local cmd="$*"
    local output
    local exit_status

    # Capture both stdout and stderr
    output=$("$@" 2>&1)
    exit_status=$?

    # Log command and output to both channels
    log_to_both "Command: $cmd"
    log_to_both "Output: $output"
    
    return $exit_status
}

# Function to print status messages
print_status() {
    local status=$?
    local message=$1
    local skip=$2
    local width=40
    local time_stamp=$(timestamp)
    local output

    if [ "$skip" = "skip" ]; then
        output=$(printf "%s | %-${width}s \e[90mSKIPPED\e[0m" "$time_stamp" "$message")
    else
        if [ "$status" -eq 0 ]; then
            output=$(printf "%s | %-${width}s \e[32mDONE\e[0m" "$time_stamp" "$message")
        else
            output=$(printf "%s | %-${width}s \e[31mFAILED\e[0m" "$time_stamp" "$message")
            log_to_console "See full log at: $LOG_FILE"
        fi
    fi

    # Status messages go to both console and log
    log_to_both "$output"
}

# ========================================
# Configuration Variables
# ========================================

# Timestamp for log entries
timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# ========================================
# Core Functions and Utilities
# ========================================

# Directory of the setup repo
SETUP_DIR="$HOME/workspace/setup"

# Extract branch from the download URL if available
SETUP_BRANCH=${SETUP_DOWNLOAD_URL##*/refs/heads/}
SETUP_BRANCH=${SETUP_BRANCH%%/setup.sh}
SETUP_BRANCH=${SETUP_BRANCH:-main}

# Environment detection
is_wsl() {
    case "$(uname -r)" in
    *microsoft* ) return 0 ;; # WSL 2
    *Microsoft* ) return 0 ;; # WSL 1
    * ) return 1 ;;
    esac
}

# Package management helpers
is_installed() {
    # Only log to file, return status for logic
    if run_silent dpkg -s "$1"; then
        return 0
    else
        return 1
    fi
}

install_package() {
    local package=$1
    local action_name="install $package"

    if is_installed "$package"; then
        print_status "$action_name" skip
    else
        # Run apt install silently (only to log)
        if run_silent sudo DEBIAN_FRONTEND=noninteractive apt install -y "$package"; then
            print_status "$action_name"
        else
            print_status "$action_name"
            return 1
        fi
    fi
}

remove_package() {
    local package=$1
    local action_name="remove $package"

    if is_installed "$package"; then
        # Run apt remove silently (only to log)
        if run_silent sudo DEBIAN_FRONTEND=noninteractive apt remove -y "$package"; then
            print_status "$action_name"
        else
            print_status "$action_name"
            return 1
        fi
    else
        print_status "$action_name" skip
    fi
}

# File management helpers
copy_file() {
    local src="$SETUP_DIR/config/$1"
    local tgt="$HOME/$1"

    if [ -e "$tgt" ]; then
        print_status "copy config $1" skip
    else
        run_silent cp "$src" "$tgt"
        print_status "copy config $1"
    fi
}

make_link() {
    local src="$SETUP_DIR/config/$1"
    local tgt="$HOME/$1"

    if [ -L "$tgt" ]; then
        print_status "make symlink $1" skip
    else
        run_silent ln -s "$src" "$tgt"
        print_status "make symlink $1"
    fi
}

# ========================================
# Initial System Setup
# ========================================

initial_system_setup() {
    log_to_both "--------------------------------"
    log_to_both "# Initial System Setup"
    log_to_both "--------------------------------"

    # Update package list
    run_silent sudo apt update -y
    print_status "update package list"

    # Remove unnecessary packages
    remove_package "unattended-upgrades"

    # Reinstall Firefox from Mozilla repo
    if ! is_wsl; then
        # Remove snap version
        if snap list firefox &>/dev/null; then
            run_silent sudo snap remove firefox
            print_status "remove firefox snap"

            # Add Mozilla repository
            MOZILLA_KEYRING="/etc/apt/keyrings/packages.mozilla.org.asc"
            if [ ! -f "$MOZILLA_KEYRING" ]; then
                run_silent sudo install -d -m 0755 /etc/apt/keyrings
                run_silent sudo wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O "$MOZILLA_KEYRING"
                print_status "add mozilla signing key"
            else
                print_status "add mozilla signing key" skip
            fi

            MOZILLA_LIST="/etc/apt/sources.list.d/mozilla.list"
            if [ ! -f "$MOZILLA_LIST" ]; then
                run_silent sudo bash -c 'echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" > /etc/apt/sources.list.d/mozilla.list'
                print_status "add mozilla apt repo"
            else
                print_status "add mozilla apt repo" skip
            fi

            # Add package preferences
            MOZILLA_PREFS="/etc/apt/preferences.d/mozilla"
            if [ ! -f "$MOZILLA_PREFS" ]; then
                run_silent sudo tee "$MOZILLA_PREFS" > /dev/null <<EOL
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
EOL
                print_status "add mozilla apt preferences"
            else
                print_status "add mozilla apt preferences" skip
            fi

            # Update and reinstall firefox
            run_silent sudo apt update -y
            print_status "update package list with mozilla repo"
            
            # Force remove existing firefox and install from Mozilla repo
            remove_package "firefox"
            if run_silent sudo DEBIAN_FRONTEND=noninteractive apt install -y firefox; then
                print_status "install firefox from mozilla repo"
            else
                print_status "install firefox from mozilla repo"
                return 1
            fi
        else
            print_status "remove firefox snap" skip
        fi
    else
        print_status "firefox reinstallation" "skip (WSL detected)"
    fi

    # Install git first
    install_package "git"
    install_package "git-lfs"

    # Clone setup repository
    if [ ! -d "$SETUP_DIR" ]; then
        mkdir -p "$SETUP_DIR"
        run_silent bash -c 'git clone -b "$1" https://github.com/zyoNoob/setup "$2" && \
            cd "$2" && \
            git checkout "$1"' -- "$SETUP_BRANCH" "$SETUP_DIR"
        print_status "clone setup repo"
    else
        cd "$SETUP_DIR"
        # Get current branch and handle git operations in a single context
        run_silent bash -c '
            CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            if [ "$CURRENT_BRANCH" != "$1" ]; then
                git fetch origin "$1" && \
                git checkout "$1"
                exit $?
            fi
            exit 0
        ' -- "$SETUP_BRANCH"
        if [ $? -eq 0 ]; then
            print_status "switch to branch $SETUP_BRANCH" skip
        else
            print_status "switch to branch $SETUP_BRANCH"
        fi
        run_silent git pull origin "$SETUP_BRANCH"
        print_status "update setup repo"
        cd - >/dev/null
    fi

    # Copy bashrc to warmup
    run_silent sudo cp "$SETUP_DIR/config/.bashrc" "$HOME/.bashrc"
    print_status "copy bashrc"
}

# ========================================
# Essential Package Installation
# ========================================

install_essential_packages() {
    log_to_both "--------------------------------"
    log_to_both "# Essential Package Installation"
    log_to_both "--------------------------------"
    # Core development tools
    local packages_core=(
        curl
        g++
        build-essential
        pkg-config
        stow
        cmake
        libssl-dev
        libcurl4-openssl-dev
        python3-dev
    )

    # System utilities
    local packages_system=(
        htop
        btop
        speedtest-cli
        net-tools
        screen
        unzip
        keychain
        maim
        xclip
        xdotool
        rename
        transmission
        policykit-1-gnome
    )

    # Terminal environment
    local packages_terminal=(
        zsh
        tmux
        fzf
        silversearcher-ag
        tree
        neovim
    )

    # Desktop environment
    local packages_desktop=(
        i3
        pavucontrol
        feh
        dunst
        rofi
        picom
        polybar
        neofetch
    )

    # Install all packages
    for pkg in "${packages_core[@]}" "${packages_system[@]}" "${packages_terminal[@]}" "${packages_desktop[@]}"; do
        install_package "$pkg"
    done
}

# ========================================
# Desktop Environment Setup
# ========================================

setup_desktop_environment() {
    log_to_both "--------------------------------"
    log_to_both "# Desktop Environment Setup"
    log_to_both "--------------------------------"

    # Configure monitors (non-WSL only)
    if ! is_wsl; then
        run_silent sudo "$SETUP_DIR/dotfiles/.config/scripts/set_monitors.sh"
        print_status "setup monitors"
        run_silent sudo cp "$HOME/.config/monitors.xml" "/var/lib/gdm3/.config/"
        print_status "copy monitors.xml to gdm3"
        run_silent sudo chown gdm:gdm /var/lib/gdm3/.config/monitors.xml
        print_status "change owner to gdm"

        # Install Meslo Nerd Font
        if [ ! -d "$HOME/.local/share/fonts/meslo-nerd-font" ]; then
            mkdir -p "$HOME/.local/share/fonts"
            FONT_TMP_DIR=$(mktemp -d)
            run_silent wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Meslo.zip" -P "$FONT_TMP_DIR"
            run_silent unzip -q "$FONT_TMP_DIR/Meslo.zip" -d "$HOME/.local/share/fonts/meslo-nerd-font"
            rm -rf "$FONT_TMP_DIR"
            run_silent fc-cache -f
            print_status "install meslo nerd font"
        else
            print_status "install meslo nerd font" skip
        fi

        # Install Catppuccin GTK theme
        CATPPUCCIN_THEME_DIR="$HOME/.local/share/themes/catppuccin-mocha-blue-standard+default"
        if [ ! -d "$CATPPUCCIN_THEME_DIR" ]; then
            mkdir -p ~/.local/share/themes
            ROOT_URL="https://github.com/catppuccin/gtk/releases/download"
            RELEASE="v1.0.3"
            FLAVOR="mocha"
            ACCENT="blue"
            run_silent wget -q "${ROOT_URL}/${RELEASE}/catppuccin-${FLAVOR}-${ACCENT}-standard+default.zip" -O "/tmp/catppuccin-theme.zip"
            run_silent unzip -q "/tmp/catppuccin-theme.zip" -d ~/.local/share/themes
            rm -f "/tmp/catppuccin-theme.zip"
            mkdir -p "${HOME}/.config/gtk-4.0"
            run_silent ln -sf "${CATPPUCCIN_THEME_DIR}/gtk-4.0/assets" "${HOME}/.config/gtk-4.0/assets"
            run_silent ln -sf "${CATPPUCCIN_THEME_DIR}/gtk-4.0/gtk.css" "${HOME}/.config/gtk-4.0/gtk.css"
            run_silent ln -sf "${CATPPUCCIN_THEME_DIR}/gtk-4.0/gtk-dark.css" "${HOME}/.config/gtk-4.0/gtk-dark.css"
            print_status "install catppuccin gtk theme"
        else
            print_status "install catppuccin gtk theme" skip
        fi

        # Install Papirus icon theme and Catppuccin cursors
        if ! is_installed "papirus-icon-theme"; then
            run_silent sudo add-apt-repository -y ppa:papirus/papirus
            run_silent sudo apt update -y
            install_package "papirus-icon-theme"
        else
            print_status "install papirus icon theme" skip
        fi

        CURSOR_DARK_DIR="$HOME/.icons/catppuccin-mocha-dark-cursors"
        if [ ! -d "$CURSOR_DARK_DIR" ]; then
            mkdir -p ~/.icons
            run_silent wget -q "https://github.com/catppuccin/cursors/releases/download/v1.0.2/catppuccin-mocha-dark-cursors.zip" -O "/tmp/cursors.zip"
            run_silent unzip -q "/tmp/cursors.zip" -d ~/.icons
            rm -f "/tmp/cursors.zip"
            print_status "install catppuccin dark cursors"
        else
            print_status "install catppuccin dark cursors" skip
        fi

        CURSOR_LIGHT_DIR="$HOME/.icons/catppuccin-mocha-light-cursors"
        if [ ! -d "$CURSOR_LIGHT_DIR" ]; then
            mkdir -p ~/.icons
            run_silent wget -q "https://github.com/catppuccin/cursors/releases/download/v1.0.2/catppuccin-mocha-light-cursors.zip" -O "/tmp/cursors.zip"
            run_silent unzip -q "/tmp/cursors.zip" -d ~/.icons
            rm -f "/tmp/cursors.zip"
            print_status "install catppuccin light cursors"
        else
            print_status "install catppuccin light cursors" skip
        fi

        # Enable userChrome.css support for firefox theming
        AUTOCONFIG_DIR="/usr/lib/firefox/defaults/pref"
        if [ ! -f "$AUTOCONFIG_DIR/autoconfig.js" ]; then
            run_silent sudo mkdir -p "$AUTOCONFIG_DIR"
            echo 'pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' | \
                run_silent sudo tee "$AUTOCONFIG_DIR/autoconfig.js"
            print_status "enable firefox userchrome support"
        else
            print_status "enable firefox userchrome support" skip
        fi

        # Copy backgrounds
        if [ ! -d "$HOME/Pictures/backgrounds" ]; then
            run_silent cp -r "$SETUP_DIR/backgrounds" "$HOME/Pictures/"
            print_status "copy backgrounds"
        else
            print_status "copy backgrounds" skip
        fi

        # Install 'yazi' file manager
        if [ ! -x "$(command -v yazi)" ]; then
            run_silent $HOME/.cargo/bin/cargo install --locked yazi-fm yazi-cli
            print_status "install yazi"
        else
            print_status "install yazi" skip
        fi

        # Apply GNOME desktop settings
        run_silent gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false
        run_silent gsettings set org.gnome.desktop.interface cursor-size 24
        run_silent gsettings set org.gnome.desktop.interface cursor-blink true
        run_silent gsettings set org.gnome.desktop.interface cursor-blink-timeout 1200
        run_silent gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        run_silent gsettings set org.gnome.desktop.peripherals.mouse speed -0.40
        run_silent gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
        run_silent gsettings set org.gnome.desktop.interface font-name 'MesloLGS Nerd Font 12'
        run_silent gsettings set org.gnome.desktop.interface document-font-name 'MesloLGS Nerd Font 12'
        run_silent gsettings set org.gnome.desktop.interface monospace-font-name 'MesloLGS Nerd Font Mono 12'
        run_silent gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-mocha-blue-standard+default'
        run_silent gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
        run_silent gsettings set org.gnome.desktop.interface cursor-theme 'catppuccin-mocha-dark-cursors'
        print_status "apply desktop settings"
    else
        print_status "desktop environment setup" "skip (WSL detected)"
    fi
}

# ========================================
# Development Tools Setup
# ========================================

setup_development_tools() {
    log_to_both "--------------------------------"
    log_to_both "# Development Tools Setup"
    log_to_both "--------------------------------"

    # Install VS Code (non-WSL only)
    if ! is_wsl; then
        if ! is_installed "code"; then
            # Download and set up Microsoft's GPG key and repository in one sequence
            run_silent bash -c '
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg && \
                sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && \
                echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
                sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null && \
                rm -f /tmp/microsoft.gpg && \
                sudo apt update
            '
            install_package "code"
        else
            print_status "install code" skip
        fi
    else
        print_status "install code" "skip (WSL detected)"
    fi

    # Install ydiff
    if [ ! -f "$HOME/bin/ydiff" ]; then
        mkdir -p "$HOME/bin"
        run_silent curl -L https://raw.github.com/ymattw/ydiff/master/ydiff.py -o "$HOME/bin/ydiff"
        run_silent chmod +x "$HOME/bin/ydiff"
        print_status "install ydiff"
    else
        print_status "install ydiff" skip
    fi

    # Install Miniconda
    if [ ! -d "$HOME/miniconda3" ]; then
        run_silent wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
        run_silent bash ~/miniconda.sh -b -p "$HOME/miniconda3"
        rm ~/miniconda.sh
        run_silent "$HOME/miniconda3/bin/conda" init zsh
        run_silent "$HOME/miniconda3/bin/conda" config --set auto_activate_base false
        print_status "install miniconda"
    else
        print_status "install miniconda" skip
    fi

    # Install uv for Python package management
    if [ ! -x "$(command -v uv)" ]; then
        run_silent bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
        print_status "install uv"
    else
        print_status "install uv" skip
    fi

    # Install Rust
    if [ ! -x "$(command -v rustc)" ]; then
        run_silent bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
        print_status "install rust"
    else
        print_status "install rust" skip
    fi

    # Install Zig
    if [ ! -x "$(command -v zig)" ]; then
        ZIG_VERSION="0.13.0"
        run_silent wget -q "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" -O /tmp/zig.tar.xz
        run_silent sudo mkdir -p /usr/local/zig
        run_silent sudo tar xf /tmp/zig.tar.xz -C /usr/local/zig --strip-components=1
        run_silent sudo ln -s /usr/local/zig/zig /usr/local/bin/zig
        rm -rf /tmp/zig.tar.xz
        print_status "install zig"
    else
        print_status "install zig" skip
    fi

    # Install ngrok
    if is_installed "ngrok"; then
        print_status "install ngrok" skip
    else
        # Add ngrok GPG key and repository
        run_silent bash -c 'curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
            | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
            && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
            | sudo tee /etc/apt/sources.list.d/ngrok.list'
        # Update apt package list after adding the ngrok repository
        run_silent sudo apt update -y
        # Finally, install ngrok using your install_package function
        install_package "ngrok"
    fi
}

# ========================================
# Shell Environment Setup
# ========================================

setup_shell_environment() {
    log_to_both "--------------------------------"
    log_to_both "# Shell Environment Setup"
    log_to_both "--------------------------------"

    # Install Ghostty if not in WSL
    if is_wsl; then
        print_status "install ghostty" "skip (WSL detected)"
    else
        if [ -x "$(command -v ghostty)" ]; then
            print_status "install ghostty" skip
        else
            # Install build dependencies
            install_package "libgtk-4-dev"
            install_package "libadwaita-1-dev"

            # Clone and build Ghostty (cleanup old cloned repo)
            if [ -d "$HOME/bin/ghostty" ]; then
                rm -rf "$HOME/bin/ghostty"
            fi
            run_silent git clone https://github.com/ghostty-org/ghostty.git -- "$HOME/bin/ghostty"
            cd "$HOME/bin/ghostty"
            run_silent git checkout tags/v1.1.2
            run_silent zig build -p "$HOME/.local" -Doptimize=ReleaseFast -Dgtk-adwaita=true
            print_status "install ghostty"
            cd "$HOME" >/dev/null
            rm -rf "$HOME/bin/ghostty"
        fi
    fi

    # Install Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        run_silent bash -c 'curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh -s -- --unattended --keep-zshrc'
        print_status "install omz"
    else
        print_status "install omz" skip
    fi

    # Install Oh My Zsh plugins
    local plugins=(
        "fzf-tab https://github.com/Aloxaf/fzf-tab"
        "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions"
        "zsh-autocomplete https://github.com/marlonrichert/zsh-autocomplete.git"
        "F-Sy-H https://github.com/z-shell/F-Sy-H.git"
        "conda-zsh-completion https://github.com/conda-incubator/conda-zsh-completion"
    )

    for entry in "${plugins[@]}"; do
        plugin=$(echo "$entry" | cut -d' ' -f1)
        url=$(echo "$entry" | cut -d' ' -f2)
        plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin"

        if [ ! -d "$plugin_dir" ]; then
            if [ "$plugin" = "zsh-autocomplete" ]; then
                run_silent bash -c 'git clone -q --depth 1 -- "$1" "$2"' -- "$url" "$plugin_dir"
            else
                run_silent bash -c 'git clone -q "$1" "$2"' -- "$url" "$plugin_dir"
            fi
            print_status "install $plugin"
        else
            print_status "install $plugin" skip
        fi
    done
}

# ========================================
# Configuration and Dotfiles
# ========================================

configure_dotfiles_and_utils() {
    log_to_both "--------------------------------"
    log_to_both "# Configurating Dotfiles & Utils"
    log_to_both "--------------------------------"

    cd "$SETUP_DIR"    
   
    # Stow dotfiles with explicit target directory and adopt existing files
    run_silent stow --no-folding --adopt --override=* -v -t "$HOME" dotfiles
    print_status "stow dotfiles"
    run_silent stow --no-folding --adopt --override=* -v -t "$HOME" utils
    print_status "stow utils"

    # Ensure Firefox profile exists
    if ! is_wsl; then
        FIREFOX_PROFILE_DIR=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name '*.default-release' | head -n 1)
        if [ -z "$FIREFOX_PROFILE_DIR" ]; then
            print_status "creating firefox profile"
            # Launch and kill firefox to generate profile
            timeout 5s firefox --headless >/dev/null 2>&1 &
            sleep 2
            pkill -f firefox || true
            FIREFOX_PROFILE_DIR=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name '*.default-release' | head -n 1)
        fi
    fi

    # Link Firefox profile chrome directory
    if [ -n "$FIREFOX_PROFILE_DIR" ]; then
        CHROME_TARGET="../default-release/chrome"
        if [ ! -L "$FIREFOX_PROFILE_DIR/chrome" ]; then
            # Remove existing directory if present
            if [ -d "$FIREFOX_PROFILE_DIR/chrome" ]; then
                run_silent rm -rf "$FIREFOX_PROFILE_DIR/chrome"
            fi
            run_silent ln -sf "$CHROME_TARGET" "$FIREFOX_PROFILE_DIR/chrome"
            print_status "link firefox chrome config"
        else
            print_status "link firefox chrome config" skip
        fi
    else
        print_status "firefox profile configuration" "skip (profile not found)"
    fi

    # Clean up any adopted changes from stow
    if ! git diff --quiet; then
        run_silent git stash
        print_status "stash adopted changes"
    else
        print_status "stash adopted changes" skip
    fi
    cd - >/dev/null

    # Copy .netrc
    copy_file ".netrc"

    # Generate SSH key
    if [ ! -f "$HOME/.ssh/id_rsa" ]; then
        mkdir -p "$HOME/.ssh"
        run_silent ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
        run_silent chmod 600 "$HOME/.ssh/id_rsa"
        run_silent chmod 644 "$HOME/.ssh/id_rsa.pub"
        print_status "generate ssh key"
    else
        print_status "generate ssh key" skip
    fi
}

# ========================================
# Final Setup and Cleanup
# ========================================

final_setup() {
    log_to_both "--------------------------------"
    log_to_both "# Final Setup and Cleanup"
    log_to_both "--------------------------------"

    # Switch to zsh
    if [ "$SHELL" != "$(which zsh)" ]; then
        chsh -s "$(which zsh)"
        print_status "switch to zsh"
    else
        print_status "switch to zsh" skip
    fi

    # Final actions
    if is_wsl; then
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
}

# ========================================
# Main Execution Flow
# ========================================

main() {
    print_status "Starting setup..."

    initial_system_setup
    install_essential_packages
    configure_dotfiles_and_utils
    setup_development_tools
    setup_desktop_environment
    setup_shell_environment
    final_setup
}

# Invoke the main function
main