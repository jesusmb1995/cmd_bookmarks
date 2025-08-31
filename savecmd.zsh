#!/bin/zsh
# By jesusmb1995 under MIT license

# Function to save a command with a name to local history
# TODO sort categories and commands within cat by date
# TODO nvim plugin few last used... and categories

# Helper function to update stats
_update_cmd_stats() {
    local cmd_name="$1"
    local dir="$(pwd)"
    local cmd_stats="$dir/.local_cmd_bookmarks_stats"
    local timestamp=$(date +%s)
    
    # Remove existing entry for this command if it exists
    if [[ -f "$cmd_stats" ]]; then
        sed -i "/^$cmd_name|/d" "$cmd_stats" 2>/dev/null
    fi
    
    # Add new entry with just command name and timestamp
    echo "$cmd_name|$timestamp" >> "$cmd_stats"
}

# Save new bookmark or append additional step to existing bookmark
# If no namee, append to last bookmark
cmdsave() {
    local cmd_name="$1"
    if [[ -z "$cmd_name" ]]; then
        # If no name provided, try to get the last used bookmark from stats
        local dir="$(pwd)"
        local cmd_stats="$dir/.local_cmd_bookmarks_stats"
        if [[ -f "$cmd_stats" ]]; then
            cmd_name=$(sort -t'|' -k2,2nr "$cmd_stats" | head -1 | cut -d'|' -f1)
        fi
    fi
    if [[ -z "$cmd_name" ]]; then
        echo "Error: No last used bookmark found. Provide a name for the command."
        return 1
    fi
    local dir="$(pwd)"
    local cmd_bookmarks="$dir/.local_cmd_bookmarks"

    # Check if a name was provided
    if [[ -z "$cmd_name" ]]; then
        echo "Error: Please provide a name for the command"
        return 1
    fi

    # Get the last command from history (excluding our savecmd command)
    local last_cmd="$(history -1 | sed 's/^[ ]*[0-9]*[ ]*//')"

    if [[ -z "$last_cmd" ]]; then
        echo "Error: No previous command found"
        return 1
    fi

    # Check if command already exists
    local existing_cmd=""
    if [[ -f "$cmd_bookmarks" ]]; then
        existing_cmd=$(grep "^$cmd_name|" "$cmd_bookmarks" | tail -1 | cut -d'|' -f2-)
    fi

    if [[ -n "$existing_cmd" ]]; then
        # Command exists, append with &&
        local new_cmd="$existing_cmd && $last_cmd"
        # Remove the old entry and add the new one
        sed -i "/^$cmd_name|/d" "$cmd_bookmarks" 2>/dev/null
        echo "$cmd_name|$new_cmd" >> "$cmd_bookmarks"
        echo "Appended '$last_cmd' to existing command '$cmd_name'"
        echo "New command: $new_cmd"
    else
        # Command doesn't exist, save as new
        echo "$cmd_name|$last_cmd" >> "$cmd_bookmarks"
        echo "Saved '$last_cmd' as '$cmd_name'"
    fi

    _update_cmd_stats "$cmd_name"

    # Update completion cache
    _local_cmd_bookmarks_commands
}

# Function to execute a saved command
cmdrun() {
    local cmd_name="$1"
    local dir="$(pwd)"
    local cmd_bookmarks="$dir/.local_cmd_bookmarks"

    if [[ ! -f "$cmd_bookmarks" ]]; then
        echo "No local bookmarks file found: $cmd_bookmarks"
        return 1
    fi 

    # Find the command by name
    local cmd=$(grep "^$cmd_name|" "$cmd_bookmarks" | tail -1 | cut -d'|' -f2-)

    if [[ -z "$cmd" ]]; then
      echo "Command '$cmd_name' not found in local bookmarks '$cmd_bookmarks'. Use 'cmdlist' to show available bookmarks."
        return 1
    fi 

    _update_cmd_stats "$cmd_name"

    # Execute the command
    echo "Running: $cmd"
    eval "$cmd"
}

# Function to list available bookmarks
cmdlist() {
    local dir="$(pwd)"
    local cmd_bookmarks="$dir/.local_cmd_bookmarks"

    if [[ ! -f "$cmd_bookmarks" ]]; then
        echo "No bookmark file found $cmd_bookmarks. Use 'cmdsave' to create new bookmarks."
        return 1
    fi

    echo "Available commands:"
    awk -F'|' '{printf "%-20s %s\n", $1, $2}' "$cmd_bookmarks"
}

# Completion function
_local_cmd_bookmarks_commands() {
    local dir="$(pwd)"
    local cmd_bookmarks="$dir/.local_cmd_bookmarks"
    local cmd_stats="$dir/.local_cmd_bookmarks_stats"
    local commands=()

    if [[ -f "$cmd_bookmarks" ]]; then
        if [[ -f "$cmd_stats" ]]; then
            # Sort by last run date (most recent first)
            commands=($(awk -F'|' '
                NR==FNR {stats[$1]=$2; next}
                {if (stats[$1]) print stats[$1] "|" $1; else print "0|" $1}
            ' "$cmd_stats" "$cmd_bookmarks" | sort -t'|' -k1,1nr | cut -d'|' -f2))
        else
            # Fallback to original behavior if no stats file
            commands=($(cut -d'|' -f1 "$cmd_bookmarks" | sort -u))
        fi
        
        if [[ ${#commands[@]} -gt 0 ]]; then
            _describe -V 'local commands' commands
        fi
    fi
}

# Set up completion
compdef _local_cmd_bookmarks_commands cmdsave cmdrun cmdlist
