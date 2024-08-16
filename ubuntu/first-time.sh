#!/bin/bash

# Change to home directory
cd "$HOME"

# Create directories if they do not exist
mkdir -p workspace bin

cd workspace

# Update package list
sudo apt-get update

# Install necessary packages
sudo apt-get --assume-yes install \
  git \
  curl \
  zsh \
  fzf \
  silversearcher-ag \
  vim-gtk3 \
  g++ \
  gnome-tweak-tool \
  build-essential \
  htop \
  apt-transport-https \
  tree \
  speedtest-cli

echo "Packages installed"

# Install GPU drivers if available
sudo ubuntu-drivers install || echo "No GPU drivers available for installation"

echo "GPU Drivers Installed"

# Install VS Code
if ! command -v code &> /dev/null; then
    echo "Installing VS-Code"
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
    sudo apt update
    sudo apt install --assume-yes code
    echo "VS-Code Installed"
else
    echo "VS-Code is already installed"
fi

# Clone setup repository if not already present
if [ ! -d "setup" ]; then
    git clone https://github.com/zyoNoob/setup
else
    echo "setup repository already cloned"
fi

# Install ydiff
if [ ! -f "$HOME/bin/ydiff" ]; then
    curl -L https://raw.github.com/ymattw/ydiff/master/ydiff.py > "$HOME/bin/ydiff"
    chmod +x "$HOME/bin/ydiff"
    echo "ydiff installed"
else
    echo "ydiff is already installed"
fi

# Install oh-my-zsh if not installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    echo "oh-my-zsh installed"
else
    echo "oh-my-zsh is already installed"
fi

# Install oh-my-zsh plugins if not already installed
declare -A plugins=(
    ["fzf-tab"]="https://github.com/Aloxaf/fzf-tab"
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-autocomplete"]="https://github.com/marlonrichert/zsh-autocomplete.git"
    ["F-Sy-H"]="https://github.com/z-shell/F-Sy-H.git"
    ["conda-zsh-completion"]="https://github.com/conda-incubator/conda-zsh-completion"
)

for plugin in "${!plugins[@]}"; do
    plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin"

    if [ "$plugin" == "zsh-autocomplete" ]; then
        # Special handling for zsh-autocomplete
        if [ ! -d "$plugin_dir" ]; then
            # Replace this command with your customized one
            git clone --depth 1 -- ${plugins[$plugin]} "$plugin_dir"
            echo "$plugin plugin installed with custom command"
        else
            echo "$plugin plugin is already installed"
        fi
    else
        # Default handling for other plugins
        if [ ! -d "$plugin_dir" ]; then
            git clone ${plugins[$plugin]} "$plugin_dir"
            echo "$plugin plugin installed"
        else
            echo "$plugin plugin is already installed"
        fi
    fi
done

# Install Miniconda if not installed
if [ ! -d "$HOME/miniconda3" ]; then
    echo "Installing Miniconda"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
    bash ~/miniconda.sh -b -p $HOME/miniconda3
    rm ~/miniconda.sh
    echo "Miniconda installed"
    
    # Initialize Miniconda for zsh
    $HOME/miniconda3/bin/conda init zsh
    echo "Miniconda initialized for zsh"
    
else
    echo "Miniconda is already installed"
fi

# Change default shell to zsh if not already set
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)"
    echo "Default shell changed to zsh"
else
    echo "zsh is already the default shell"
fi
