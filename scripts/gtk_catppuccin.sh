mkdir -p ~/.local/share/themes
cd ~/.local/share/themes

# Set the root URL
export ROOT_URL="https://github.com/catppuccin/gtk/releases/download"

# Change to the tag you want to download
export RELEASE="v1.0.3"

# Change to suite your flavor / accent combination
export FLAVOR="mocha"
export ACCENT="blue"
curl -LsSO "${ROOT_URL}/${RELEASE}/catppuccin-${FLAVOR}-${ACCENT}-standard+default.zip"

# Extract the catppuccin zip file
unzip "catppuccin-${FLAVOR}-${ACCENT}-standard+default.zip"

# Set the catppuccin theme directory
export THEME_DIR="$HOME/.local/share/themes/catppuccin-${FLAVOR}-${ACCENT}-standard+default"

# Optionally, add support for libadwaita
mkdir -p "${HOME}/.config/gtk-4.0" && 
ln -sf "${THEME_DIR}/gtk-4.0/assets" "${HOME}/.config/gtk-4.0/assets" && 
ln -sf "${THEME_DIR}/gtk-4.0/gtk.css" "${HOME}/.config/gtk-4.0/gtk.css" && 
ln -sf "${THEME_DIR}/gtk-4.0/gtk-dark.css" "${HOME}/.config/gtk-4.0/gtk-dark.css"