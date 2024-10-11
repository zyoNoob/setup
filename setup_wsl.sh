#!/bin/sh

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

install_package git
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
SETUP_REPO=$HOME/workspace/setup

if [ ! -d $SETUP_REPO ]; then
    mkdir -p $SETUP_REPO
    git clone https://github.com/zyoNoob/setup $SETUP_REPO >/dev/null 2>&1
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
    print_status "install miniconda"
else
    print_status "install miniconda" skip
fi


if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)"
    print_status "switch to zsh"
else
    print_status "switch to zsh" skip
fi
