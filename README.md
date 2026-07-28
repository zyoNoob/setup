# Setup


### Stable Config
```
export SETUP_DOWNLOAD_URL="https://raw.githubusercontent.com/zyoNoob/setup/refs/heads/main/setup.sh" && \
wget -qO /tmp/setup.sh $SETUP_DOWNLOAD_URL && \
bash /tmp/setup.sh && \
rm /tmp/setup.sh
```
### Dev Config
```
export SETUP_DOWNLOAD_URL="https://raw.githubusercontent.com/zyoNoob/setup/refs/heads/dev/setup.sh" && \
wget -qO /tmp/setup.sh $SETUP_DOWNLOAD_URL && \
bash /tmp/setup.sh && \
rm /tmp/setup.sh
```

### Forcing the server or desktop path

By default the script decides which path to take by looking for desktop
metapackages, display managers and DE session packages. Set `SETUP_PROFILE` to
skip detection entirely:

```
SETUP_PROFILE=server bash /tmp/setup.sh     # core packages only, no GUI
SETUP_PROFILE=desktop bash /tmp/setup.sh    # include i3, polybar, flatpak apps
```

Worth setting explicitly on a headless machine that has a GPU driver installed.
`nvidia-driver` pulls in `xserver-xorg-core` as a dependency, and enough of an X
stack on disk can otherwise make a server look like a desktop.
