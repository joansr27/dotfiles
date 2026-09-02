#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '


# ============================================================
# TERMINAL RICE
# ============================================================

# Display the Fastfetch banner when an interactive Bash shell starts.
if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi

# Use Starship as the interactive Bash prompt.
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi
