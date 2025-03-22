# Minimal version
# Full template: https://github.com/ohmyzsh/ohmyzsh/blob/master/templates/zshrc.zsh-template

# DISABLE_MAGIC_FUNCTIONS=true

# Use the above flag or the bottom block

# Disable zsh-autocompletion on paste
pasteinit() {
  OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
  zle -N self-insert url-quote-magic # I wonder if you'd need `.url-quote-magic`?
}
pastefinish() {
   zle -N self-insert $OLD_SELF_INSERT
}
zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish

# Source env variables from .zshenv
[ -f "$HOME/.zshenv" ] && . "$HOME/.zshenv"

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

# Plugins -> zsh-autocomplete for completion
# plugins=(git zsh-autosuggestions zsh-autocomplete F-Sy-H conda-zsh-completion fzf)

# Plugins -> fzf-tab for completion
plugins+=(vi-mode conda-zsh-completion)    

fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

autoload -U compinit; compinit

plugins+=(fzf fzf-tab git zsh-autosuggestions F-Sy-H)

# Add unhandled widgets to be ignored by F-Sy-H
zle -N insert-unambiguous-or-complete
zle -N menu-search
zle -N recent-paths

source $ZSH/oh-my-zsh.sh

# There is a newline in the prompt
# The j part shows number of suspended jobs
PROMPT='%(?:%{$fg_bold[green]%}%1{OK%} :%{$fg_bold[red]%}%1{FAILED%} ) %{$fg[cyan]%}%1{($?)%}
%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[cyan]%}%c% %{$fg[red]%}%(1j. [%j].)%{$reset_color%} $(git_prompt_info)'

# Alias function for gitydiff
# Unalias if it exists (from oh-my-zsh)
[[ -n $(alias gd 2>/dev/null) ]] && unalias gd
gd() {
  if ! command -v ydiff >/dev/null 2>&1; then
    echo "Error: ydiff is not installed" >&2
    return 1
  fi

  if [ $# -eq 0 ]; then
    git diff . | ydiff -s
  else
    git diff "$@" | ydiff -s
  fi
}

# Alias function for gitstagedydiff
# Unalias if it exists (from oh-my-zsh)
[[ -n $(alias gds 2>/dev/null) ]] && unalias gds
gds() {
  if ! command -v ydiff >/dev/null 2>&1; then
    echo "Error: ydiff is not installed" >&2
    return 1
  fi

  if [ $# -eq 0 ]; then
    git diff --staged . | ydiff -s
  else
    git diff --staged "$@" | ydiff -s
  fi
}

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/zyon/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/zyon/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/zyon/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/zyon/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# keychain for ssh-agent
eval $(keychain --eval id_rsa)

# Integrate television
[ -f "$HOME/.config/television/.tvzshrc" ] && . "$HOME/.config/television/.tvzshrc"

# Only auto-start tmux if:
# 1. The shell is interactive.
# 2. You are not already inside a tmux session.
# 3. No command was passed to the shell.
if [[ $- == *i* ]] && [ -z "$TMUX" ] && [ $# -eq 0 ]; then
    tmux attach -t default || tmux new -s default
fi

# Set terminal program for ssh
if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
    export TERM=xterm-256color
fi




















































