#!/bin/bash

# --------------------------------
# setup/setup_containers.sh
# --------------------------------

# Log file path
LOG_FILE="/tmp/setup_containers_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"

# Logging functions
timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

log_to_file() {
    echo "$(timestamp) | $*" >> "$LOG_FILE"
}

log_to_console() {
    echo -e "$*" >&1
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

is_installed() {
    if run_silent dpkg -s "$1"; then
        return 0
    else
        return 1
    fi
}

install_docker() {
    log_to_both "--------------------------------"
    log_to_both "# Installing Docker"
    log_to_both "--------------------------------"

    if is_installed "docker-ce"; then
        print_status "install docker" skip
        return 0
    fi

    # Install prerequisites
    run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
    print_status "install docker prerequisites"

    # Add Docker's official GPG key
    run_silent sudo install -m 0755 -d /etc/apt/keyrings
    run_silent sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    run_silent sudo chmod a+r /etc/apt/keyrings/docker.asc
    print_status "add docker gpg key"

    # Add the repository to Apt sources
    run_silent bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
    run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    print_status "add docker repository"

    # Install Docker packages
    if run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        print_status "install docker packages"
    else
        print_status "install docker packages"
        return 1
    fi

    # Add current user to docker group
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        run_silent sudo usermod -aG docker "$USER"
        print_status "add user to docker group"
        log_to_console "Note: You might need to log out and log back in for docker group changes to take effect."
    else
        print_status "add user to docker group" skip
    fi
}

uninstall_docker() {
    log_to_both "--------------------------------"
    log_to_both "# Uninstalling Docker"
    log_to_both "--------------------------------"

    if ! is_installed "docker-ce" && ! is_installed "docker-ce-cli"; then
        print_status "uninstall docker packages" skip
    else
        run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
        print_status "uninstall docker packages"
    fi

    if [ -d "/var/lib/docker" ] || [ -d "/var/lib/containerd" ]; then
        run_silent sudo rm -rf /var/lib/docker
        run_silent sudo rm -rf /var/lib/containerd
        print_status "remove docker data directories"
    else
        print_status "remove docker data directories" skip
    fi

    # Remove repository and keyring
    if [ -f "/etc/apt/sources.list.d/docker.list" ]; then
        run_silent sudo rm -f /etc/apt/sources.list.d/docker.list
        print_status "remove docker repository"
    else
        print_status "remove docker repository" skip
    fi

    if [ -f "/etc/apt/keyrings/docker.asc" ]; then
        run_silent sudo rm -f /etc/apt/keyrings/docker.asc
        print_status "remove docker gpg key"
    else
        print_status "remove docker gpg key" skip
    fi
}

install_nvidia_toolkit() {
    log_to_both "--------------------------------"
    log_to_both "# Installing NVIDIA Container Toolkit"
    log_to_both "--------------------------------"

    if is_installed "nvidia-container-toolkit"; then
        print_status "install nvidia container toolkit" skip
        return 0
    fi

    # Install prerequisites
    run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl gnupg2
    print_status "install nvidia toolkit prerequisites"

    # Add GPG key
    run_silent bash -c 'curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg'
    print_status "add nvidia toolkit gpg key"

    # Add repository
    run_silent bash -c 'curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null'
    print_status "add nvidia toolkit repository"

    # Install package
    run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    if run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit; then
        print_status "install nvidia-container-toolkit"
    else
        print_status "install nvidia-container-toolkit"
        return 1
    fi

    # Configure Docker runtime
    run_silent sudo nvidia-ctk runtime configure --runtime=docker
    run_silent sudo systemctl restart docker
    print_status "configure docker for nvidia runtime"
}

uninstall_nvidia_toolkit() {
    log_to_both "--------------------------------"
    log_to_both "# Uninstalling NVIDIA Container Toolkit"
    log_to_both "--------------------------------"

    if is_installed "nvidia-container-toolkit"; then
        run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y nvidia-container-toolkit
        print_status "uninstall nvidia-container-toolkit"
    else
        print_status "uninstall nvidia-container-toolkit" skip
    fi

    if [ -f "/etc/apt/sources.list.d/nvidia-container-toolkit.list" ]; then
        run_silent sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
        print_status "remove nvidia toolkit repository"
    else
        print_status "remove nvidia toolkit repository" skip
    fi

    if [ -f "/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg" ]; then
        run_silent sudo rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        print_status "remove nvidia toolkit gpg key"
    else
        print_status "remove nvidia toolkit gpg key" skip
    fi
}

install_podman() {
    log_to_both "--------------------------------"
    log_to_both "# Installing Podman"
    log_to_both "--------------------------------"

    if is_installed "podman" && is_installed "podman-compose"; then
        print_status "install podman" skip
    else
        run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
        if run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get install -y podman podman-compose; then
            print_status "install podman"
        else
            print_status "install podman"
            return 1
        fi
    fi
}

uninstall_podman() {
    log_to_both "--------------------------------"
    log_to_both "# Uninstalling Podman"
    log_to_both "--------------------------------"

    if is_installed "podman" || is_installed "podman-compose"; then
        if run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y podman podman-compose; then
            print_status "uninstall podman"
            run_silent sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
            print_status "autoremove podman dependencies"
        else
            print_status "uninstall podman"
            return 1
        fi
    else
        print_status "uninstall podman" skip
    fi
}

purge_containers() {
    log_to_both "--------------------------------"
    log_to_both "# Purging Container Resources"
    log_to_both "--------------------------------"

    if [ "$PURGE_ACTIVE" = "true" ]; then
        log_to_console "\e[31mWARNING: Nuclear option activated. Stopping all running containers...\e[0m"
        
        if is_installed "docker-ce"; then
            run_verbose bash -c 'docker stop $(docker ps -aq) 2>/dev/null || true'
        fi
        
        if is_installed "podman"; then
            run_verbose bash -c 'podman stop -a 2>/dev/null || true'
        fi
    fi

    if is_installed "docker-ce"; then
        log_to_console "Purging Docker resources..."
        run_verbose docker system prune -a --volumes -f
    else
        log_to_console "Docker not installed, skipping purge."
    fi

    if is_installed "podman"; then
        log_to_console "Purging Podman resources..."
        run_verbose podman system prune -a --volumes -f
    else
        log_to_console "Podman not installed, skipping purge."
    fi
}

check_status() {
    log_to_both "--------------------------------"
    log_to_both "# Container Status"
    log_to_both "--------------------------------"

    if is_installed "docker-ce"; then
        log_to_console "Docker: \e[32mInstalled\e[0m"
    else
        log_to_console "Docker: \e[31mNot Installed\e[0m"
    fi

    if is_installed "podman"; then
        log_to_console "Podman: \e[32mInstalled\e[0m"
    else
        log_to_console "Podman: \e[31mNot Installed\e[0m"
    fi

    if is_installed "podman-compose"; then
        log_to_console "Podman Compose: \e[32mInstalled\e[0m"
    else
        log_to_console "Podman Compose: \e[31mNot Installed\e[0m"
    fi

    if is_installed "nvidia-container-toolkit"; then
        log_to_console "NVIDIA Toolkit: \e[32mInstalled\e[0m"
    else
        log_to_console "NVIDIA Toolkit: \e[31mNot Installed\e[0m"
    fi
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --install      Install Docker, Podman, Podman Compose, and NVIDIA Toolkit"
    echo "  --uninstall    Uninstall Docker, Podman, Podman Compose, and NVIDIA Toolkit"
    echo "  --status       Check installation status"
    echo "  --purge        Purge all unused containers, networks, images, and volumes"
    echo "  --active       When used with --purge, stops ALL active containers before purging (Nuclear option)"
    echo "  --help         Show this help message"
}

# Argument parsing
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

ACTION=""
PURGE_ACTIVE="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)
            ACTION="install"
            shift
            ;;
        --uninstall)
            ACTION="uninstall"
            shift
            ;;
        --status)
            ACTION="status"
            shift
            ;;
        --purge)
            ACTION="purge"
            shift
            ;;
        --active)
            PURGE_ACTIVE="true"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ "$ACTION" = "install" ]; then
    install_docker
    install_nvidia_toolkit
    install_podman
elif [ "$ACTION" = "uninstall" ]; then
    uninstall_docker
    uninstall_nvidia_toolkit
    uninstall_podman
elif [ "$ACTION" = "status" ]; then
    check_status
elif [ "$ACTION" = "purge" ]; then
    purge_containers
fi

exit 0
