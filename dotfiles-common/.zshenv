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
alias gplr="git pull --recurse-submodules"
alias gd="gitydiff "
alias gds="gitstagedydiff "
alias lg="lazygit"

# RipGrep
alias rga='rg -uu --hidden'            # search absolutely everything
alias rgf='rg -F'                      # fixed-string search (literal)
alias rgi='rg -i'                      # force case-insensitive
alias rgc='rg -C 3'                    # context search
alias rgg='rg --glob'                  # pass custom globs easily
alias rgm='rg -U -z'                   # multiline search mode
alias rgl='rg -l'                      # show only filenames
alias rgr='rg --hidden -S --glob "!.git"' 

# Aria2c
alias dl='aria2c -x 16 -s 16'

# Coding TUIs
alias clauded='claude --dangerously-skip-permissions'
alias codexed='codex --dangerously-bypass-approvals-and-sandbox'
alias agyd='agy --dangerously-skip-permissions'

# claudex: Claude Code TUI on Codex (ChatGPT) models via local CLIProxyAPI (127.0.0.1:8317).
# Proxy: systemctl --user {status,restart} cliproxyapi.service ; re-auth: cli-proxy-api -codex-login
# Model override: CLAUDEX_MODEL=gpt-5.6-sol claudex   (or append: claudex --model gpt-5.6-sol)
claudex() {
  local model="${CLAUDEX_MODEL:-gpt-6-astra}"
  ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
  ANTHROPIC_AUTH_TOKEN="$(<~/.cli-proxy-api/client.key)" \
  CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 \
  CLAUDE_CODE_SUBAGENT_MODEL="$model" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL=gpt-5.4-mini \
  CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 \
  CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3 \
  ENABLE_TOOL_SEARCH=false \
  claude --model "$model" "$@"
}
alias claudexed='claudex --dangerously-skip-permissions'
