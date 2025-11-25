# Headless Server Setup

## Overview

This guide provides step-by-step instructions to set up a headless server for running [Sunshine](https://github.com/LizardByte/sunshine), enabling remote access to your desktop environment. A headless server operates without a monitor, keyboard, or mouse, allowing remote management.

---

## Prerequisites

Ensure you have the following before starting:

- A server running a compatible Linux distribution (e.g., **Ubuntu 24.04** or later)
- **SSH access** to the server
- A **non-root user** with `sudo` privileges
- A display connected to the server (for initial setup)
- A compatible graphics card (**NVIDIA**, **AMD**, or **Intel**) with the necessary drivers installed

---

## Setup Steps

### 1. Modify Hostname

Change your server's hostname to something recognizable:

```bash
sudo nano /etc/hostname
sudo nano /etc/hosts
```

> Example hostname: `zyon-ubuntu-server`

---

### 2. Configure SSH

Edit the SSH daemon configuration:

```bash
sudo nano /etc/ssh/sshd_config
```

- Find the line:

  ```
  UsePam yes
  ```

- Change it to:

  ```
  UsePam no
  ```

- Save and exit.

Restart the SSH service:

```bash
sudo systemctl restart sshd.service
```

Set up password-less SSH from your client computer.

---

### 3. Virtual Display Setup

**a. Generate X configuration:**

```bash
sudo nvidia-xconfig
sudo nano /etc/X11/xorg.conf
```

> Update this file using the reference `xorg.conf` provided in your reference directory.

**b. Generate Modelines for Custom Resolutions:**

To add custom resolutions (such as 4K@144Hz), you need to generate a modeline. You can use either the `cvt` or `gtf` utilities:

- **Using `cvt`:**

  ```bash
  cvt 3840 2160 144
  ```

  - For reduced blanking (required for high refresh rates and resolutions):

    ```bash
    cvt -r 3840 2160 144
    ```

  - **Note:** The `-r` (reduced blanking) option in `cvt` only supports refresh rates that are multiples of 60Hz (e.g., 60, 120, 180). For other refresh rates like 144Hz, use `gtf` or manually adjust the modeline.

- **Using `gtf`:**

  ```bash
  gtf 3840 2160 144
  ```

  - `gtf` supports arbitrary refresh rates and can be used if `cvt -r` does not generate a modeline for your desired refresh rate.

Copy the generated modeline and add it to your X configuration under the appropriate `Monitor` section.

**c. Update Xwrapper configuration:**

```bash
sudo nano /etc/X11/Xwrapper.config
```

**d. Update GDM3 custom configuration:**

```bash
sudo nano /etc/gdm3/custom.conf
```

> Enable autologin and set the user to your username.

**e. Update user session files:**

```bash
nano ~/.xsessionrc
```

> Disable monitor scripts.

```bash
nano ~/.Xresources
```

> Set DPI to 90 for 1080p resolution.

```bash
nano ~/.config/rofi/config.rasi
```

> Set DPI to 90 for 1080p resolution.

---

### 4. Input Device Permissions

Create a script to set input device permissions:

```bash
mkdir -p ~/scripts
echo "chown $(id -un):$(id -gn) /dev/uinput" > ~/scripts/sunshine-setup.sh
chmod +x ~/scripts/sunshine-setup.sh
```

Backup and edit the sudoers file:

```bash
sudo cp /etc/sudoers.d/${USER} /etc/sudoers.d/${USER}.bak
sudo visudo /etc/sudoers.d/${USER}
```

Add the following line (replace `${USER}` with your username):

```
${USER} ALL=(ALL:ALL) ALL, NOPASSWD: /home/${USER}/scripts/sunshine-setup.sh
```

---

### 5. Install Sunshine

Clone the Sunshine repository:

```bash
git clone https://github.com/lizardbyte/sunshine.git --recurse-submodules ~/workspace/compiled-programs/sunshine
```

Update the build script for Ubuntu 25.04 support:

```bash
# In scripts/linux_build.sh, add:
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

Build Sunshine:

```bash
cd ~/workspace/compiled-programs/sunshine
./scripts/linux_build.sh
```

> The build may fail due to CUDA and GCC discrepancies. Edit `build/cuda/targets/x86_64-linux/include/crt/math_functions.h` and add `noexcept (true)` to the `sinpi`, `cospi`, `sinpif`, and `cospif` functions.

Rebuild with sudo:

```bash
sudo ./scripts/linux_build.sh
```

Install the generated `.deb` package:

```bash
cd build/cmake_artifacts
sudo dpkg -i Sunshine*.deb
```

Install required dependencies:

```bash
sudo apt install miniupnpc libayatana-appindicator3-1
sudo apt --fix-broken install
```

---

### 6. Install Sunshine as a Service

Create a systemd user service:

```bash
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/sunshine.service
```

> Add the content from the reference service file.

Enable and start the service:

```bash
systemctl enable --user sunshine.service
systemctl start --user sunshine.service
```

---

**Your headless server is now ready for remote desktop access using Sunshine!**
