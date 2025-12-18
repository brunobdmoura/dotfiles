# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000

# append to the history file, don't overwrite it
shopt -s histappend

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Alias definitions.
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

copy() {
    if [ -t 0 ]; then
        cat "$1" | xclip -selection clipboard
    else
        cat | xclip -selection clipboard
    fi
}

logfiles() {
    local outfile="log-$(date +%s).txt";
    find "${1:-.}" -type f -not -path "./$outfile" -print0 | while IFS= read -r -d '' file;
    do echo "---- $file - begin -----";
    cat "$file";
    echo;
    echo "---- $file - end ------";
    done > "$outfile" && echo "Done. Logged to '$outfile'.";
}

# Primary Prompt Colors (Bold)
readonly ENV_COLOR="\[\033[01;38;5;011m\]" # Yellow/Orange
readonly MAIN_COLOR="\[\033[01;38;5;010m\]" # Bright Green
readonly SECONDARY_COLOR="\[\033[01;38;5;013m\]" # Magenta/Purple
readonly INSIDER_COLOR="\[\033[01;38;5;014m\]" # Cyan
readonly NON_BOLD_COLOR="\[\033[00;38;5;015m\]" # Bright White/Standard Reset
readonly NC="\[\033[0m\]" # Standard ANSI Reset

# Function to get Virtual Environment Info
_get_virtualenv_info() {
    if [ -n "$VIRTUAL_ENV" ]; then
        echo "${ENV_COLOR}[`basename "$VIRTUAL_ENV"`]${MAIN_COLOR}"
    fi
}

# Function to get Git Branch Info
_get_git_info() {
    local git_output
    git_output=$(git rev-parse --abbrev-ref HEAD 2>/dev/null )

    if [ -n "$git_output" ]; then
        echo " ${SECONDARY_COLOR}(${git_output})${MAIN_COLOR} "
    else
        echo " "
    fi
}

shell_prompt() {
    local env_info=$(_get_virtualenv_info)
    local git_info=$(_get_git_info)

    PS1="${MAIN_COLOR}\u ${NON_BOLD_COLOR}on ${MAIN_COLOR}\h (${SECONDARY_COLOR}\t${MAIN_COLOR}) "
    PS1+="${INSIDER_COLOR}\w${MAIN_COLOR}"
    PS1+="${git_info}"
    PS1+="${env_info}"
    PS1+="\n${MAIN_COLOR}\$ "
    PS1+="${NON_BOLD_COLOR}"
}

export VIRTUAL_ENV_DISABLE_PROMPT=1
export EDITOR='nvim'
export DEBEMAIL='bruno.moura@canonical.com'
export DEBFULLNAME='Bruno B Moura'
PROMPT_COMMAND=shell_prompt
