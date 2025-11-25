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

# Directory for storing compiled programs
COMPILED_PROGRAMS_DIR="$HOME/workspace/compiled-programs"

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
    local src="$1"
    local tgt="$2"
    local name="$3"

    if [ -e "$tgt" ]; then
        print_status "copy $name" skip
    else
        run_silent cp "$src" "$tgt"
        print_status "copy $name"
    fi
}

make_link() {
    local src="$1"
    local tgt="$2"
    local name="$3"

    if [ -L "$tgt" ]; then
        print_status "symlink $name" skip
    else
        run_silent ln -s "$src" "$tgt"
        print_status "symlink $name"
    fi
}

# ========================================
# Initial System Setup
# ========================================

initial_system_setup() {
    log_to_both "--------------------------------"
    log_to_both "# Initial System Setup"
    log_to_both "--------------------------------"

    # Create directory for compiled programs
    if [ ! -d "$COMPILED_PROGRAMS_DIR" ]; then
        run_silent mkdir -p "$COMPILED_PROGRAMS_DIR"
        print_status "create compiled programs directory"
    else
        print_status "create compiled programs directory" skip
    fi

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
    if [ ! -d "$SETUP_DIR/.git" ]; then
        rm -rf "$SETUP_DIR"
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
    # Core packages
    local packages_core=(
        curl
        gcc
        g++
        libclang-dev
        clang
        build-essential
        pkg-config
        stow
        cmake
        libssl-dev
        libcurl4-openssl-dev
        python3
        python3-dev
        python3-pip
        python3-numpy
        flatpak
        htop
        btop
        speedtest-cli
        net-tools
        screen
        unzip
        7zip
        keychain
        maim
        xclip
        xdotool
        rename
        transmission
        policykit-1-gnome
        network-manager-gnome
        openssh-server
        zsh
        tmux
        silversearcher-ag
        tree
        i3
        i3blocks
        pavucontrol
        pulsemixer
        feh
        dunst
        rofi
        picom
        polybar
        avahi-daemon
        avahi-utils
        iperf3
        aria2
        wireplumber
    )

    # Install all packages
    for pkg in "${packages_core[@]}"; do
        install_package "$pkg"
    done

    # Install fzf
    if [ ! -f "$HOME/bin/fzf" ]; then
        FZF_DIR="$COMPILED_PROGRAMS_DIR/fzf"
        run_silent bash -c 'git clone --depth 1 https://github.com/junegunn/fzf.git "$1"' -- "$FZF_DIR"
        run_silent bash -c '$1/install --no-key-bindings --no-completion --no-update-rc --no-bash --no-zsh --no-fish' -- "$FZF_DIR"
        run_silent mkdir -p "$HOME/bin"
        run_silent cp "$FZF_DIR/bin/fzf" "$HOME/bin/"
        print_status "install fzf"
    else
        print_status "install fzf" skip
    fi

    # Install brightnessctl
    if [ ! -x "$(command -v brightnessctl)" ]; then
        install_package "brightnessctl"
        run_silent sudo chmod +s /usr/bin/brightnessctl
        print_status "install brightnessctl"
    else
        print_status "install brightnessctl" skip
    fi

    # Install Neovim
    if [ ! -x "$(command -v nvim)" ]; then
        # Prerequisites
        install_package "ninja-build"
        install_package "gettext"
        # Neovim
        NEOVIM_DIR="$COMPILED_PROGRAMS_DIR/neovim"
        run_silent bash -c 'git clone https://github.com/neovim/neovim.git "$1"' -- "$NEOVIM_DIR"
        cd "$NEOVIM_DIR"
        run_silent git checkout stable
        run_silent make CMAKE_BUILD_TYPE=Release
        run_silent sudo make install
        cd - >/dev/null
        print_status "install neovim"
    else
        print_status "install neovim" skip
    fi

    # Configure flatpak
    if ! flatpak remotes | grep -q flathub; then
        run_silent flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        run_silent flatpak --user override --filesystem=~/.icons/:ro
        run_silent flatpak --user override --filesystem=~/.themes/:ro
        run_silent flatpak --user override --filesystem=~/.fonts/:ro
        run_silent flatpak --user override --filesystem=~/.cache/:ro
        run_silent bash -c 'flatpak --user override --filesystem="$1"/:ro' -- "$SETUP_DIR"
        run_silent flatpak --user override --filesystem=/usr/share/icons/:ro
        run_silent flatpak --user override --filesystem=/usr/share/themes/:ro
        run_silent flatpak --user override --filesystem=/usr/share/fonts/:ro
        print_status "configure flatpak"
    else
        print_status "configure flatpak" skip
    fi

    # Install Flatseal (Flatpak permissions manager)
    if ! flatpak list | grep -q com.github.tchx84.Flatseal; then
        run_silent flatpak install -y flathub com.github.tchx84.Flatseal
        print_status "install flatseal"
    else
        print_status "install flatseal" skip
    fi

    # Install Discord
    if ! flatpak list | grep -q com.discordapp.Discord; then
        run_silent flatpak install -y flathub com.discordapp.Discord
        run_silent flatpak override --user --env=XCURSOR_PATH= com.discordapp.Discord
        print_status "install discord"
    else
        # Ensure environment variables are set even if Discord is already installed
        run_silent flatpak override --user --env=XCURSOR_PATH= com.discordapp.Discord
        print_status "install discord" skip
    fi

    # Install Bolt (RS3 Launcher)
    if ! flatpak list | grep -q com.adamcake.Bolt; then
        run_silent flatpak install -y flathub com.adamcake.Bolt
        run_silent flatpak override --user --env=PULSE_LATENCY_MSEC=126 com.adamcake.Bolt
        print_status "install bolt"
    else
        # Ensure environment variables are set even if Bolt is already installed
        run_silent flatpak override --user --env=PULSE_LATENCY_MSEC=126 com.adamcake.Bolt
        print_status "install bolt" skip
    fi

    # Install Vibrant Linux - Saturation Manager
    if ! flatpak list | grep -q io.github.libvibrant.vibrantLinux; then
        run_silent flatpak install -y flathub io.github.libvibrant.vibrantLinux
        print_status "install vibrantLinux"
    else
        print_status "install vibrantLinux" skip
    fi

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
            {
                echo 'pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
                echo 'pref("clipboard.autocopy", false);'
                echo 'pref("middlemouse.paste", false);'
            } | run_silent sudo tee "$AUTOCONFIG_DIR/autoconfig.js"
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

        # Install 'greenclip'
        if [ ! -x "$(command -v greenclip)" ]; then
            GREENCLIP_VERSION="v4.2"
            run_silent wget -q "https://github.com/erebe/greenclip/releases/download/$GREENCLIP_VERSION/greenclip" -O "$HOME/bin/greenclip"
            run_silent chmod +x "$HOME/bin/greenclip"
            print_status "install greenclip"
        else
            print_status "install greenclip" skip
        fi

        # Install XMousePasteBlock
        if ! command -v xmousepasteblock &> /dev/null; then
            install_package "libev-dev"
            install_package "libx11-dev"
            install_package "libxtst-dev"
            install_package "libxi-dev"

            XMPB_DIR="$COMPILED_PROGRAMS_DIR/XMousePasteBlock"
            run_silent bash -c "git clone https://github.com/milaq/XMousePasteBlock.git \"$XMPB_DIR\""
            cd "$XMPB_DIR"
            run_silent make
            run_silent sudo make install
            cd - >/dev/null
            print_status "install xmousepasteblock"
        else
            print_status "install xmousepasteblock" skip
        fi

        # Install Google Chrome
        if ! is_installed "google-chrome-stable"; then
            run_silent wget -q "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -O "/tmp/google-chrome.deb"
            run_silent sudo dpkg -i "/tmp/google-chrome.deb" || run_silent sudo apt install -f -y
            rm -f "/tmp/google-chrome.deb"
            print_status "install google chrome"
        else
            print_status "install google chrome" skip
        fi

        # Install mpv
        install_package "mpv"

        # Install Obsidian (note-taking app)
        if [ ! -f "$HOME/bin/obsidian.AppImage" ]; then
            mkdir -p "$HOME/bin"
            OBSIDIAN_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep "browser_download_url.*AppImage\"" | grep -v "arm64" | head -1 | cut -d '"' -f 4)
            run_silent wget -q "$OBSIDIAN_URL" -O "$HOME/bin/obsidian.AppImage"
            run_silent chmod +x "$HOME/bin/obsidian.AppImage"
            # Create wrapper script with --no-sandbox flag
            cat > "$HOME/bin/obsidian" <<'EOF'
#!/bin/bash
exec "$HOME/bin/obsidian.AppImage" --no-sandbox "$@"
EOF
            run_silent chmod +x "$HOME/bin/obsidian"
            print_status "install obsidian"
        else
            print_status "install obsidian" skip
        fi

        # Setup VirtualHere Service
        if ! systemctl list-unit-files | grep -q "virtualhere.service"; then
            SERVICE_FILE="/etc/systemd/system/virtualhere.service"
            LOCAL_CONFIG="$HOME/.config/virtualhere/vhuit.ini"
            BIN_PATH="$HOME/bin/vhclientx86_64"
            cat <<EOL | sudo tee "$SERVICE_FILE" >/dev/null
[Unit]
Description=VirtualHere Client Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'exec sudo $BIN_PATH -c "$LOCAL_CONFIG"'
WorkingDirectory=$HOME
User=root
StandardOutput=journal
StandardError=journal
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL
            run_silent sudo chmod 644 "$SERVICE_FILE"
            run_silent sudo systemctl daemon-reload
            # run_silent sudo systemctl enable virtualhere.service
            # run_silent sudo systemctl start virtualhere.service
            print_status "virtualhere service setup"
        else
            print_status "virtualhere service setup" skip
        fi

        # Install Solaar (Logitech device manager)
        if ! is_installed "solaar"; then
            run_silent sudo add-apt-repository -y ppa:solaar-unifying/stable
            run_silent sudo apt update -y
            install_package "solaar"
        else
            print_status "install solaar" skip
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
        print_status "apply gnome-desktop settings"

        # Apply ibus settings
        run_silent dconf write /desktop/ibus/panel/show-icon-on-systray false
        run_silent dconf write /desktop/ibus/general/hotkey/triggers "@as []"
        print_status "apply ibus settings"

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

    # Install for Python package management
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

    # Install Node.js and npm via nvm
    if [ ! -x "$(command -v node)" ]; then
        # Check if nvm is already installed
        if [ ! -d "$HOME/.nvm" ]; then
            # Download and install nvm:
            run_silent bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash'
        else
            print_status "nvm already installed" skip
        fi

        # Source nvm in the current shell session
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        # Download and install Node.js (latest LTS version):
        run_silent bash -c 'source "$HOME/.nvm/nvm.sh" && nvm install --lts'

        # Verify the Node.js version:
        if run_silent bash -c 'source "$HOME/.nvm/nvm.sh" && node -v'; then
            print_status "install nodejs and npm"
        else
            print_status "install nodejs and npm"
            return 1
        fi
    else
        print_status "install nodejs and npm" skip
    fi

    # Install global npm packages
    local npm_packages=(
        "@google/gemini-cli"
        "opencode-ai"
        "@openai/codex"
        "@anthropic-ai/claude-code"
    )

    for pkg in "${npm_packages[@]}"; do
        if ! run_silent bash -c "source \"$HOME/.nvm/nvm.sh\" && npm list -g \"$pkg\" >/dev/null 2>&1"; then
            run_silent bash -c "source \"$HOME/.nvm/nvm.sh\" && npm install -g \"$pkg\""
            print_status "npm install -g $pkg"
        else
            print_status "npm install -g $pkg" skip
        fi
    done

    # Install go
    if [ ! -x "$(command -v go)" ]; then
        GO_VERSION="1.24.0"
        run_silent wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
        if [ -d "/usr/local/go" ]; then
            run_silent sudo rm -rf /usr/local/go
        fi
        run_silent sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        rm -rf /tmp/go.tar.gz
        print_status "install go"
    else
        print_status "install go" skip
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

    # Install Tailscale
    if is_installed "tailscale"; then
        print_status "install tailscale" skip
    else
        # Detect OS and Codename for Tailscale repo
        # We wrap this in a subshell/bash-c to handle variables cleanly
        run_silent bash -c '
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                TS_OS=$ID
                TS_CODENAME=$VERSION_CODENAME
            elif command -v lsb_release >/dev/null; then
                TS_OS=$(lsb_release -is | tr "[:upper:]" "[:lower:]")
                TS_CODENAME=$(lsb_release -cs)
            else
                TS_OS="ubuntu"
                TS_CODENAME="jammy"
            fi

            # Ensure strict "ubuntu" or "debian" mapping if needed, 
            # generally ID from os-release works for ubuntu/debian.
            
            curl -fsSL "https://pkgs.tailscale.com/stable/${TS_OS}/${TS_CODENAME}.noarmor.gpg" | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
            curl -fsSL "https://pkgs.tailscale.com/stable/${TS_OS}/${TS_CODENAME}.tailscale-keyring.list" | sudo tee /etc/apt/sources.list.d/tailscale.list
        '
        
        # Update apt after adding repo
        run_silent sudo apt update -y
        
        # Install tailscale
        install_package "tailscale"
    fi

    # Install cargo-update
    if ! $HOME/.cargo/bin/cargo install --list | grep -q "cargo-update"; then
        run_silent $HOME/.cargo/bin/cargo install cargo-update
        print_status "install cargo-update"
    else
        print_status "install cargo-update" skip
    fi

    # UV tool installs
    local uv_tools=(
        "netron"
        "smassh"
        "gdown"
        "huggingface_hub[cli]"
    )

    for tool in "${uv_tools[@]}"; do
        if ! $HOME/.local/bin/uv tool list | grep -q "^${tool%%\[*}"; then
            run_silent $HOME/.local/bin/uv tool install "$tool"
            print_status "uv install $tool"
        else
            print_status "uv install $tool" skip
        fi
    done

    # Install hf_transfer
    # Activate huggingface-hub venv and check if hf_transfer is installed
    if ! (source "$HOME/.local/share/uv/tools/huggingface-hub/bin/activate" && \
          "$HOME/.local/bin/uv" pip list | grep -q "hf-transfer" && \
          deactivate); then
        run_silent bash -c 'source "$HOME/.local/share/uv/tools/huggingface-hub/bin/activate" && \
            "$HOME/.local/bin/uv" pip install hf_transfer && \
            deactivate'
        print_status "uv install hf_transfer"
    else
        print_status "uv install hf_transfer" skip
    fi

    # Go installs
    local go_packages=(
        "github.com/charmbracelet/mods@latest"
        "github.com/charmbracelet/gum@latest"
        "github.com/charmbracelet/glow@latest"
        "github.com/jorgerojas26/lazysql@latest"
    )

    for pkg_url in "${go_packages[@]}"; do
        pkg_name=$(basename "$pkg_url" | cut -d'@' -f1)
        # Go installs binaries to $GOPATH/bin or $HOME/go/bin by default
        # We will check $HOME/go/bin as it's a common user-level location
        if [ ! -x "$HOME/go/bin/$pkg_name" ]; then
            run_silent /usr/local/go/bin/go install "$pkg_url"
            print_status "go install $pkg_name"
        else
            print_status "go install $pkg_name" skip
        fi
    done

    # Install GitHub CLI
    if ! command -v gh &> /dev/null; then
        run_silent bash -c '
            (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) && \
            sudo mkdir -p -m 755 /etc/apt/keyrings && \
            out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg && \
            cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
            sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
            sudo apt update && \
            sudo apt install gh -y
        '
        print_status "install github-cli"
    else
        print_status "install github-cli" skip
    fi

    # Install GitLab CLI
    if ! command -v glab &> /dev/null; then
        run_silent bash -c '
            curl -sSL "https://raw.githubusercontent.com/upciti/wakemeops/main/assets/install_repository" | sudo bash && \
            sudo apt update && \
            sudo apt install -y glab
        '
        print_status "install gitlab-cli"
    else
        print_status "install gitlab-cli" skip
    fi

    # Install lazygit
    if ! command -v lazygit &> /dev/null; then
        run_silent bash -c '
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '\''"tag_name": *"v\K[^"]*'\'') && \
            curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
            tar xf /tmp/lazygit.tar.gz -C /tmp lazygit && \
            sudo install /tmp/lazygit -D -t /usr/local/bin/ && \
            rm /tmp/lazygit /tmp/lazygit.tar.gz
        '
        print_status "install lazygit"
    else
        print_status "install lazygit" skip
    fi

    # Install AWS CLI
    # Overall status for core installation will be printed based on success/failure.
    if [ -x "/usr/local/bin/aws" ]; then
        print_status "aws cli core installation" skip
        log_to_file "AWS CLI already installed. Version: $(/usr/local/bin/aws --version 2>&1 || echo 'version check failed')"
    else
        AWS_CLI_TMP_DIR=$(mktemp -d)
        local aws_install_ok=false

        run_silent curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$AWS_CLI_TMP_DIR/awscliv2.zip"
        print_status "download aws cli"
        if [ $? -eq 0 ]; then
            run_silent unzip -q "$AWS_CLI_TMP_DIR/awscliv2.zip" -d "$AWS_CLI_TMP_DIR"
            print_status "unzip aws cli"
            if [ $? -eq 0 ]; then
                run_silent sudo "$AWS_CLI_TMP_DIR/aws/install" --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
                print_status "run aws cli installer"
                if [ $? -eq 0 ] && [ -x "/usr/local/bin/aws" ]; then
                    aws_install_ok=true
                    log_to_file "AWS CLI installed successfully. Version: $(/usr/local/bin/aws --version 2>&1 || echo 'version check failed')"
                else
                    log_to_file "AWS CLI installation failed or command not found after install."
                fi
            fi
        fi
        run_silent rm -rf "$AWS_CLI_TMP_DIR"
        print_status "cleanup aws cli temp files"

        if $aws_install_ok; then
            print_status "aws cli core installation"
        else
            print_status "aws cli core installation" 1 # Explicitly mark as failed if not ok
        fi
    fi

    # Configure S3 accelerate endpoint (if AWS CLI is available)
    if [ -x "/usr/local/bin/aws" ]; then
        local current_accelerate_setting
        # Ensure errors from `aws configure get` don't stop the script if `set -e` is active elsewhere.
        current_accelerate_setting=$(/usr/local/bin/aws configure get default.s3.use_accelerate_endpoint 2>/dev/null || echo "key_not_found")
        local get_status=$?

        # Proceed if key was not found (get_status != 0) or if value is not "true"
        if [ "$current_accelerate_setting" != "true" ]; then
            run_silent /usr/local/bin/aws configure set default.s3.use_accelerate_endpoint true
            print_status "configure aws s3 accelerate"
        else
            print_status "configure aws s3 accelerate" skip
        fi
    else
        log_to_file "AWS CLI not available, skipping S3 accelerate configuration."
    fi

    # Install ffmpeg and dev libraries
    local ffmpeg_packages=(
        ffmpeg
        libavformat-dev
        libavcodec-dev
        libavdevice-dev
        libavutil-dev
        libavfilter-dev
        libswscale-dev
        libswresample-dev
    )
    for pkg in "${ffmpeg_packages[@]}"; do
        install_package "$pkg"
    done

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
        gstreamer1.0-x
        gstreamer1.0-alsa
        gstreamer1.0-gl
        gstreamer1.0-gtk3
        gstreamer1.0-qt5
        gstreamer1.0-pulseaudio
    )
    for pkg in "${gstreamer_packages[@]}"; do
        install_package "$pkg"
    done

    # Install PostgreSQL and related dev packages
    local postgres_packages=(
        postgresql
        postgresql-contrib
        libpqxx-dev
    )
    for pkg in "${postgres_packages[@]}"; do
        install_package "$pkg"
    done

    # Install SQLite and related dev packages
    local sqlite_packages=(
        sqlite3
        libsqlite3-dev
    )
    for pkg in "${sqlite_packages[@]}"; do
        install_package "$pkg"
    done

    # Install VM tools
    local vm_packages=(
        libvirt-daemon-system 
        libvirt-clients 
        qemu-kvm 
        qemu-utils 
        virt-manager 
        ovmf
    )
    for pkg in "${vm_packages[@]}"; do
        install_package "$pkg"
    done
    run_silent sudo systemctl enable --now libvirtd

    # C++ Dev Libraries
    local cpp_dev_packages=(
        libboost-all-dev
        libomp-dev
        libzmq3-dev
        nlohmann-json3-dev
    )
    for pkg in "${cpp_dev_packages[@]}"; do
        install_package "$pkg"
    done

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
            GHOSTTY_DIR="$COMPILED_PROGRAMS_DIR/ghostty"
            # Clean up existing directory if necessary
            if [ -d "$GHOSTTY_DIR" ]; then
                run_silent rm -rf "$GHOSTTY_DIR"
            fi

            # Clone and build
            run_silent bash -c 'git clone https://github.com/ghostty-org/ghostty.git "$1" && \
                cd "$1" && \
                git checkout tags/v1.1.3 && \
                zig build -p "$HOME/.local" -Doptimize=ReleaseFast -Dgtk-adwaita=true' -- "$GHOSTTY_DIR"
            print_status "install ghostty"
        fi
    fi

    # Install kitty
    if is_wsl; then
        print_status "install kitty" "skip (WSL detected)"
    else
        if [ -x "$(command -v kitty)" ]; then
            print_status "install kitty" skip
        else
            run_silent bash -c 'curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin'
            # Symlink kitty binaries to .local/bin
            for bin in "$HOME/.local/kitty.app/bin/"*; do
                if [ -x "$bin" ]; then
                    make_link "$(realpath "$bin")" "$HOME/.local/bin/$(basename "$bin")" "kitty/$(basename "$bin")"
                fi
            done
            print_status "install kitty"
        fi
    fi

    # Install tpm (TmuxPluginManager)
    if [ ! -d "$HOME/.config/tmux/plugins/tpm" ]; then
        run_silent bash -c 'git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"'
        print_status "install tpm"
    else
        print_status "install tpm" skip
    fi

    # Install 'yazi' file manager
    if [ ! -x "$(command -v yazi)" ]; then
        run_silent $HOME/.cargo/bin/cargo install --locked yazi-fm yazi-cli
        print_status "install yazi"
    else
        print_status "install yazi" skip
    fi

    # Install 'bunny.yazi' plugin
    if [ -x "$HOME/.cargo/bin/ya" ]; then
        if [ ! -d "$HOME/.config/yazi/plugins/bunny.yazi" ]; then
            run_silent mkdir -p "$HOME/.config/yazi/plugins"
            run_silent git clone https://github.com/stelcodes/bunny.yazi.git "$HOME/.config/yazi/plugins/bunny.yazi"
            print_status "install yazi plugin bunny"
        else
            print_status "install yazi plugin bunny" skip
        fi

        # Install 'searchjump.yazi' plugin
        if [ ! -d "$HOME/.config/yazi/plugins/searchjump.yazi" ]; then
            run_silent mkdir -p "$HOME/.config/yazi/plugins"
            run_silent git clone https://github.com/zyoNoob/searchjump.yazi.git "$HOME/.config/yazi/plugins/searchjump.yazi"
            print_status "install yazi plugin searchjump"
        else
            print_status "install yazi plugin searchjump" skip
        fi
    fi

    # Install 'nyaa' torrent tui client
    if [ ! -x "$(command -v nyaa)" ]; then
        run_silent $HOME/.cargo/bin/cargo install --locked nyaa
        print_status "install nyaa"
    else
        print_status "install nyaa" skip
    fi

    # Install 'manga-tui' manga tui client
    if [ ! -x "$(command -v manga-tui)" ]; then
        install_package "libdbus-1-dev"
        run_silent $HOME/.cargo/bin/cargo install --locked manga-tui
        print_status "install manga-tui"
    else
        print_status "install manga-tui" skip
    fi

    # Install 'spotify-player' spotify tui client
    if [ ! -x "$(command -v spotify_player)" ]; then
        install_package "libasound2-dev"
        run_silent $HOME/.cargo/bin/cargo install spotify_player --features image,fzf,notify
        print_status "install spotify_player"
    else
        print_status "install spotify_player" skip
    fi

    # Install 'television' tui
    if [ ! -x "$(command -v tv)" ]; then
        run_silent $HOME/.cargo/bin/cargo install --locked television
        print_status "install television"
    else
        print_status "install television" skip
    fi

    # Install 'ripgrep'
    if [ ! -x "$(command -v rg)" ]; then
        run_silent $HOME/.cargo/bin/cargo install --locked ripgrep
        print_status "install ripgrep"
    else
        print_status "install ripgrep" skip
    fi

    # Install 'fd'
    if [ ! -x "$(command -v fd)" ]; then
        run_silent $HOME/.cargo/bin/cargo install --locked fd-find
        print_status "install fd"
    else
        print_status "install fd" skip
    fi

    # Install 'zoxide'
    if [ ! -x "$(command -v zoxide)" ]; then
        run_silent $HOME/.cargo/bin/cargo install --locked zoxide
        run_silent sudo ln -s $HOME/.cargo/bin/zoxide /usr/local/bin/zoxide
        print_status "install zoxide"
    else
        print_status "install zoxide" skip
    fi

    # Install 'bat'
    if [ ! -x "$(command -v bat)" ]; then
        run_silent $HOME/.cargo/bin/cargo install --locked bat
        run_silent $HOME/.cargo/bin/bat cache --build
        run_silent sudo ln -s $HOME/.cargo/bin/bat /usr/local/bin/bat
        print_status "install bat"
    else
        run_silent $HOME/.cargo/bin/bat cache --build
        print_status "install bat" skip
    fi

    # Install 'fastfetch'
    if ! command -v fastfetch &> /dev/null; then
        log_to_file "Attempting to install fastfetch..."
        if run_silent curl -sSLo /tmp/fastfetch.deb https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb; then
            log_to_file "Fastfetch downloaded successfully."
            if run_silent sudo dpkg -i /tmp/fastfetch.deb; then
                print_status "install fastfetch"
            else
                print_status "install fastfetch (dpkg failed)"
                log_to_file "Fastfetch installation failed (dpkg -i /tmp/fastfetch.deb)."
            fi
            run_silent rm /tmp/fastfetch.deb
            log_to_file "Cleaned up /tmp/fastfetch.deb."
        else
            print_status "install fastfetch (download failed)"
            log_to_file "Download of fastfetch.deb failed."
        fi
    else
        print_status "install fastfetch" skip
    fi

    # Install 'nvtop'
    if ! command -v nvtop &> /dev/null; then # Check if nvtop command exists
        # Check if running in WSL, if so, skip nvtop installation
        if is_wsl; then
            print_status "install nvtop" "skip (WSL detected, nvtop requires direct GPU access)"
        else
            install_package "libncurses-dev"
            install_package "libdrm-dev"
            install_package "libsystemd-dev" # Added libsystemd-dev as it's a common build dep
            NVTOP_DIR="$COMPILED_PROGRAMS_DIR/nvtop"
            run_silent bash -c "git clone https://github.com/Syllo/nvtop.git \"$NVTOP_DIR\""
            run_silent mkdir -p "$NVTOP_DIR/build" # Ensure build directory exists
            cd "$NVTOP_DIR/build"
            run_silent cmake .. -DNVIDIA_SUPPORT=ON -DAMDGPU_SUPPORT=ON -DINTEL_SUPPORT=ON
            run_silent make -j
            run_silent sudo make install
            cd - >/dev/null
            print_status "install nvtop"
        fi
    else
        print_status "install nvtop" skip
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
        "zsh-completions https://github.com/zsh-users/zsh-completions"
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
# Desktop Entry Creation for TUI Apps
# ========================================

create_tui_desktop_entries() {
    log_to_both "--------------------------------"
    log_to_both "# Creating Desktop Entries for TUI Apps"
    log_to_both "--------------------------------"

    # Create desktop entries directory
    DESKTOP_ENTRIES_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_ENTRIES_DIR"

    # Create custom icons directory
    CUSTOM_ICONS_DIR="$HOME/.local/share/icons/tui-apps"
    
    # Symlink custom icons from setup repo
    if [ -d "$SETUP_DIR/icons/tui-apps" ]; then
        if [ -L "$CUSTOM_ICONS_DIR" ]; then
            print_status "symlink tui app icons" skip
        else
            # Remove directory if it exists and is not a symlink
            if [ -d "$CUSTOM_ICONS_DIR" ]; then
                run_silent rm -rf "$CUSTOM_ICONS_DIR"
            fi
            run_silent ln -s "$SETUP_DIR/icons/tui-apps" "$CUSTOM_ICONS_DIR"
            print_status "symlink tui app icons"
        fi
    else
        print_status "symlink tui app icons" skip
    fi

    # Helper function to create a desktop entry
    create_desktop_entry() {
        local app_name=$1
        local exec_command=$2
        local display_name=$3
        local comment=$4
        local icon=$5
        local categories=$6
        local terminal=${7:-true}
        local desktop_file="$DESKTOP_ENTRIES_DIR/${app_name}.desktop"

        if [ -f "$desktop_file" ]; then
            print_status "create desktop entry for $app_name" skip
            return
        fi

        cat > "$desktop_file" <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=$display_name
Comment=$comment
Exec=$exec_command
Icon=$icon
Terminal=$terminal
Categories=$categories
EOL
        print_status "create desktop entry for $app_name"
    }

    # spotify_player
    if command -v spotify_player &> /dev/null; then
        create_desktop_entry "spotify_player" \
            "kitty -e spotify_player" \
            "Spotify Player" \
            "Terminal-based Spotify client" \
            "$CUSTOM_ICONS_DIR/spotify_player.svg" \
            "AudioVideo;Audio;Player;" \
            "false"
    fi

    # pulsemixer
    if command -v pulsemixer &> /dev/null; then
        create_desktop_entry "pulsemixer" \
            "kitty -e pulsemixer" \
            "PulseMixer" \
            "Terminal-based PulseAudio mixer" \
            "$CUSTOM_ICONS_DIR/pulsemixer.svg" \
            "AudioVideo;Audio;Mixer;" \
            "false"
    fi

    # yazi
    if command -v yazi &> /dev/null; then
        create_desktop_entry "yazi" \
            "kitty -e yazi" \
            "Yazi" \
            "Blazing fast terminal file manager" \
            "$CUSTOM_ICONS_DIR/yazi.svg" \
            "System;FileTools;FileManager;" \
            "false"
    fi

    # nyaa
    if command -v nyaa &> /dev/null; then
        create_desktop_entry "nyaa" \
            "kitty -e nyaa" \
            "Nyaa" \
            "Terminal-based torrent client for anime" \
            "$CUSTOM_ICONS_DIR/nyaa.svg" \
            "Network;FileTransfer;" \
            "false"
    fi

    # manga-tui
    if command -v manga-tui &> /dev/null; then
        create_desktop_entry "manga-tui" \
            "kitty -e manga-tui" \
            "Manga TUI" \
            "Terminal-based manga reader" \
            "$CUSTOM_ICONS_DIR/manga-tui.svg" \
            "Graphics;Viewer;" \
            "false"
    fi

    # fastfetch
    if command -v fastfetch &> /dev/null; then
        create_desktop_entry "fastfetch" \
            "kitty -e zsh -c \"fastfetch; echo; echo 'Press Enter to exit...'; read\"" \
            "Fastfetch" \
            "Fast system information tool" \
            "$CUSTOM_ICONS_DIR/fastfetch.svg" \
            "System;Utility;" \
            "false"
    fi

    # lazysql
    if command -v lazysql &> /dev/null; then
        create_desktop_entry "lazysql" \
            "kitty -e lazysql" \
            "LazySQL" \
            "Terminal-based SQL client" \
            "$CUSTOM_ICONS_DIR/lazysql.svg" \
            "Development;Database;" \
            "false"
    fi
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
    run_silent stow --no-folding --adopt --override=.* -v -t "$HOME" dotfiles
    print_status "stow dotfiles"

    # Stow utils/bin packages
    run_silent stow --no-folding --adopt --override=.* -v -t "$HOME" utils
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
    copy_file "$SETUP_DIR/config/.netrc" "$HOME/.netrc" "Github .netrc"

    # Copy .creds
    copy_file "$SETUP_DIR/config/.creds" "$HOME/.creds" "Credentials .creds"

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
    create_tui_desktop_entries
    final_setup
}

# Invoke the main function
main
