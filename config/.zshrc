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
plugins=(git zsh-autosuggestions zsh-autocomplete F-Sy-H conda-zsh-completion fzf fzf-tab)

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

# Custom ZSH Executions
cd ~
alias zshconfig="source ~/.zshrc"
alias deactivate="conda deactivate"

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

