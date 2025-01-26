# Setup

## Ubuntu

### Configurations

Running `./setup.sh` will create symlinks for some dotfiles present in `/configs`

The env var `SETUP_REPO` is set in `.zshenv` and may need modification.
Present value is `~/workspace/setup`

### Run Init Script 

```
# Stable Config
export SETUP_DOWNLOAD_URL="https://raw.githubusercontent.com/zyoNoob/setup/refs/heads/main/setup.sh" && wget -qO- $SETUP_DOWNLOAD_URL | sh

# Dev Config
export SETUP_DOWNLOAD_URL="https://raw.githubusercontent.com/zyoNoob/setup/refs/heads/dev/setup.sh" && wget -qO- $SETUP_DOWNLOAD_URL | sh
```

### Terminal

In order to edit terminal settings through config:
```
# Load config to a text file
dconf dump /org/gnome/terminal/ > terminal.conf
# Apply config
cat terminal.conf | dconf load /org/gnome/terminal/
```

Note: Color scheme for GNOME is generated from standard light theme in the following way:
  - 16 colors are in order: black, red, green, yellow, blue, purple, cyan, white (then their bright variants)
  - these are then stored in the `palette` array
  - Here are the derived values from xv3 light scheme
  - `palette=['rgb(20,24,26)', 'rgb(166,37,36)', 'rgb(47,117,0)', 'rgb(176,137,4)', 'rgb(30,101,153)', 'rgb(113,25,128)', 'rgb(30,115,108)', 'rgb(128,125,114)', 'rgb(7,63,77)', 'rgb(222,51,48)', 'rgb(66,166,0)', 'rgb(219,171,5)', 'rgb(35,119,181)', 'rgb(169,37,191)', 'rgb(43,166,156)', 'rgb(166,161,149)']`


### Misc stuff

- Fonts:
    - Download and copy .ttf to ~/.local/share/fonts

- To hide the trash icon
  `gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false`

- For tex, look at install instructions on [tex live official website](https://tug.org/texlive/quickinstall.html#running)

***
