mkdir -p $HOME/.icons
cd $HOME/.icons
curl -LOsS https://github.com/catppuccin/cursors/releases/download/v1.0.2/catppuccin-mocha-dark-cursors.zip
unzip catppuccin-mocha-dark-cursors.zip

curl -LOsS https://github.com/catppuccin/cursors/releases/download/v1.0.2/catppuccin-mocha-light-cursors.zip
unzip catppuccin-mocha-light-cursors.zip

sudo add-apt-repository ppa:papirus/papirus
sudo apt-get update
sudo apt-get install papirus-icon-theme  # Papirus, Papirus-Dark, and Papirus-Light