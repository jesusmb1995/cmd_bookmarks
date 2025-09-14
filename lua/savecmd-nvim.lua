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
    
    -- Read bookmarks file and track line numbers
    local lines = vim.fn.readfile(bookmarks_file)
    for line_num, line in ipairs(lines) do
        local name, cmd = line:match("^([^|]+)|(.+)$")
        if name and cmd then
            table.insert(commands, {
                name = name,
                command = cmd,
                last_used = 0,
                line_number = line_num  -- Track line number for editing
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

-- Open bookmarks file for editing at specific line
local function edit_bookmarks_file(line_number)
    local cwd = get_cwd()
    local bookmarks_file = cwd .. "/.local_cmd_bookmarks"
    
    -- Check if bookmarks file exists
    if vim.fn.filereadable(bookmarks_file) == 0 then
        vim.notify("No bookmarks file found in current directory", vim.log.levels.WARN)
        return
    end
    
    -- Open the file and jump to the specified line
    vim.cmd("edit " .. vim.fn.fnameescape(bookmarks_file))
    if line_number then
        vim.cmd("normal! " .. line_number .. "G")
    end
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

-- Write stats to file
local function write_cmd_stats(command_name)
    local cwd = get_cwd()
    local stats_file = cwd .. "/.local_cmd_bookmarks_stats"
    local timestamp = os.time()
    
    -- Read existing stats
    local stats = {}
    if vim.fn.filereadable(stats_file) == 1 then
        local stats_lines = vim.fn.readfile(stats_file)
        for _, line in ipairs(stats_lines) do
            local name, ts = line:match("^([^|]+)|(.+)$")
            if name and ts then
                stats[name] = ts
            end
        end
    end
    
    -- Update the timestamp for this command
    stats[command_name] = timestamp
    
    -- Write back to file
    local lines = {}
    for name, ts in pairs(stats) do
        table.insert(lines, name .. "|" .. ts)
    end
    
    vim.fn.writefile(lines, stats_file)
end

-- Execute command with specified window type
local function execute_command(command, window_type, command_name)
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
    
    -- Update timestamp if command_name is provided
    if command_name then
        write_cmd_stats(command_name)
    end
    
    -- Save as last command in memory
    save_last_command_info(command, window_type)
    
    vim.notify("Running: " .. command, vim.log.levels.INFO)
end

-- Create floating window with Telescope
local function create_floating_window(commands, launch_type)
    if #commands == 0 then
        vim.notify("No saved commands found in current directory", vim.log.levels.INFO)
        return
    end
    
    -- Check if Telescope is available
    local telescope_available = pcall(require, 'telescope')
    
    if not telescope_available then
        -- Fallback to vim.ui.select if Telescope is not available
        local display_items = {}
        for i, cmd in ipairs(commands) do
            local number_str = string.format("%2d", i)
            local display_text = string.format("[%s] %s", number_str, cmd.name)
            table.insert(display_items, {
                index = i,
                command = cmd,
                display = display_text,
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
                execute_command(selected_cmd.command, launch_type, selected_cmd.name)
            end
        end)
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
            display = display_text,
            preview_content = string.format("\n[%s] %s\n\n%s", 
                cmd.name,
                cmd.last_used > 0 and os.date("%Y-%m-%d %H:%M:%S", cmd.last_used) or "Never",
                cmd.command
            )
        })
    end

    -- Use Telescope directly
    require('telescope.pickers').new({}, {
        prompt_title = "Select a command to run:",
        finder = require('telescope.finders').new_table({
            results = display_items,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.display,
                    ordinal = entry.display,
                }
            end,
        }),
        sorter = require('telescope.sorters').get_generic_fuzzy_sorter(),
        previewer = require('telescope.previewers').new_buffer_previewer({
            title = "Command Details",
            define_preview = function(self, entry, status)
                local preview_text = entry.value.preview_content or "No preview available"
                
                -- Get the actual window width for dynamic wrapping
                local win_width = vim.api.nvim_win_get_width(0) -- Get current window width
                local wrap_width = math.max(20, win_width - 4) -- Leave some margin, minimum 20 chars
                
                -- Manual text wrapping function
                local function wrap_text(text, width)
                    local lines = {}
                    local words = vim.split(text, '%s+')
                    local current_line = ""
                    
                    for _, word in ipairs(words) do
                        if #current_line + #word + 1 <= width then
                            if current_line == "" then
                                current_line = word
                            else
                                current_line = current_line .. " " .. word
                            end
                        else
                            if current_line ~= "" then
                                table.insert(lines, current_line)
                            end
                            current_line = word
                        end
                    end
                    if current_line ~= "" then
                        table.insert(lines, current_line)
                    end
                    return lines
                end
                
                -- Split by newlines first, then wrap each line
                local original_lines = vim.split(preview_text, '\n')
                local wrapped_lines = {}
                
                for _, line in ipairs(original_lines) do
                    if #line <= wrap_width then
                        table.insert(wrapped_lines, line)
                    else
                        local wrapped = wrap_text(line, wrap_width)
                        for _, wrapped_line in ipairs(wrapped) do
                            table.insert(wrapped_lines, wrapped_line)
                        end
                    end
                end
                
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, wrapped_lines)
            end,
        }),
        attach_mappings = function(prompt_bufnr, map)
            local actions = require('telescope.actions')
            
            -- Default action: run command
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = require('telescope.actions.state').get_selected_entry()
                if selection then
                    local selected_cmd = selection.value.command
                    execute_command(selected_cmd.command, launch_type, selected_cmd.name)
                end
            end)
            
            -- Ctrl+E: edit bookmarks file at selected line
            map('i', '<C-e>', function()
                actions.close(prompt_bufnr)
                local selection = require('telescope.actions.state').get_selected_entry()
                if selection then
                    local selected_cmd = selection.value.command
                    edit_bookmarks_file(selected_cmd.line_number)
                end
            end)
            
            -- Also support Ctrl+E in normal mode
            map('n', '<C-e>', function()
                actions.close(prompt_bufnr)
                local selection = require('telescope.actions.state').get_selected_entry()
                if selection then
                    local selected_cmd = selection.value.command
                    edit_bookmarks_file(selected_cmd.line_number)
                end
            end)
            
            return true
        end,
    }):find()
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
    
    execute_command(last_command, last_window_type, nil) -- No command_name for last command
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
