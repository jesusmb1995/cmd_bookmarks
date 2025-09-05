local M = {}

-- Configuration
local config = {
    border = "rounded",
    width = 0.8,
    height = 0.8,
    title = " SaveCmd Commands ",
    title_pos = "center",
}

-- Last command tracking
local last_command = nil
local last_window_type = nil

-- Get the current working directory
local function get_cwd()
    return vim.fn.getcwd()
end

-- Save last command info in memory
local function save_last_command_info(command, window_type)
    last_command = command
    last_window_type = window_type
end

-- Read and parse the command bookmarks file
local function read_cmd_bookmarks()
    local cwd = get_cwd()
    local bookmarks_file = cwd .. "/.local_cmd_bookmarks"
    local stats_file = cwd .. "/.local_cmd_bookmarks_stats"
    
    local commands = {}
    
    -- Check if bookmarks file exists
    if vim.fn.filereadable(bookmarks_file) == 0 then
        return commands
    end
    
    -- Read bookmarks file
    local lines = vim.fn.readfile(bookmarks_file)
    for _, line in ipairs(lines) do
        local name, cmd = line:match("^([^|]+)|(.+)$")
        if name and cmd then
            table.insert(commands, {
                name = name,
                command = cmd,
                last_used = 0
            })
        end
    end
    
    -- Read stats file if it exists and update last_used timestamps
    if vim.fn.filereadable(stats_file) == 1 then
        local stats_lines = vim.fn.readfile(stats_file)
        local stats = {}
        for _, line in ipairs(stats_lines) do
            local name, timestamp = line:match("^([^|]+)|(.+)$")
            if name and timestamp then
                stats[name] = tonumber(timestamp) or 0
            end
        end
        
        -- Update commands with timestamps
        for _, cmd in ipairs(commands) do
            cmd.last_used = stats[cmd.name] or 0
        end
        
        -- Sort by last used (most recent first)
        table.sort(commands, function(a, b)
            return a.last_used > b.last_used
        end)
    end
    
    return commands
end

-- Filter commands based on search query
local function filter_commands(commands, query)
    if not query or query == "" then
        return commands
    end
    
    local filtered = {}
    local lower_query = query:lower()
    
    for _, cmd in ipairs(commands) do
        if cmd.name:lower():find(lower_query, 1, true) then
            table.insert(filtered, cmd)
        end
    end
    
    return filtered
end

-- Execute command with specified window type
local function execute_command(command, window_type)
    -- Make sure to use same ids as: https://github.com/NvChad/NvChad/blob/v2.5/lua/nvchad/mappings.lua
    if window_type == "vertical" then
        -- Use NvChad's vertical terminal runner
        require("nvchad.term").runner {
            pos = "vsp",
            cmd = command,
            id = "vtoggleTerm",
            clear_cmd = false
        }
    elseif window_type == "horizontal" then
        -- Use NvChad's horizontal terminal runner
        require("nvchad.term").runner {
            pos = "sp",
            cmd = command,
            id = "htoggleTerm",
            clear_cmd = false
        }
    elseif window_type == "float" then
        -- Use NvChad's float terminal runner
        require("nvchad.term").runner {
            pos = "float",
            cmd = command,
            id = "floatTerm",
            clear_cmd = false
        }
    else
        vim.notify("Invalid launch type: " .. window_type, vim.log.levels.ERROR)
        return
    end
    
    -- Save as last command in memory
    save_last_command_info(command, window_type)
    
    vim.notify("Running: " .. command, vim.log.levels.INFO)
end

-- Create floating window
local function create_floating_window(commands, launch_type)
    if #commands == 0 then
        vim.notify("No saved commands found in current directory", vim.log.levels.INFO)
        return
    end
    
    -- Create display items with numbers
    local display_items = {}
    for i, cmd in ipairs(commands) do
        local number_str = string.format("%2d", i)
        local display_text = string.format("[%s] %s", number_str, cmd.name)
        table.insert(display_items, {
            index = i,
            command = cmd,
            display = display_text
        })
    end

    vim.ui.select(display_items, {
        prompt = "Select a command to run:",
        format_item = function(item)
            return item.display
        end,
    }, function(choice)
        if choice then
            local selected_cmd = choice.command
            execute_command(selected_cmd.command, launch_type)
        end
    end)
end

-- Main functions
function M.launch_vertical()
    local commands = read_cmd_bookmarks()
    create_floating_window(commands, "vertical")
end

function M.launch_horizontal()
    local commands = read_cmd_bookmarks()
    create_floating_window(commands, "horizontal")
end

function M.launch_float() 
  local commands = read_cmd_bookmarks()
  create_floating_window(commands, "float")
end

function M.launch_last()
    if not last_command or not last_window_type then
        vim.notify("No previous command found to run", vim.log.levels.WARN)
        return
    end
    
    execute_command(last_command, last_window_type)
end

-- Setup function
function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
    
    -- Create user commands
    vim.api.nvim_create_user_command("LaunchVert", M.launch_vertical, {
        desc = "Launch saved commands in vertical terminal"
    })
    
    vim.api.nvim_create_user_command("LaunchHoriz", M.launch_horizontal, {
        desc = "Launch saved commands in horizontal terminal"
    })

    vim.api.nvim_create_user_command("LaunchFloat", M.launch_float, {
        desc = "Launch saved commands in floating window"
    })
    
    vim.api.nvim_create_user_command("LaunchLast", M.launch_last, {
        desc = "Launch the last run command in the same window type"
    })
end

M.setup()

return M
