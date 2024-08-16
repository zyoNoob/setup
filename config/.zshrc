# Minimal version
# Full template: https://github.com/ohmyzsh/ohmyzsh/blob/master/templates/zshrc.zsh-template

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-autocomplete F-Sy-H conda-zsh-completion fzf fzf-tab)
source $ZSH/oh-my-zsh.sh

# There is a newline in the prompt
# The j part shows number of suspended jobs
PROMPT='%(?:%F{green}OK%f:%F{red}FAILED%f) %F{white}($?)%f
%F{blue}%~%f%F{red}%(1j. [%j].)%f $(git_prompt_info)'

# git diff aliases to pipe to ydiff
alias gd="git diff | ydiff -s"
alias gds="git diff --staged | ydiff -s"

# Custom ZSH Executions
cd ~
alias zshconfig="source ~/.zshrc"
alias deactivate="conda deactivate"

# Custome Export Paths
export LD_LIBRARY_PATH=/usr/lib/wsl/lib:$LD_LIBRARY_PATH
export VIDEO_CODEC_SDK_PATH=/home/zyon/nvidia/video/codec/sdk
export PATH="/usr/local/cuda/bin:$PATH"
