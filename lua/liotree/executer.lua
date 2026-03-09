-- lua/liotree/executer.lua
local lio_picker = require("liotree.picker").lio_picker

local executers = {}
local select_methods = {}

local M = {}

M.setup = function(ex, sel)
    executers = ex or {}
    select_methods = sel or {}
end


M.execute = function(absolute_path, mark)
    local basename = vim.fn.fnamemodify(absolute_path, ":t")
    local matched_cmd, matched_pattern

    for pattern, cmd in pairs(executers) do
        if basename == pattern or string.match(basename, pattern) then
            matched_cmd = cmd
            matched_pattern = pattern
            break
        end
    end
    if not matched_cmd then
        print("No executer found for " .. basename)
        return
    end

    -- Determine the directory to cd into
    local cd_dir
    if mark then
        cd_dir = mark   -- mark is already a directory (from parser)
    else
        cd_dir = vim.fn.fnamemodify(absolute_path, ":h")
    end

    -- Escape paths for shell
    local escaped_cd = vim.fn.shellescape(cd_dir)
    local escaped_this = vim.fn.shellescape(absolute_path)

    -- Replace placeholders
    local cmd = matched_cmd
    cmd = cmd:gsub("__path__", escaped_cd)
    cmd = cmd:gsub("__this__", escaped_this)

    -- Handle __select__ placeholder
    if cmd:find("__select__") then
        local method = select_methods[matched_pattern]
        if not method then
            print("No select method for " .. matched_pattern)
            return
        end

        local choices = {}
        if method == "make_targets" then
            -- Simple Makefile target parser
            local f = io.open(absolute_path, "r")
            if f then
                for line in f:lines() do
                    local target = line:match("^([%w_%-]+)%s*:")
                    if target then table.insert(choices, target) end
                end
                f:close()
            end
        elseif type(method) == "function" then
            choices = method(absolute_path)
        else
            print("Invalid select method")
            return
        end

        if #choices == 0 then
            print("No selectable items")
            return
        end

        -- Show picker and run command with selected target
        lio_picker(choices, "Select target", function(choice)
            local final_cmd = cmd:gsub("__select__", vim.fn.shellescape(choice))
            vim.cmd("!" .. final_cmd)
        end)
        return
    end

    -- No __select__: run command immediately
    vim.cmd("!" .. cmd)
end


return M
