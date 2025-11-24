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
alias audio="pulsemixer"
alias vim="nvim"

# Tailscale
alias vpnstart="sudo tailscale up"
alias vpnstop="sudo tailscale down"
alias vpnstatus="sudo tailscale status"

# Git
alias gpl="git pull"
alias gd="gitydiff "
alias gds="gitstagedydiff "

# RipGrep
alias rga='rg -uu --hidden'            # search absolutely everything
alias rgf='rg -F'                      # fixed-string search (literal)
alias rgi='rg -i'                      # force case-insensitive
alias rgc='rg -C 3'                    # context search
alias rgg='rg --glob'                  # pass custom globs easily
alias rgm='rg -U -z'                   # multiline search mode
alias rgl='rg -l'                      # show only filenames
alias rgr='rg --hidden -S --glob "!.git"' 
