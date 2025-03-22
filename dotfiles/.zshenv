# Source env variables
[ -f "$HOME/.env" ] && . "$HOME/.env"

# Source credentials
[ -f "$HOME/.creds" ] && . "$HOME/.creds"

# SSH Aliases
# alias ssh_remote="ssh user@domain"

# Commands|App Aliases
alias zshconfig="source ~/.zshrc"
alias sudo="sudo "
alias audio="pulsemixer"
alias vim="nvim"
alias cat="bat"
alias vpnstart="sudo tailscale up"
alias vpnstop="sudo tailscale down"
alias vpnstatus="sudo tailscale status"
alias gpl="git pull"