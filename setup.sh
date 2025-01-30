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
    )

    # System utilities
    local packages_system=(
        htop
        btop
        apt-transport-https
        speedtest-cli
        net-tools
        screen
        unzip
        keychain
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
        arandr
        autorandr
        pavucontrol
        nitrogen
        dunst
        rofi
        picom
        polybar
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
        run_silent "$SETUP_DIR/scripts/set_monitors.sh"
        print_status "setup monitors"
        run_silent autorandr --save user_profile --force
        print_status "save monitor profile"
    else
        print_status "setup monitors" "skip (WSL detected)"
    fi

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

            # Clone and build Ghostty
            run_silent git clone https://github.com/mitchellh/ghostty.git "$HOME/bin/ghostty"
            cd "$HOME/bin/ghostty"
            run_silent zig build -p "$HOME/.local" -Doptimize=ReleaseFast
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

configure_dotfiles() {
    log_to_both "--------------------------------"
    log_to_both "# Configuration and Dotfiles"
    log_to_both "--------------------------------"

    # Stow dotfiles with explicit target directory and adopt existing files
    # --no-folding ensures exact file matching without directory merging
    cd "$SETUP_DIR"
    run_silent stow --no-folding --adopt -v -t "$HOME" dotfiles
    print_status "stow dotfiles"
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
        run_verbose chsh -s "$(which zsh)"
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
    configure_dotfiles
    setup_desktop_environment
    setup_development_tools
    setup_shell_environment
    final_setup
}

# Invoke the main function
main