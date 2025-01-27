#!/bin/sh

# --------------------------------
# Status printing helper function
# --------------------------------
print_status() {
  local status=$?
  local message=$1
  local skip=$2
  local width=40

  if [ "$skip" = "skip" ]; then
    printf "%-${width}s \e[90mSKIPPED\e[0m\n" "$message"
  else
    if [ "$status" -eq 0 ]; then
      printf "%-${width}s \e[32mDONE\e[0m\n" "$message"
    else
      printf "%-${width}s \e[31mFAILED\e[0m\n" "$message"
    fi
  fi
}

# --------------------------------
# WSL check
# --------------------------------
is_wsl() {
    case "$(uname -r)" in
    *microsoft* ) return 0 ;; # WSL 2
    *Microsoft* ) return 0 ;; # WSL 1
    * ) return 1 ;;
    esac
}

# --------------------------------
# package helper functions
# --------------------------------
sudo apt update -y >/dev/null 2>&1
print_status "update package list"

is_installed() {
  [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" = "install ok installed" ]
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

# --------------------------------
# package setup
# --------------------------------
remove_package unattended-upgrades

install_package git
install_package git-lfs
install_package curl
install_package tree # Recursive directory listing command
install_package htop # Interactive process viewer
install_package fzf
install_package silversearcher-ag
install_package vim-gtk3
install_package g++
install_package build-essential
install_package zsh
install_package apt-transport-https
install_package speedtest-cli
install_package net-tools
install_package pkg-config
install_package screen
install_package unzip
install_package keychain


# Install VS Code only if not in WSL
if is_wsl; then
    print_status "install code" "skip (WSL detected)"
else
    if is_installed code; then
        print_status "install code" skip
    else
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg 2>/dev/null
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg 2>/dev/null
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null 2>&1
        rm -f packages.microsoft.gpg
        sudo apt update -qq >/dev/null 2>&1
        install_package code
    fi
fi

# Install ydiff
if [ -f "$HOME/bin/ydiff" ]; then
  print_status "install ydiff" skip
else
  mkdir -p "$HOME/bin"
  curl -L https://raw.github.com/ymattw/ydiff/master/ydiff.py > "$HOME/bin/ydiff" >/dev/null 2>&1
  chmod +x "$HOME/bin/ydiff"
  print_status "install ydiff"
fi

if [ -d "$HOME/.oh-my-zsh" ]; then
  print_status "install omz" skip
else
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null 2>&1
  print_status "install omz"
  # OMZ installation creates a default .zshrc
  rm -f "$HOME/.zshrc"
fi

# Install oh-my-zsh plugins if not already installed
plugins="fzf-tab https://github.com/Aloxaf/fzf-tab
zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
zsh-autocomplete https://github.com/marlonrichert/zsh-autocomplete.git
F-Sy-H https://github.com/z-shell/F-Sy-H.git
conda-zsh-completion https://github.com/conda-incubator/conda-zsh-completion"

# Save the original IFS
OLDIFS="$IFS"
# Set IFS to newline to correctly handle plugin entries
IFS="
"

for entry in $plugins; do
    plugin=$(echo "$entry" | awk '{print $1}')
    url=$(echo "$entry" | awk '{print $2}')
    plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin"

    if [ "$plugin" = "zsh-autocomplete" ]; then
        # Special handling for zsh-autocomplete
        if [ ! -d "$plugin_dir" ]; then
            # Replace this command with your customized one
            git clone -q --depth 1 -- "$url" "$plugin_dir"
            print_status "install $plugin"
        else
            print_status "install $plugin" skip
        fi
    else
        # Default handling for other plugins
        if [ ! -d "$plugin_dir" ]; then
            git clone -q "$url" "$plugin_dir"
            print_status "install $plugin"
        else
            print_status "install $plugin" skip
        fi
    fi
done

# Restore the original IFS
IFS="$OLDIFS"

# --------------------------------
# configs setup
# --------------------------------

# Directory of the setup repo
SETUP_REPO=$HOME/workspace/setup

# Extract branch from the download URL if available
SETUP_BRANCH=${SETUP_DOWNLOAD_URL##*/refs/heads/}
SETUP_BRANCH=${SETUP_BRANCH%%/setup.sh}
# Default to "main" if branch cannot be determined
SETUP_BRANCH=${SETUP_BRANCH:-main}

if [ ! -d $SETUP_REPO ]; then
    mkdir -p $SETUP_REPO
    git clone -b $SETUP_BRANCH https://github.com/zyoNoob/setup $SETUP_REPO >/dev/null 2>&1
    print_status "clone setup repo"
else
    print_status "clone setup repo" skip
fi

copy_file() {
  local src=$SETUP_REPO/config/$1
  local tgt=$HOME/$1

  if [ -e "$tgt" ]; then
    print_status "copy config $1" skip
  else
    cp $src $tgt
    print_status "copy config $1"
  fi
}

make_link() {
  local src=$SETUP_REPO/config/$1
  local tgt=$HOME/$1

  if [ -L "$tgt" ]; then
    print_status "make symlink $1" skip
  else
    ln -s $src $tgt >/dev/null 2>&1
    print_status "make symlink $1"
  fi
}

make_link .gitconfig
make_link .zshenv
make_link .vimrc
make_link .zshrc
copy_file .netrc

# Install Miniconda if not installed
if [ ! -d "$HOME/miniconda3" ]; then
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh >/dev/null 2>&1
    bash ~/miniconda.sh -b -p $HOME/miniconda3 >/dev/null 2>&1
    rm ~/miniconda.sh
    
    # Initialize Miniconda for zsh
    $HOME/miniconda3/bin/conda init zsh >/dev/null 2>&1
    
    # Disable auto-activation of base environment
    $HOME/miniconda3/bin/conda config --set auto_activate_base false >/dev/null 2>&1
    print_status "install miniconda"
else
    print_status "install miniconda" skip
fi

# Install Rust if not installed
if command -v rustc >/dev/null 2>&1; then
    print_status "install rust" skip
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >/dev/null 2>&1
    print_status "install rust"
fi

# Generate SSH key if it doesn't exist
if [ -f "$HOME/.ssh/id_rsa" ]; then
    print_status "generate ssh key" skip
else
    mkdir -p "$HOME/.ssh"
    ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N "" >/dev/null 2>&1
    chmod 600 "$HOME/.ssh/id_rsa"
    chmod 644 "$HOME/.ssh/id_rsa.pub"
    print_status "generate ssh key"
fi

# Switch to zsh
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)"
    print_status "switch to zsh"
else
    print_status "switch to zsh" skip
fi

# End if WSL else logout of session
if is_wsl; then
    print_status "setup complete"
else
    gnome-session-quit --no-prompt
fi