# TODO List

## Table of Contents
- [TODO](#todo)
- [REJECTED / DISCARDED](#rejected--discarded)

---

## TODO
- [ ] FULL RETRUCTURE OF INSTALLATION SCRIPT
    - [ ] Explore what is the best approach to install all the programs
    - [ ] Rust using ratatui might be a good aproach.

- [ ] cycle through TUIs in this repo -> https://github.com/rothgar/awesome-tuis?tab=readme-ov-file
- [ ] ffmpeg - download prebuilt and link
    - [ ] source https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl-shared.tar.xz
    - [ ] sudo ln -s /path/to/ffmpeg-build/bin/* /usr/local/bin/
    - [ ] sudo ln -s /path/to/ffmpeg-build/lib/* /usr/local/lib/
    - [ ] sudo ldconfig
    - [ ] sudo ln -s /path/to/ffmpeg-build/include /usr/local/include/ffmpeg
    - [ ] sudo ln -s /path/to/ffmpeg-build/lib/pkgconfig/ffmpeg.pc /usr/local/lib/pkgconfig/ffmpeg.pc
    - [ ] sudo ln -s /path/to/ffmpeg-build/man /usr/local/share/man
    - [ ] sudo find /usr/local -xtype l -delete (removal of symlinks for uninstallation)
- [ ] samba configuration
    - [ ] sudo apt install samba
    - [ ] sudo nano /etc/samba/smb.conf ```[sambashare] \n comment = Shared Drive \n path = /path/to/drive/mount/point \n read only = no \n browsable = yes```
    - [ ] sudo smbpasswd -a zyon
    - [ ] sudo service samba restart
    - [ ] sudo ufw allow samba
- [ ] make updating all apps easier (make a simple script to handlle all sources for updates, system, uv , cargo, go, etc...)

- [ ] add cargo-update crate for easier update of cargo based apps.
- [ ] netron via `uv tool install netron`
- [ ] smassh via `uv tool install smashh` configure too
- [ ] openssh-server
- [ ] iperf3
- [ ] 1password cli
- [ ] automatic file organiser musa-labs/maid on github
- [ ] ripgrep
- [ ] codecompanion nvim plugin
- [ ] build a go based app that collates latest releases in AI
- [ ] Tailscale
- [ ] Kdiskmark
- [ ] aria2, and a corresponding webui
- [ ] gh cli, glab cli
- [ ] yeet script that handles the gcmsg " " and gp operation using mods.
- [ ] mods, gum, ship, ship_glab (ai based pull requests) - https://gist.githubusercontent.com/dangrondahl/2807a52f8ae11d12ac3f7a701fd822dc/raw/5e0166ee485124e0e6139ab61236c0faa863d55f/ship.sh
- [ ] pulsemixer
- [ ] https://github.com/milaq/XMousePasteBlock use this to disable paste on middle click
- [ ] neofetch
- [ ] lazysql
- [ ] lazygit
- [ ] 7zip and other Yazi formats
- [ ] Tdf or other doc viewer
- [ ] videoplayer - mpv
- [ ] Image viewer
- [ ] Make cursor executable directly
- [ ] nvim - build from source and also config with lazyvim and what not (default installation was also installing xclip, need to make sure xclip doesnt get fucked now)
- [ ] scratchpad
- [ ] Add imgur upload to screenshot pipeline (potentially using [this tool](https://github.com/jomo/imgur-screenshot))
- [o] Yazi rust
- [x] Bolt runescale launcher
- [x] flatseal
- [x] discord
- [x] script play_remote to play remote videos using mpv and ffmpeg and ssh
- [x] add flatpak and flathub
- [x] kitty terminal emulator
- [x] spotify-player (cargo install spotify_player --features image,fzf,notify) - tui
- [x] manga tui
- [x] zoxide - cargo install zoxide --locked
- [x] tmux
- [x] btop
- [x] i3blocks - bar customisation
- [x] dunst
- [x] rofi
- [x] cmake
- [x] libssl-dev
- [x] libcurl4-openssl-dev
- [x] python3-dev
- [x] rename
- [x] use xset to set suspend i3lock to 1800 seconds (xset s 1800)
- [x] ngrok
- [x] go installation
- [x] fd-find rust
- [x] nyaa rust
- [x] television rust
- [x] bat rust
- [x] transmission
- [x] nvtop - build from source
    - [x] libncurses-dev
    - [x] libdrm-dev 
    - [x] libsystemd-dev
- [x] polkit-gnome - autostart in i3wm
- [x] Figure out how to run virtualhere
- [x] greenclip - clipboard integration for rofi
- [x] Mouse speed settings

---

## REJECTED / DISCARDED
- [x] polybar - way to complicated for what it offers
- [x] clipse - interactive clipboard -> NOT GOING TO USE THIS (WORKS LIKE SHIT ATM)
