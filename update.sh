#!/bin/bash

# --------------------------------
# setup/update.sh
# --------------------------------

# Log file path
LOG_FILE="/tmp/update_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"

# Make sure user-installed binaries are in PATH
export PATH="$HOME/bin:$HOME/.local/bin:$HOME/go/bin:$HOME/.cargo/bin:/usr/local/go/bin:/usr/local/bin:$PATH"

# Timestamp helper
timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

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

    output=$("$@" 2>&1)
    exit_status=$?

    log_to_file "Command: $cmd"
    log_to_file "Output: $output"

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

    if [ -n "$skip" ]; then
        local skip_label="SKIPPED"
        if [[ "$skip" =~ ^skip\ \((.*)\)$ ]]; then
            skip_label="SKIPPED (${BASH_REMATCH[1]})"
        fi
        output=$(printf "%s | %-${width}s \e[90m%s\e[0m" "$time_stamp" "$message" "$skip_label")
    else
        if [ "$status" -eq 0 ]; then
            output=$(printf "%s | %-${width}s \e[32mDONE\e[0m" "$time_stamp" "$message")
        else
            output=$(printf "%s | %-${width}s \e[31mFAILED\e[0m" "$time_stamp" "$message")
            log_to_console "See full log at: $LOG_FILE"
        fi
    fi

    log_to_both "$output"
}

# Environment detection
is_wsl() {
    case "$(uname -r)" in
    *microsoft* ) return 0 ;; # WSL 2
    *Microsoft* ) return 0 ;; # WSL 1
    * ) return 1 ;;
    esac
}

_IS_SERVER_CACHED=""
is_server() {
    if [ -n "$_IS_SERVER_CACHED" ]; then
        return "$_IS_SERVER_CACHED"
    fi
    local pkg
    for pkg in ubuntu-desktop ubuntu-desktop-minimal kubuntu-desktop xubuntu-desktop lubuntu-desktop; do
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            _IS_SERVER_CACHED=1; return 1
        fi
    done
    for pkg in xserver-xorg-core xwayland; do
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            _IS_SERVER_CACHED=1; return 1
        fi
    done
    _IS_SERVER_CACHED=0; return 0
}

# Setup directories
SETUP_DIR="$HOME/workspace/setup"
COMPILED_PROGRAMS_DIR="$HOME/workspace/compiled-programs"

setup_nvidia_pinning() {
    log_to_both "# NVIDIA Driver Pinning Configuration"
    
    if is_wsl; then
        print_status "nvidia driver pinning" "skip (WSL detected)"
        return
    fi

    # Check if any nvidia driver package is installed
    local nvidia_ver
    nvidia_ver=$(dpkg-query -W -f='${Version}\n' 'nvidia-*' 'libnvidia-*' 2>/dev/null | grep -E "^[0-9]" | head -n 1)
    
    if [ -z "$nvidia_ver" ]; then
        print_status "nvidia driver pinning" "skip (no nvidia driver detected)"
        return
    fi
    
    local nvidia_major
    nvidia_major=$(echo "$nvidia_ver" | cut -d'.' -f1)
    
    if [[ ! "$nvidia_major" =~ ^[0-9]+$ ]]; then
        print_status "nvidia driver pinning" "skip (could not parse driver major version)"
        return
    fi
    
    local pin_file="/etc/apt/preferences.d/nvidia-$nvidia_major"
    
    if [ -f "$pin_file" ]; then
        print_status "nvidia driver pinning (branch $nvidia_major)" skip
    else
        # Remove any other nvidia-* pin files in preferences.d to avoid conflicts
        run_silent sudo rm -f /etc/apt/preferences.d/nvidia-[0-9]*
        
        # Create the new pin file
        run_silent sudo tee "$pin_file" > /dev/null <<EOL
Package: nvidia*
Pin: version ${nvidia_major}.*
Pin-Priority: 1001

Package: libnvidia*
Pin: version ${nvidia_major}.*
Pin-Priority: 1001

Package: xserver-xorg-video-nvidia*
Pin: version ${nvidia_major}.*
Pin-Priority: 1001

Package: libxnvctrl*
Pin: version ${nvidia_major}.*
Pin-Priority: 1001
EOL
        print_status "nvidia driver pinning (branch $nvidia_major)"
    fi
}


handle_nvidia_driver_update() {
    log_to_both "--------------------------------"
    log_to_both "# Checking NVIDIA Driver Upgrade/Downgrade"
    log_to_both "--------------------------------"

    if is_wsl; then
        return
    fi

    # Check if any nvidia driver is currently installed
    local nvidia_ver
    nvidia_ver=$(dpkg-query -W -f='${Version}\n' 'nvidia-*' 'libnvidia-*' 2>/dev/null | grep -E "^[0-9]" | head -n 1)

    if [ -z "$nvidia_ver" ]; then
        return
    fi

    local nvidia_major
    nvidia_major=$(echo "$nvidia_ver" | cut -d'.' -f1)

    if [[ ! "$nvidia_major" =~ ^[0-9]+$ ]]; then
        return
    fi

    # Check if open-source or proprietary driver is installed
    local is_open_driver=false
    if dpkg -l | grep -E '^ii  nvidia-driver-.*-open|^ii  nvidia-open' &>/dev/null; then
        is_open_driver=true
    fi

    # Find available driver branches in repositories
    local available_branches
    if $is_open_driver; then
        available_branches=$(apt-cache search --names-only "^nvidia-driver-[0-9]+-open$" | grep -oE '[0-9]+' | sort -un)
    else
        available_branches=$(apt-cache search --names-only "^nvidia-driver-[0-9]+$" | grep -oE '[0-9]+' | sort -un)
    fi

    # Check if there are other branches available besides current
    local has_other_branches=false
    for b in $available_branches; do
        if [ "$b" -ne "$nvidia_major" ]; then
            has_other_branches=true
            break
        fi
    done

    if ! $has_other_branches; then
        log_to_both "NVIDIA driver branch $nvidia_major is the only available branch in the repository."
        return
    fi

    # Make sure gum is available
    local gum_cmd="gum"
    if ! command -v gum &>/dev/null; then
        if [ -x "$HOME/go/bin/gum" ]; then
            gum_cmd="$HOME/go/bin/gum"
        else
            gum_cmd=""
        fi
    fi

    if [ -n "$gum_cmd" ]; then
        log_to_console "NVIDIA GPU driver branch configuration (Current branch: $nvidia_major)."
        if "$gum_cmd" confirm "Would you like to change (upgrade/downgrade) your NVIDIA driver branch?"; then
            # Construct choices list (sorting branches)
            local choices=""
            for b in $available_branches; do
                if [ "$b" -eq "$nvidia_major" ]; then
                    choices="$choices\n$b (current)"
                elif [ "$b" -gt "$nvidia_major" ]; then
                    choices="$choices\n$b (upgrade)"
                else
                    choices="$choices\n$b (downgrade)"
                fi
            done
            choices=$(echo -e "$choices" | sed '/^$/d')

            local chosen_choice
            chosen_choice=$(echo -e "$choices" | "$gum_cmd" choose --header="Select NVIDIA driver branch:")
            
            if [ -n "$chosen_choice" ]; then
                local chosen_branch
                chosen_branch=$(echo "$chosen_choice" | grep -oE '[0-9]+')
                
                if [ -n "$chosen_branch" ] && [ "$chosen_branch" -ne "$nvidia_major" ]; then
                    local target_package
                    if $is_open_driver; then
                        target_package="nvidia-driver-${chosen_branch}-open"
                    else
                        target_package="nvidia-driver-${chosen_branch}"
                    fi

                    local clean_install=false
                    if "$gum_cmd" confirm "Perform a clean installation (purge existing NVIDIA packages and configs first)?"; then
                        clean_install=true
                    fi

                    if [ "$chosen_branch" -lt "$nvidia_major" ]; then
                        log_to_both "WARNING: Downgrading NVIDIA driver branch from $nvidia_major to $chosen_branch..."
                    else
                        log_to_both "Updating NVIDIA driver to branch $chosen_branch ($target_package)..."
                    fi

                    if $clean_install; then
                        log_to_both "Purging existing NVIDIA driver packages for a clean install..."
                        run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y '*nvidia*' '*libnvidia*'
                        run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
                        print_status "purge old nvidia packages"
                    fi
                    
                    # Update pin file to the new branch
                    run_silent sudo rm -f /etc/apt/preferences.d/nvidia-*
                    run_silent sudo tee "/etc/apt/preferences.d/nvidia-$chosen_branch" > /dev/null <<EOL
Package: nvidia*
Pin: version ${chosen_branch}.*
Pin-Priority: 1001

Package: libnvidia*
Pin: version ${chosen_branch}.*
Pin-Priority: 1001

Package: xserver-xorg-video-nvidia*
Pin: version ${chosen_branch}.*
Pin-Priority: 1001

Package: libxnvctrl*
Pin: version ${chosen_branch}.*
Pin-Priority: 1001
EOL

                    if $clean_install; then
                        log_to_both "Updating package lists after purge..."
                        run_silent sudo apt-get update
                    fi

                    # Install/downgrade driver package
                    local install_cmd
                    if command -v apt-fast &>/dev/null; then
                        install_cmd="sudo DEBIAN_FRONTEND=noninteractive apt-fast install -y --allow-downgrades"
                    else
                        install_cmd="sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades"
                    fi

                    if run_silent $install_cmd "$target_package"; then
                        print_status "nvidia driver branch change to $chosen_branch"
                    else
                        print_status "nvidia driver branch change to $chosen_branch"
                    fi
                else
                    log_to_both "NVIDIA driver branch change canceled or kept at current."
                fi
            fi
        fi
    else
        log_to_both "Gum CLI not found. Skipping interactive NVIDIA driver branch selection."
    fi
}

main() {
    log_to_both "========================================"
    log_to_both "Starting System and Package Updates..."
    log_to_both "========================================"

    # 1. Nvidia Driver Pinning (First Priority)
    setup_nvidia_pinning

    # Ensure any legacy dev pinning file is removed
    if [ -f "/etc/apt/preferences.d/nvidia-dev-libraries" ]; then
        run_silent sudo rm -f /etc/apt/preferences.d/nvidia-dev-libraries
    fi

    # 2. System apt package update
    log_to_both "# Updating APT package lists..."
    if run_silent sudo apt update -y; then
        print_status "apt update"
    else
        print_status "apt update"
    fi

    # Interactive Nvidia Driver branch upgrade check (if repo is updated)
    handle_nvidia_driver_update

    # 3. Update Non-APT Packages installed via setup script
    log_to_both "--------------------------------"
    log_to_both "# Updating Installed Applications"
    log_to_both "--------------------------------"

    # FZF
    local fzf_dir="$COMPILED_PROGRAMS_DIR/fzf"
    if [ -d "$fzf_dir" ]; then
        log_to_both "Updating FZF..."
        (
            cd "$fzf_dir" && \
            run_silent git stash && \
            run_silent git fetch origin && \
            run_silent git checkout master && \
            run_silent git reset --hard origin/master && \
            run_silent ./install --no-key-bindings --no-completion --no-update-rc --no-bash --no-zsh --no-fish && \
            run_silent cp bin/fzf "$HOME/bin/"
        )
        print_status "update fzf"
    else
        print_status "update fzf" "skip (not installed)"
    fi

    # Neovim
    local nvim_dir="$COMPILED_PROGRAMS_DIR/neovim"
    if [ -d "$nvim_dir" ] && command -v nvim &>/dev/null; then
        log_to_both "Updating Neovim..."
        (
            cd "$nvim_dir" && \
            run_silent git stash && \
            run_silent git checkout master && \
            run_silent git fetch origin --tags -f && \
            run_silent git checkout stable && \
            run_silent make CMAKE_BUILD_TYPE=Release && \
            run_silent sudo make install
        )
        print_status "update neovim"
    else
        print_status "update neovim" "skip (not installed)"
    fi

    # Miniconda
    if [ -d "$HOME/miniconda3" ]; then
        log_to_both "Updating Miniconda..."
        # Accept Terms of Service if required
        if "$HOME/miniconda3/bin/conda" help tos &>/dev/null; then
            run_silent "$HOME/miniconda3/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
            run_silent "$HOME/miniconda3/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
        fi
        if run_silent "$HOME/miniconda3/bin/conda" update -n base -c defaults conda -y; then
            print_status "update miniconda"
        else
            print_status "update miniconda"
        fi
    else
        print_status "update miniconda" "skip (not installed)"
    fi

    # Python UV tools
    if command -v uv &>/dev/null; then
        log_to_both "Updating UV tools..."
        if run_silent uv tool upgrade --all; then
            print_status "update uv tools"
        else
            print_status "update uv tools"
        fi
    else
        print_status "update uv tools" "skip (not installed)"
    fi

    # Rust
    if command -v rustup &>/dev/null; then
        log_to_both "Updating Rust..."
        if run_silent rustup update; then
            print_status "update rust"
        else
            print_status "update rust"
        fi
        
        # Cargo packages via cargo-update
        if command -v cargo &>/dev/null && cargo install --list | grep -q "cargo-update"; then
            log_to_both "Updating Cargo packages..."
            # Query which packages need updates
            local cargo_upgrades
            cargo_upgrades=$(cargo install-update -l 2>/dev/null | awk '$NF == "Yes" {print $1}' | grep -Ev '^(yazi-fm|yazi-cli)$' | tr '\n' ' ')
            
            local cargo_ok=true
            if [ -n "$cargo_upgrades" ]; then
                if ! run_silent cargo install-update $cargo_upgrades; then
                    cargo_ok=false
                fi
            fi
            
            # Update Yazi via yazi-build if needed
            if cargo install-update -l 2>/dev/null | grep -E '^(yazi-fm|yazi-cli)\s+' | grep -q 'Yes$'; then
                log_to_both "Updating Yazi file manager..."
                if ! run_silent cargo install --locked yazi-build; then
                    cargo_ok=false
                fi
            fi
            
            if $cargo_ok; then
                print_status "update cargo packages"
            else
                print_status "update cargo packages"
            fi
        fi
    else
        print_status "update rust" "skip (not installed)"
    fi

    # Node.js and global npm packages via NVM
    if [ -d "$HOME/.nvm" ]; then
        log_to_both "Updating Node.js (NVM)..."
        (
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            if run_silent nvm install --lts --reinstall-packages-from=node && \
               run_silent nvm alias default 'lts/*' && \
               run_silent npm update -g; then
                exit 0
            else
                exit 1
            fi
        )
        print_status "update nodejs and global packages"
    else
        print_status "update nodejs and global packages" "skip (not installed)"
    fi

    # Claude Code
    if command -v claude &>/dev/null; then
        log_to_both "Updating Claude Code..."
        if run_silent bash -c "curl -fsSL https://claude.ai/install.sh | bash"; then
            print_status "update claude code"
        else
            print_status "update claude code"
        fi
    else
        print_status "update claude code" "skip (not installed)"
    fi

    # Antigravity CLI
    if command -v agy &>/dev/null || command -v antigravity &>/dev/null; then
        log_to_both "Updating Antigravity CLI (agy)..."
        if run_silent bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash"; then
            print_status "update antigravity-cli"
        else
            print_status "update antigravity-cli"
        fi
    else
        print_status "update antigravity-cli" "skip (not installed)"
    fi

    # Go packages
    if [ -x "/usr/local/go/bin/go" ]; then
        log_to_both "Updating Go packages..."
        local go_packages=(
            "github.com/charmbracelet/mods@latest"
            "github.com/charmbracelet/gum@latest"
            "github.com/charmbracelet/glow@latest"
            "github.com/jorgerojas26/lazysql@latest"
        )
        for pkg_url in "${go_packages[@]}"; do
            local pkg_name
            pkg_name=$(basename "$pkg_url" | cut -d'@' -f1)
            if run_silent /usr/local/go/bin/go install "$pkg_url"; then
                print_status "update go package $pkg_name"
            else
                print_status "update go package $pkg_name"
            fi
        done
    else
        print_status "update go packages" "skip (not installed)"
    fi

    # Lazygit
    if command -v lazygit &>/dev/null; then
        log_to_both "Updating Lazygit..."
        local lazygit_ver
        lazygit_ver=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*')
        if [ -n "$lazygit_ver" ]; then
            if run_silent curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${lazygit_ver}/lazygit_${lazygit_ver}_Linux_x86_64.tar.gz" && \
               run_silent tar xf /tmp/lazygit.tar.gz -C /tmp lazygit && \
               run_silent sudo install /tmp/lazygit -D -t /usr/local/bin/ && \
               run_silent rm -f /tmp/lazygit /tmp/lazygit.tar.gz; then
                print_status "update lazygit (to v$lazygit_ver)"
            else
                print_status "update lazygit"
            fi
        else
            print_status "update lazygit"
        fi
    else
        print_status "update lazygit" "skip (not installed)"
    fi

    # ydiff
    if [ -f "$HOME/bin/ydiff" ]; then
        log_to_both "Updating ydiff..."
        if run_silent curl -L https://raw.github.com/ymattw/ydiff/master/ydiff.py -o "$HOME/bin/ydiff" && \
           run_silent chmod +x "$HOME/bin/ydiff"; then
            print_status "update ydiff"
        else
            print_status "update ydiff"
        fi
    else
        print_status "update ydiff" "skip (not installed)"
    fi

    # AWS CLI
    if [ -x "/usr/local/bin/aws" ]; then
        log_to_both "Updating AWS CLI..."
        local aws_tmp
        aws_tmp=$(mktemp -d)
        if run_silent curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$aws_tmp/awscliv2.zip" && \
           run_silent unzip -q "$aws_tmp/awscliv2.zip" -d "$aws_tmp" && \
           run_silent sudo "$aws_tmp/aws/install" --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update; then
            print_status "update aws cli"
        else
            print_status "update aws cli"
        fi
        run_silent rm -rf "$aws_tmp"
    else
        print_status "update aws cli" "skip (not installed)"
    fi

    # Flatpak packages
    if command -v flatpak &>/dev/null; then
        log_to_both "Updating Flatpak packages..."
        if run_silent flatpak update -y; then
            print_status "update flatpak packages"
        else
            print_status "update flatpak packages"
        fi
    else
        print_status "update flatpak packages" "skip (not installed)"
    fi

    # 4. Selective APT upgrade using Gum
    log_to_both "--------------------------------"
    log_to_both "# Selective System Packages Upgrade"
    log_to_both "--------------------------------"

    # Make sure gum is available
    local gum_cmd="gum"
    if ! command -v gum &>/dev/null; then
        if [ -x "$HOME/go/bin/gum" ]; then
            gum_cmd="$HOME/go/bin/gum"
        else
            gum_cmd=""
        fi
    fi

    local upgradable_list
    upgradable_list=$(apt list --upgradable 2>/dev/null | grep -E '^[a-zA-Z0-9.+_-]+/[a-zA-Z0-9.+_-]+' | cut -d'/' -f1 | grep -Ev 'cuda|cudnn|tensorrt|nvinfer|nvparsers|nvonnxparser|nvidia|libxnvctrl')

    if [ -n "$upgradable_list" ]; then
        if [ -n "$gum_cmd" ]; then
            log_to_console "The following packages have updates available."
            log_to_console "Select which ones you want to update (SPACE to select/deselect, ENTER to confirm):"
            
            local selected_packages
            selected_packages=$(echo "$upgradable_list" | "$gum_cmd" choose --no-limit --selected="*" --header="Select packages to upgrade:")
            
            if [ -n "$selected_packages" ]; then
                local packages_to_upgrade
                packages_to_upgrade=$(echo "$selected_packages" | tr '\n' ' ')
                log_to_both "Upgrading packages: $packages_to_upgrade"
                
                if command -v apt-fast &>/dev/null; then
                    sudo DEBIAN_FRONTEND=noninteractive apt-fast install -y --only-upgrade $packages_to_upgrade
                else
                    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade $packages_to_upgrade
                fi
                print_status "upgrade selected packages"
            else
                log_to_both "No packages selected for upgrade."
            fi
        else
            log_to_both "Gum CLI not found. Defaulting to upgrading all packages via apt-fast/apt-get."
            if command -v apt-fast &>/dev/null; then
                sudo apt-fast upgrade -y
            else
                sudo apt-get upgrade -y
            fi
            print_status "upgrade all packages"
        fi
    else
        log_to_both "All system packages are up to date."
    fi

    log_to_both "========================================"
    log_to_both "Update complete! Log file: $LOG_FILE"
    log_to_both "========================================"
}

main "$@"
