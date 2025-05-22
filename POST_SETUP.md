# Post-Setup Configuration Checklist

This checklist outlines manual configuration steps that might be necessary after running the main `setup.sh` script.

## Authentication & Credentials

- [ ] **AWS CLI**: Run `aws configure` to set up your AWS Access Key ID, Secret Access Key, default region, and output format.
  ```bash
  aws configure
  ```
- [ ] **Git Global Configuration**: Set your Git username and email.
  ```bash
  git config --global user.name "Your Name"
  git config --global user.email "your.email@example.com"
  ```
- [ ] **SSH Key for Git Platforms**:
    - Add your public SSH key (`~/.ssh/id_rsa.pub`) to your GitHub, GitLab, or other Git hosting services.
    - Test the connection:
      ```bash
      ssh -T git@github.com
      # or
      ssh -T git@gitlab.com
      ```
- [ ] **Ngrok Authtoken**: Configure your Ngrok authtoken to enable features for your account.
  ```bash
  ngrok config add-authtoken YOUR_AUTHTOKEN
  ```
- [ ] **GitHub CLI Authentication**: Authenticate with GitHub.
  ```bash
  gh auth login
  ```
- [ ] **GitLab CLI Authentication**: Authenticate with GitLab.
  ```bash
  glab auth login
  ```
- [ ] **Spotify Player (spotify_player)**:
    - Launch `spotify_player`.
    - Follow the on-screen instructions to authenticate with your Spotify account. This usually involves opening a URL in your browser and granting permissions.

## Application & Service Logins

- [ ] **Browser Sync/Login**:
    - Open Firefox (or your preferred browser).
    - Sign in to your browser account to sync bookmarks, extensions, and settings.
- [ ] **VS Code Settings Sync**:
    - If you use VS Code's Settings Sync feature, ensure it's enabled and configured to sync with your GitHub or Microsoft account.
- [ ] **Discord**:
    - Launch Discord (Flatpak).
    - Log in with your Discord credentials.
- [ ] **Miniconda/Conda Environments**:
    - If you use Conda for managing Python environments, you might need to create or activate specific environments for your projects.
    - Example: `conda create --name myenv python=3.9`

## System & Desktop

- [ ] **VirtualHere Client**:
    - If you use VirtualHere, ensure the client is configured to connect to your VirtualHere server. The service should be running, but you may need to specify the server IP or hostname in `$HOME/.config/virtualhere/vhuit.ini` if not auto-discovered.
- [ ] **Ghostty/Kitty Terminal Configuration**:
    - Review and customize terminal emulator configurations if needed (e.g., `~/.config/ghostty/config`, `~/.config/kitty/kitty.conf`).
- [ ] **i3 Window Manager**:
    - If using i3, review keybindings and configuration in `~/.config/i3/config`. The setup script reloads i3, but further customization might be desired.
- [ ] **Rofi/Dunst/Polybar**:
    - Customize configurations for Rofi (application launcher), Dunst (notifications), and Polybar (status bar) as needed. Their configuration files are typically in `~/.config/rofi/`, `~/.config/dunst/`, and `~/.config/polybar/`.

## Development Tools

- [ ] **Neovim Configuration**:
    - Launch Neovim (`nvim`).
    - Your Neovim configuration (e.g., LazyVim, AstroNvim, or custom) might have post-install steps like running `:Lazy sync` or installing LSPs.
- [ ] **Cargo/Rust Crates**:
    - Some Rust tools installed via `cargo install` might require additional setup or API keys (e.g., if they interact with online services).
- [ ] **Go Tools**:
    - Similar to Cargo, Go tools installed via `go install` might need specific configuration.

## Other

- [ ] **Review Log File**: Check the setup log file (`/tmp/setup_*.log`) for any skipped items or potential issues that might require manual intervention.

This list is not exhaustive. Depending on your specific needs and the applications you use, other manual configurations might be necessary.
