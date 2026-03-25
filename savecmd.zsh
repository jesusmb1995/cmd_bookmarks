#!/bin/zsh
# By jesusmb1995 under MIT license

# Function to save a command with a name to local history
# TODO sort categories and commands within cat by date

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

    # Check if command already exists (by display name, supports dep+name format)
    local existing_line=""
    if [[ -f "$cmd_bookmarks" ]]; then
        existing_line=$(_find_bookmark_line "$cmd_name" "$cmd_bookmarks")
    fi

    if [[ -n "$existing_line" ]]; then
        local raw_name="${existing_line%%|*}"
        local existing_cmd="${existing_line#*|}"
        local new_cmd="$existing_cmd && $last_cmd"
        sed -i "/^${raw_name}|/d" "$cmd_bookmarks" 2>/dev/null
        echo "$raw_name|$new_cmd" >> "$cmd_bookmarks"
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

# Find a bookmark line by display name (last + segment)
_find_bookmark_line() {
    local cmd_name="$1"
    local cmd_bookmarks="$2"
    awk -F'|' -v name="$cmd_name" '{
        n = split($1, parts, "+")
        if (parts[n] == name) result = $0
    } END { if (result) print result }' "$cmd_bookmarks"
}

# Function to execute a saved command
# Use -d flag to run dependencies first: cmdrun -d name
cmdrun() {
    local with_deps=false
    if [[ "$1" == "-d" ]]; then
        with_deps=true
        shift
    fi

    if [[ $# -gt 1 ]]; then
        for cmd_name in "$@"; do
            if [[ "$with_deps" == true ]]; then
                cmdrun -d "$cmd_name" || return $?
            else
                cmdrun "$cmd_name" || return $?
            fi
        done
        return
    fi

    local cmd_name="$1"
    local dir="$(pwd)"
    local cmd_bookmarks="$dir/.local_cmd_bookmarks"

    if [[ ! -f "$cmd_bookmarks" ]]; then
        echo "No local bookmarks file found: $cmd_bookmarks"
        return 1
    fi

    local line=$(_find_bookmark_line "$cmd_name" "$cmd_bookmarks")

    if [[ -z "$line" ]]; then
        echo "Command '$cmd_name' not found in local bookmarks '$cmd_bookmarks'. Use 'cmdlist' to show available bookmarks."
        return 1
    fi

    local raw_name="${line%%|*}"
    local cmd="${line#*|}"

    # Resolve and run dependencies if requested
    if [[ "$with_deps" == true && "$raw_name" == *"+"* ]]; then
        local deps_str="${raw_name%+*}"
        local deps=(${(s:+:)deps_str})
        for dep in "${deps[@]}"; do
            echo "Running dependency: $dep"
            cmdrun -d "$dep" || return $?
        done
    fi

    _update_cmd_stats "$cmd_name"

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
    awk -F'|' '{
        n = split($1, parts, "+")
        name = parts[n]
        deps = ""
        if (n > 1) {
            for (i = 1; i < n; i++) {
                if (deps != "") deps = deps "+"
                deps = deps parts[i]
            }
            deps = " [+" deps "]"
        }
        printf "%-20s%-16s %s\n", name, deps, $2
    }' "$cmd_bookmarks"
}

# Completion function
_local_cmd_bookmarks_commands() {
    local dir="$(pwd)"
    local cmd_bookmarks="$dir/.local_cmd_bookmarks"
    local cmd_stats="$dir/.local_cmd_bookmarks_stats"
    local commands=()

    if [[ -f "$cmd_bookmarks" ]]; then
        if [[ -f "$cmd_stats" ]]; then
            # Sort by last run date (most recent first), use display name (last + segment)
            commands=($(awk -F'|' '
                NR==FNR {
                    n = split($1, p, "+"); stats[p[n]] = $2; next
                }
                {
                    n = split($1, p, "+"); name = p[n]
                    if (stats[name]) print stats[name] "|" name; else print "0|" name
                }
            ' "$cmd_stats" "$cmd_bookmarks" | sort -t'|' -k1,1nr | cut -d'|' -f2))
        else
            commands=($(awk -F'|' '{n=split($1,p,"+"); print p[n]}' "$cmd_bookmarks" | sort -u))
        fi
        
        if [[ ${#commands[@]} -gt 0 ]]; then
            _describe -V 'local commands' commands
        fi
    fi
}

# Set up completion
compdef _local_cmd_bookmarks_commands cmdsave cmdrun cmdlist
