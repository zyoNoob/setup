#!/bin/bash

# --------------------------------
# setup/setup.sh
# --------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Trap any error and remove /tmp/setup.sh if it exists
trap 'rm -f /tmp/setup.sh' ERR

# ========================================
# Configuration Variables
# ========================================

# Log file path
LOG_FILE="/tmp/setup_$(date +%Y%m%d_%H%M%S).log"

# Redirect all output and errors to the log file and the console
exec > >(tee -a "$LOG_FILE") 2>&1

# Timestamp for log entries
timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# ========================================
# 1. Core Functions and Utilities
# ========================================

# Directory of the setup repo
SETUP_DIR="$HOME/workspace/setup"

# Extract branch from the download URL if available
SETUP_BRANCH=${SETUP_DOWNLOAD_URL##*/refs/heads/}
SETUP_BRANCH=${SETUP_BRANCH%%/setup.sh}
SETUP_BRANCH=${SETUP_BRANCH:-main}

# Status printing helper with timestamp
print_status() {
    local status=$?
    local message=$1
    local skip=$2
    local width=40
    local time_stamp=$(timestamp)

    if [ "$skip" = "skip" ]; then
        printf "%s | %-${width}s \e[90mSKIPPED\e[0m\n" "$time_stamp" "$message"
    else
        if [ "$status" -eq 0 ]; then
            printf "%s | %-${width}s \e[32mDONE\e[0m\n" "$time_stamp" "$message"
        else
            printf "%s | %-${width}s \e[31mFAILED\e[0m\n" "$time_stamp" "$message"
        fi
    fi
}

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
    dpkg -s "$1" &> /dev/null
}

install_package() {
    local package=$1
    local action_name="install $package"

    if is_installed "$package"; then
        print_status "$action_name" skip
    else
        sudo apt install -y "$package" >/dev/null 2>&1
        print_status "$action_name"
    fi
}

remove_package() {
    local package=$1
    local action_name="remove $package"

    if is_installed "$package"; then
        sudo apt remove -y "$package" >/dev/null 2>&1
        print_status "$action_name"
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
        cp "$src" "$tgt"
        print_status "copy config $1"
    fi
}

make_link() {
    local src="$SETUP_DIR/config/$1"
    local tgt="$HOME/$1"

    if [ -L "$tgt" ]; then
        print_status "make symlink $1" skip
    else
        ln -s "$src" "$tgt" >/dev/null 2>&1
        print_status "make symlink $1"
    fi
}

# ========================================
# 2. Initial System Setup
# ========================================

initial_system_setup() {
    echo "--------------------------------"
    echo "# 2. Initial System Setup"
    echo "--------------------------------"

    # Update package list
    sudo apt update -y >/dev/null 2>&1
    print_status "update package list"

    # Remove unnecessary packages
    remove_package "unattended-upgrades"

    # Install git first
    install_package "git"
    install_package "git-lfs"

    # Clone setup repository
    if [ ! -d "$SETUP_DIR" ]; then
        mkdir -p "$SETUP_DIR"
        git clone -b "$SETUP_BRANCH" https://github.com/zyoNoob/setup "$SETUP_DIR" >/dev/null 2>&1
        cd "$SETUP_DIR"
        git checkout "$SETUP_BRANCH" >/dev/null 2>&1
        cd - >/dev/null
        print_status "clone setup repo"
    else
        cd "$SETUP_DIR"
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        if [ "$CURRENT_BRANCH" != "$SETUP_BRANCH" ]; then
            git fetch origin "$SETUP_BRANCH" >/dev/null 2>&1
            git checkout "$SETUP_BRANCH" >/dev/null 2>&1
            print_status "switch to branch $SETUP_BRANCH"
        else
            print_status "switch to branch $SETUP_BRANCH" skip
        fi
        git pull origin "$SETUP_BRANCH" >/dev/null 2>&1
        print_status "update setup repo"
        cd - >/dev/null
    fi
}

# ========================================
# 3. Essential Package Installation
# ========================================

install_essential_packages() {
    echo "--------------------------------"
    echo "# 3. Essential Package Installation"
    echo "--------------------------------"

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
# 4. Desktop Environment Setup
# ========================================

setup_desktop_environment() {
    echo "--------------------------------"
    echo "# 4. Desktop Environment Setup"
    echo "--------------------------------"

    # Configure monitors (non-WSL only)
    if ! is_wsl; then
        "$SETUP_DIR/scripts/set_monitors.sh"
        print_status "setup monitors"
        autorandr --save user_profile --force >/dev/null 2>&1
        print_status "save monitor profile"
    else
        print_status "setup monitors" "skip (WSL detected)"
    fi
}

# ========================================
# 5. Development Tools Setup
# ========================================

setup_development_tools() {
    echo "--------------------------------"
    echo "# 5. Development Tools Setup"
    echo "--------------------------------"

    # Install VS Code (non-WSL only)
    if ! is_wsl; then
        if ! is_installed "code"; then
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg 2>/dev/null
            sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg 2>/dev/null
            echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null 2>&1
            rm -f packages.microsoft.gpg
            sudo apt update -qq >/dev/null 2>&1
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
        curl -L https://raw.github.com/ymattw/ydiff/master/ydiff.py > "$HOME/bin/ydiff" >/dev/null 2>&1
        chmod +x "$HOME/bin/ydiff"
        print_status "install ydiff"
    else
        print_status "install ydiff" skip
    fi

    # Install Miniconda
    if [ ! -d "$HOME/miniconda3" ]; then
        wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh >/dev/null 2>&1
        bash ~/miniconda.sh -b -p "$HOME/miniconda3" >/dev/null 2>&1
        rm ~/miniconda.sh
        "$HOME/miniconda3/bin/conda" init zsh >/dev/null 2>&1
        "$HOME/miniconda3/bin/conda" config --set auto_activate_base false >/dev/null 2>&1
        print_status "install miniconda"
    else
        print_status "install miniconda" skip
    fi

    # Install Rust
    if [ ! -x "$(command -v rustc)" ]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >/dev/null 2>&1
        print_status "install rust"
    else
        print_status "install rust" skip
    fi

    # Install Zig
    if [ ! -x "$(command -v zig)" ]; then
        ZIG_VERSION="0.13.0"
        wget -q "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" -O /tmp/zig.tar.xz >/dev/null 2>&1
        sudo mkdir -p /usr/local/zig
        sudo tar xf /tmp/zig.tar.xz -C /usr/local/zig --strip-components=1
        sudo ln -s /usr/local/zig/zig /usr/local/bin/zig
        rm -rf /tmp/zig.tar.xz
        print_status "install zig"
    else
        print_status "install zig" skip
    fi
}

# ========================================
# 6. Shell Environment Setup
# ========================================

setup_shell_environment() {
    echo "--------------------------------"
    echo "# 6. Shell Environment Setup"
    echo "--------------------------------"

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
            git clone https://github.com/mitchellh/ghostty.git "$HOME/bin/ghostty" >/dev/null 2>&1
            cd "$HOME/bin/ghostty"
            zig build -p "$HOME/.local" -Doptimize=ReleaseFast >/dev/null 2>&1
            print_status "install ghostty"
            cd "$HOME" >/dev/null
            rm -rf "$HOME/bin/ghostty"
        fi
    fi

    # Install Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null 2>&1
        print_status "install omz"
        rm -f "$HOME/.zshrc"
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

    OLDIFS="$IFS"
    IFS=$'\n'

    for entry in "${plugins[@]}"; do
        plugin=$(echo "$entry" | awk '{print $1}')
        url=$(echo "$entry" | awk '{print $2}')
        plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin"

        if [ ! -d "$plugin_dir" ]; then
            if [ "$plugin" = "zsh-autocomplete" ]; then
                git clone -q --depth 1 -- "$url" "$plugin_dir"
            else
                git clone -q "$url" "$plugin_dir"
            fi
            print_status "install $plugin"
        else
            print_status "install $plugin" skip
        fi
    done

    IFS="$OLDIFS"
}

# ========================================
# 7. Configuration and Dotfiles
# ========================================

configure_dotfiles() {
    echo "--------------------------------"
    echo "# 7. Configuration and Dotfiles"
    echo "--------------------------------"

    # Stow dotfiles with explicit target directory and adopt existing files
    cd "$SETUP_DIR" >/dev/null
    stow --adopt -t "$HOME" dotfiles >/dev/null 2>&1
    print_status "stow dotfiles"
    cd - >/dev/null

    # Copy .netrc
    copy_file ".netrc"

    # Generate SSH key
    if [ ! -f "$HOME/.ssh/id_rsa" ]; then
        mkdir -p "$HOME/.ssh"
        ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N "" >/dev/null 2>&1
        chmod 600 "$HOME/.ssh/id_rsa"
        chmod 644 "$HOME/.ssh/id_rsa.pub"
        print_status "generate ssh key"
    else
        print_status "generate ssh key" skip
    fi

    # Install Meslo Nerd Font
    if ! ls "$HOME/.local/share/fonts" 2>/dev/null | grep -q "meslo-nerd-font"; then
        mkdir -p "$HOME/.local/share/fonts"
        FONT_TMP_DIR=$(mktemp -d)
        wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Meslo.zip" -P "$FONT_TMP_DIR" >/dev/null 2>&1
        unzip -q "$FONT_TMP_DIR/Meslo.zip" -d "$HOME/.local/share/fonts/meslo-nerd-font" >/dev/null 2>&1
        rm -rf "$FONT_TMP_DIR"
        fc-cache -f >/dev/null 2>&1
        print_status "install meslo nerd font"
    else
        print_status "install meslo nerd font" skip
    fi
}

# ========================================
# 8. Final Setup and Cleanup
# ========================================

final_setup() {
    echo "--------------------------------"
    echo "# 8. Final Setup and Cleanup"
    echo "--------------------------------"

    # Switch to zsh
    if [ "$SHELL" != "$(which zsh)" ]; then
        chsh -s "$(which zsh)" >/dev/null
        print_status "switch to zsh"
    else
        print_status "switch to zsh" skip
    fi

    # Final actions
    if is_wsl; then
        print_status "setup complete"
    else
        if [ "$XDG_SESSION_DESKTOP" = "i3" ] || [ "$DESKTOP_SESSION" = "i3" ]; then
            i3-msg reload
        else
            gnome-session-quit --no-prompt
        fi
    fi
}

# ========================================
# 9. Main Execution Flow
# ========================================

main() {
    echo "$(timestamp) | Starting setup..."

    initial_system_setup
    install_essential_packages
    configure_dotfiles
    setup_desktop_environment
    setup_development_tools
    setup_shell_environment
    final_setup

    echo "$(timestamp) | Setup complete!"
}

# Invoke the main function
main