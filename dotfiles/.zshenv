# Source env variables
[ -f "$HOME/.env" ] && . "$HOME/.env"

# Source credentials
[ -f "$HOME/.creds" ] && . "$HOME/.creds"

# SSH Aliases
# alias ssh_remote="ssh user@domain"

# Commands|App Aliases
alias zshconfig="source ~/.zshrc"
# The -E option preserves the user's environment variables (like PATH)
# This helps sudo find commands installed in user-specific directories (e.g., bat from ~/.cargo/bin)
alias sudo="sudo -E "
alias audio="pulsemixer"
alias vim="nvim"
alias cat="bat"
alias grep="rg"
alias cd="z"
alias vpnstart="sudo tailscale up"
alias vpnstop="sudo tailscale down"
alias vpnstatus="sudo tailscale status"
alias gpl="git pull"
alias gd="gitydiff "
alias gds="gitstagedydiff "
