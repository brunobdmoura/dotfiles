# custom aliases and functions
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias eb='nvim $HOME/user.bashrc && source $HOME/.bashrc'

alias cdw='cd ~/Workspace'
alias cconf='cd ~/.config'

alias ll='exa -lag --icons --group-directories-first'
alias llt='exa -lag --icons --group-directories-first --tree'

alias gitclean='git clean -f -x -d; git reset --hard'
alias gitamend='git commit --amend'
alias gitl='git log --graph --oneline'
alias gitba='git branch --all | grep -v HEAD | sed "s/.* //" | uniq | fzf --tmux=center,70% --border-label=Branches --style=minimal | xargs git checkout'
alias gitb='git branch | grep -v HEAD | sed "s/.* //" | uniq | fzf --tmux=center,70% --border-label=Branches --style=minimal | xargs git checkout'

alias build_src='dpkg-buildpackage -S -I -i -nc -d -sa'
alias save_rules='git add debian/rules && git commit --amend'
alias sync_files='rsync -avHP --delete --exclude=.git --exclude=debian'

alias llintian='lintian -EviI ../*.deb'
alias rcp='rsync -a --info=progress2,name0'
alias srcp='rsync -a --info=progress2,name0 -e ssh'
alias dchi='gbp dch --ignore-branch'

lxc_login() {
    lxc exec "$@" -- bash -c 'su - ubuntu'
}

lxc_container() {
    bash ~/Scripts/lxc_container.sh "$@"
}

mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Easier use of data into the clipboard
copy() {
    if [ -t 0 ]; then
        cat "$1" | xclip -selection clipboard
    else
        cat | xclip -selection clipboard
    fi
}

kd() {
    local selection
    # 1. Find both files (-type f) and directories (-type d)
    # 2. Sort by depth so shallow items appear first
    # 3. Pass to fzf for selection
    selection=$(find . -not -path '*/.*' \( -type d -o -type f \) 2> /dev/null | \
        awk -F/ '{print NF, $0}' | \
        sort -n -s | \
        cut -d" " -f2- | \
        fzf --tmux=center,70% --border-label="Files and Directories" --style=minimal)

    # Exit early if nothing was selected (Esc/Ctrl-C)
    [[ -z "$selection" ]] && return

    if [[ -d "$selection" ]]; then
        # If it's a directory, change into it
        cd "$selection"
    else
        # If it's a file, copy the path to clipboard
        echo -n "$selection" | wl-copy -n
    fi
}

wait_for_url() {
    if [ -z "$1" ]; then
        echo "Usage: wait_for_url <url>"
        return 1
    fi

    local target_url="$1"
    echo "Waiting for $target_url to return HTTP 200..."

    while true; do
        status=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "$target_url")

        if [ "$status" = "200" ]; then
            notify-send "URL is UP!" "$target_url now accessible"
            echo -e "\n$target_url now accessible"
            break
        else
            echo -ne "Still getting status ${status:-TIMEOUT}, retrying in 10s...\r"
            sleep 10
        fi
    done
}

keep_trying() {
    # Run the command and loop until it succeeds
    until "$@"; do
        echo "Command '$*' failed. Retrying in 1 second..."
        sleep 1
    done
    echo "Command '$*' succeeded!"
}
alias keep_trying='keep_trying '

notify_after() {
    local start_time=$(date +%s)

    # Run the command passed to the function
    "$@"

    # Capture the exit code of the command
    local exit_code=$?

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    if [ $exit_code -eq 0 ]; then
        notify-send "✅ Command Succeeded" "Command: '$1'\nTime: $elapsed seconds."
    else
        # Sends a critical notification if the command failed
        notify-send -u critical "❌ Command Failed" "Command: '$1'\nExit code: $exit_code\nTime: $elapsed seconds."
    fi

    # Return the original command's exit code
    return $exit_code
}
alias notify_after='notify_after '

notify_in() {
    # Check if the primary argument was provided
    if [ -z "$1" ]; then
        echo "Usage: timer <minutes> [label]"
        return 1
    fi

    local minutes="$1"
    # Assign the second argument to 'label', defaulting to "Task" if left blank
    local label="${2:-Task}"

    # Check if the input is a valid number
    if ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
        echo "Error: Please provide a valid number of minutes."
        return 1
    fi

    # Run the timer in a background subshell
    (
        sleep "${minutes}m"
        # Use the label cleanly in the notification title
        notify-send "Timer: $label" "Your ${minutes}-minute timer is up." --urgency=critical --icon=appointment-soon
    ) &

    # Print a confirmation to the terminal
    echo "Timer set for $minutes minute(s) for '$label' in the background. PID: $!"
}

log_files() {
    local outfile="log-$(date +%s).txt";
    find "${1:-.}" -type f -not -path "./$outfile" -print0 | while IFS= read -r -d '' file;
    do echo "---- $file - begin -----";
    cat "$file";
    echo;
    echo "---- $file - end ------";
    done > "$outfile" && echo "Done. Logged to '$outfile'.";
}

levil() {
    # Get the base name from the current directory to prefix the log
    local DIR_NAME="${PWD##*/}"

    # Define the log directory and ensure it exists
    local LOG_DIR="../_lintian_logs"
    mkdir -p "${LOG_DIR}"

    # Generate a unique log file name using a timestamp
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local LOG_FILE="${LOG_DIR}/${DIR_NAME}_lintian_${TIMESTAMP}.log"

    echo "Starting Lintian analysis..."

    # Clear/create the log file
    > "${LOG_FILE}"

    # Define the extensions based on the previous discussion
    local EXTENSIONS=("ddeb deb" "changes" "dsc" "udeb")

    for EXT in "${EXTENSIONS[@]}"; do
        # Safely find files matching the extension in the upper directory
        shopt -s nullglob
        local TARGET_FILES=( ../*."${EXT}" )
        shopt -u nullglob

        # Write the section header
        echo "# .${EXT} files:" >> "${LOG_FILE}"

        # If files exist, run lintian and append output; otherwise, note they are missing
        if [ ${#TARGET_FILES[@]} -gt 0 ]; then
            # We redirect standard error (2>&1) just in case lintian throws warnings to stderr
            lintian -EviI "${TARGET_FILES[@]}" >> "${LOG_FILE}" 2>&1
        else
            echo "# No .${EXT} files found in the upper directory." >> "${LOG_FILE}"
        fi

        # Add a blank line for readability between sections
        echo "" >> "${LOG_FILE}"
    done

    echo "--- Lintian analysis complete (Log: ${LOG_FILE}) ---"
}

clean_deb_build() {
    # Check if we are inside a valid Debian source directory
    if [ ! -f "debian/changelog" ]; then
        echo "Error: 'debian/changelog' not found."
        echo "Please run this command from the root of your Debian package source directory."
        return 1
    fi

    # Extract the source package name dynamically
    local PKG_NAME=$(dpkg-parsechangelog -S Source)

    echo "Scanning for build artifacts of '${PKG_NAME}' in ../"

    # Enable nullglob so the arrays evaluate to empty if no files match
    shopt -s nullglob
    local ARTIFACTS=(
        "../"*.deb
        "../${PKG_NAME}_"*.buildinfo
        "../${PKG_NAME}_"*.changes
        # Including source files just in case you ever build without '-b'
        "../${PKG_NAME}_"*.dsc
        "../${PKG_NAME}_"*.tar.*
    )
    shopt -u nullglob

    # Check if any files were found
    if [ ${#ARTIFACTS[@]} -eq 0 ]; then
        echo "No build artifacts found to remove."
        return 0
    fi

    # Loop through and remove the matched files
    for FILE in "${ARTIFACTS[@]}"; do
        echo "Removing: ${FILE}"
        rm -f "${FILE}"
    done

    echo "--- Cleanup complete ---"
}

rebase() {
    # Check if a number was provided
    if [ -z "$1" ]; then
        echo "Error: Please provide the number of commits."
        echo "Usage: rebase <N>"
        return 1
    fi

    # Execute the interactive rebase
    git rebase -i HEAD~"$1"
}

commit_changelog() {
    local changelog
    changelog="$(git rev-parse --show-toplevel)/debian/changelog"

    if [[ ! -f "$changelog" ]]; then
        echo "Error: debian/changelog not found" >&2
        return 1
    fi

    local first_line
    first_line=$(head -n1 "$changelog")

    local version
    version=$(echo "$first_line" | sed -n 's/.*(\([^)]*\)).*/\1/p')

    local target
    target=$(echo "$first_line" | sed -n 's/.*) \([^;]*\);.*/\1/p')

    local target_cap
    target_cap="$(echo "${target:0:1}" | tr '[:lower:]' '[:upper:]')${target:1}"

    local lp_bugs
    lp_bugs=$(awk '/^[a-z]/{p=1} p && /^ -- /{exit} p' "$changelog" | grep -oP 'LP: #\K[0-9]+' | sed 's/^/LP: #/')

    local body="Add the changelog entry to the package on Ubuntu ${target_cap}"
    if [[ -n "$lp_bugs" ]]; then
        body="${body}

${lp_bugs}
Gbp-dch: full"
    fi

    git commit -m "d/changelog: ${version}" -m "${body}"
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
    echo "${SECONDARY_COLOR}$(__git_ps1)${MAIN_COLOR} "
}

shell_prompt() {
    local env_info=$(_get_virtualenv_info)
    local git_info=$(_get_git_info)

    # PS1="${MAIN_COLOR}\u ${NON_BOLD_COLOR}on ${MAIN_COLOR}\h (${SECONDARY_COLOR}\t${MAIN_COLOR}) "
    PS1="${MAIN_COLOR}\u (${SECONDARY_COLOR}\t${MAIN_COLOR}) "
    PS1+="${INSIDER_COLOR}\w${MAIN_COLOR}"
    PS1+="${git_info}"
    PS1+="${env_info}"
    #PS1+="\n${MAIN_COLOR}\$ "
    PS1+="\n "
    PS1+="${NON_BOLD_COLOR}"
}

export VIRTUAL_ENV_DISABLE_PROMPT=1
export EDITOR='nvim'
export DEBEMAIL='bruno.moura@canonical.com'
export DEBFULLNAME='Bruno Bernardo de Moura'
PROMPT_COMMAND=shell_prompt

set -o vi
bind 'set show-mode-in-prompt on'
bind 'set vi-cmd-mode-string "\1\033[00;38;5;010m\2$"'
bind 'set vi-ins-mode-string "\1\033[01;38;5;011m\2$"'
bind -m vi-insert '"\C-w": unix-word-rubout'

# Don't forget to add this to the .bashrc file:
# if [ -f ~/user.bashrc ]; then
#     source ~/user.bashrc
# fi
