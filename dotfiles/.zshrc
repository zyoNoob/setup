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

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

# Plugins -> zsh-autocomplete for completion
# plugins=(git zsh-autosuggestions zsh-autocomplete F-Sy-H conda-zsh-completion fzf)

# Plugins -> fzf-tab for completion
plugins=(git zsh-autosuggestions F-Sy-H conda-zsh-completion fzf fzf-tab)

# Add unhandled widgets to be ignored by F-Sy-H
zle -N insert-unambiguous-or-complete
zle -N menu-search
zle -N recent-paths

source $ZSH/oh-my-zsh.sh

# There is a newline in the prompt
# The j part shows number of suspended jobs
PROMPT='%(?:%{$fg_bold[green]%}%1{OK%} :%{$fg_bold[red]%}%1{FAILED%} ) %{$fg[cyan]%}%1{($?)%}
%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[cyan]%}%c% %{$fg[red]%}%(1j. [%j].)%{$reset_color%} $(git_prompt_info)'

# git diff aliases to pipe to ydiff
alias gd="git diff | ydiff -s"
alias gds="git diff --staged | ydiff -s"

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

# Custome Export Paths
export VIDEO_CODEC_SDK_PATH=/home/zyon/nvidia/video/codec/sdk
export PATH="/usr/local/cuda/bin:/usr/local/TensorRT-10.5.0.18/bin:$PATH"
export LD_LIBRARY_PATH="/usr/lib/wsl/lib:/usr/local/cuda/lib64:/usr/local/TensorRT-10.5.0.18/lib:$LD_LIBRARY_PATH"

# keychain for ssh-agent
eval $(keychain --eval id_rsa)

# binding to a tmux session
# Only auto-start tmux if:
# 1. The shell is interactive.
# 2. You are not already inside a tmux session.
# 3. No command was passed to the shell.
# if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && [[ $# -eq 0 ]]; then
#   exec tmux
# fi
# if [ -z "$TMUX" ]; then tmux attach -t default || tmux new -s default; fi
#

# If any arguments are passed (e.g. via ghostty -e zsh -c "...")
if [ $# -gt 0 ]; then
    # Check for our special flag "--tmux" at the beginning.
    if [ "$1" = "--tmux" ]; then
        shift  # Remove the flag so that "$@" contains only the actual command.
        mode="tmux"
    else
        mode="normal"
    fi

    if [ "$mode" = "tmux" ]; then
        # Run the command inside a tmux session called "run"
        if ! tmux has-session -t run 2>/dev/null; then
            tmux new-session -d -s run
        fi
        # Create a new window in the "run" session with the command.
        tmux new-window -t run -n "rofi" "$@"
        # Optionally, you could attach immediately:
        # tmux attach -t run
        exit 0
    else
        # Run the command normally
        exec "$@"
    fi
fi

# --- For interactive shells with no command passed (normal terminal start) ---
if [[ $- == *i* ]] && [ -z "$TMUX" ]; then
    tmux attach -t default || tmux new -s default
fi
