#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# >>> go initialize >>>
export GOPATH="$HOME/.local/go"
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
# <<< go initialize <<<

# >>> nvm initialize >>>
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# <<< nvm initialize <<<

# >>> cargo initialize >>>
. "$HOME/.cargo/env"
# <<< cargo initialize <<<

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('$HOME/.miniforge/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/.miniforge/etc/profile.d/conda.sh" ]; then
        . "$HOME/.miniforge/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/.miniforge/bin:$PATH"
    fi
fi
unset __conda_setup
CONDA_ROOT="$HOME/.miniforge"
if [[ -r $CONDA_ROOT/etc/profile.d/bash_completion.sh ]]; then
    source $CONDA_ROOT/etc/profile.d/bash_completion.sh
else
    echo "WARNING: could not find conda-bash-completion setup script"
fi
# <<< conda initialize <<<

# >>> starship init >>>
eval "$(starship init bash)"
# <<< starship init <<<

# >>> setup autocompletion >>>
source ~/.local/share/blesh/ble.sh
# <<< setup autocompletion <<<

# >>> setup fancy ls >>>
alias ll='ls -alF'
alias ls='exa --icons -F -H --group-directories-first --git -1'
# <<< setup fancy ls <<<

yt-dlp-music() {
    yt-dlp $1 \
        -f "bestaudio[ext=m4a]" \
        --embed-metadata \
        --embed-thumbnail \
        --convert-thumbnail jpg \
        --exec-before-download "ffmpeg -i %(thumbnails.-1.filepath)q -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\" _%(thumbnails.-1.filepath)q" \
        --exec-before-download "rm %(thumbnails.-1.filepath)q" \
        --exec-before-download "mv _%(thumbnails.-1.filepath)q %(thumbnails.-1.filepath)q" \
        --output "%(artist)s - %(title)s.%(ext)s"
}
