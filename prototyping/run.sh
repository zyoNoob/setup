#!/bin/bash

# Directory for storing compiled programs
COMPILED_PROGRAMS_DIR="$HOME/workspace/compiled-programs"

# Logging functions
LOG_FILE="/tmp/ghostty_install_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"

timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

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

    log_to_both "$output"
}

is_installed() {
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
        if run_silent sudo DEBIAN_FRONTEND=noninteractive apt install -y "$package"; then
            print_status "$action_name"
        else
            print_status "$action_name"
            return 1
        fi
    fi
}

# Function to install Ghostty
install_ghostty() {
    log_to_both "--------------------------------"
    log_to_both "# Installing Ghostty Terminal"
    log_to_both "--------------------------------"

    # Create directory for compiled programs
    if [ ! -d "$COMPILED_PROGRAMS_DIR" ]; then
        run_silent mkdir -p "$COMPILED_PROGRAMS_DIR"
        print_status "create compiled programs directory"
    else
        print_status "create compiled programs directory" skip
    fi

    # Install essential build tools
    run_silent sudo apt update -y
    print_status "update package list"

    # Install required packages
    install_package "git"
    install_package "curl"
    install_package "build-essential"
    install_package "libgtk-4-dev"
    install_package "libadwaita-1-dev"

    # Install Zig (required for building Ghostty)
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

    # Install Ghostty
    if [ -x "$(command -v ghostty)" ]; then
        print_status "install ghostty" skip
    else
        # Clone and build Ghostty
        GHOSTTY_DIR="$COMPILED_PROGRAMS_DIR/ghostty"
        # Clean up existing directory if necessary
        if [ -d "$GHOSTTY_DIR" ]; then
            run_silent rm -rf "$GHOSTTY_DIR"
        fi
        
        # Clone and build
        run_silent bash -c 'git clone https://github.com/ghostty-org/ghostty.git "$1" && \
            cd "$1" && \
            git checkout tags/v1.1.2 && \
            zig build -p "$HOME/.local" -Doptimize=ReleaseFast -Dgtk-adwaita=true' -- "$GHOSTTY_DIR"
        print_status "install ghostty"
    fi

    log_to_both "Installation complete. If successful, Ghostty is installed at $HOME/.local/bin/ghostty"
}

# Main function
main() {
    install_ghostty
}

# Run the main function
main