# Headless Server Setup

## Overview
This document outlines the steps to set up a headless server for running sunshine, enabling remote access to your desktop environment. A headless server is a computer that operates without a monitor, keyboard, or mouse, allowing you to manage it remotely.

## Prerequisites
Before you begin, ensure you have the following:

- A server running a compatible Linux distribution (e.g., Ubuntu 24.04 or later)
- SSH access to the server
- A non-root user with sudo privileges
- A display connected to the server (for initial setup)
- A compatible graphics card (NVIDIA, AMD, or Intel) with the necessary drivers installed

Steps to set up a headless server for running sunshine:

1. **Modify Hostname**
    - Change the hostname of your server to something recognizable. This can be done by editing the `/etc/hostname` file and updating the `/etc/hosts` file accordingly. In this case zyon-ubuntu-server

2. **Edit sshd_config**
    - Open the SSH daemon configuration file:
        ```bash
        sudo nano /etc/ssh/sshd_config
        ```
    - Find the line that says `UsePam yes` and change it to:
        ```bash
        UsePam no
        ```
    - Save the file and exit the editor.
    - Restart the SSH service to apply the changes:
        ```bash
        sudo systemctl restart sshd.service
        ```
    - Also configure password-less ssh for the the client computer.

3. **Virtual Display Setup**
    - Run `sudo nvidia-xconfig` to create a new X configuration file.
    - This will generate a file at `/etc/X11/xorg.conf`. Open this file with a text editor:
        ```bash
        sudo nano /etc/X11/xorg.conf
        ```
    - Update the file taking reference from xorg.conf file in this reference directory.
    - Update xwrapper.config file:
        ```bash
        sudo nano /etc/X11/Xwrapper.config
        ```
    - Update `/etc/gdm3/custom.conf` file:
        ```bash
        sudo nano /etc/gdm3/custom.conf
        ```
      enable autologin and set the user to your username.
    - Update `~/.xsessionrc` file:
        ```bash
        nano ~/.xsessionrc
        ```
      and disable the monitor scripts.
    - Update `~/.Xresources` file:
        ```bash
        nano ~/.Xresources
        ```
      and set the DPI to 90 for 1080p resolution.
    - Update `~/.config/rofi/config.rasi` file:
        ```bash
        nano ~/.config/rofi/config.rasi
        ```
      and set the DPI to 90 for 1080p resolution.

4. **Input Device permissions**
    - Create a new dir called `~/scripts` and run the following command:
        ```bash
        echo "chown $(id -un):$(id -gn) /dev/uinput" > ~/scripts/sunshine-setup.sh && \
        chmod +x ~/scripts/sunshine-setup.sh 
        ```
    - Backup sudoers file:
        ```bash
        sudo cp /etc/sudoers.d/${USER} /etc/sudoers.d/${USER}.bak
        ```
    - Edit the sudoers file:
        ```bash
        sudo visudo /etc/sudoers.d/${USER}
        ```
    - Add the following line to the file and replace `${USER}` with your actual username:
        ```bash
        ${USER} ALL=(ALL:ALL) ALL, NOPASSWD: /home/${USER}/scripts/sunshine-setup.sh
        ```
    - Save the file and exit the editor.

5. **Install Sunshine**
    - Download the latest version of sunshine from the official GitHub repository, clone in the `~/workspace/compiled-programs` directory:
        ```bash
        git clone https://github.com/lizardbyte/sunshine.git --recurse-submodules ~/workspace/compiled-programs/sunshine
        ```
    - Navigate to the sunshine directory and update the `scripts/linux_build.sh` file to support ubuntu25.04 and other dependency version:
        ```bash
        elif grep -q "Ubuntu 25.04" /etc/os-release; then
            distro="ubuntu"
            version="25.04"
            package_update_command="${sudo_cmd} apt-get update"
            package_install_command="${sudo_cmd} apt-get install -y"
            cuda_version="12.9.0"
            cuda_build="575.51.03"
            gcc_version="14"
            nvm_node=0
        ```
    - Build sunshine:
        ```bash
        cd ~/workspace/compiled-programs/sunshine
        ./scripts/linux_build.sh
        ```
    - Build will fail once because of CUDA and GCC discrepancy. So update the erronous file `build/cuda/targets/x86_64-linux/include/crt/math_functions.h` add `noexcept (true)` to the `sinpi`,`cospi`,`sinpif`,`cospif` functions.
    - Build again this time with `sudo`:
        ```bash
        cd ~/workspace/compiled-programs/sunshine
        sudo ./scripts/linux_build.sh
        ```
    - After the build is complete, navigate to the `build/cmake_artifacts` directory:
        ```bash
        sudo dpkg -i Sunshine*.deb
        ```
    - Install the dependencies that the deb file requires:
        ```bash
        sudo apt install miniupnpc libayatana-appindicator3-1
        sudo apt --fix-broken install
        ```

6. **Install Sunshine Service**
    - Create a systemd service file for Sunshine:
        ```bash
        mkdir -p ~/.config/systemd/user
        nano ~/.config/systemd/user/sunshine.service
        ```
    - Add the content from the reference file.
    - Enable and start the Sunshine service:
        ```bash
        systemctl enable --user sunshine.service
        systemctl start --user sunshine.service
        ```