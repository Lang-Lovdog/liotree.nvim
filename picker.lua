local M = {}

local function get_contextual_prompt(full_path, title_prefix)
    -- 1. SANITIZE: Remove trailing slash if it exists 
    -- (so :h doesn't get confused)
    local clean_path = full_path:gsub("/$", "")
    
    local parent = vim.fn.fnamemodify(clean_path, ":h")
    local buffer_dir = vim.fn.expand("%:p:h")
    
    -- 2. RELATIVE MAPPING
    -- We use vim.pesc to treat buffer_dir as a literal string
    local relative_parent = parent:gsub("^" .. vim.pesc(buffer_dir .. "/"), "")
    
    -- Handle the case where the parent IS the buffer_dir
    if relative_parent == parent then
        relative_parent = "./"
    end
    
    -- 3. TRUNCATION
    if #relative_parent > 40 then
        relative_parent = "..." .. relative_parent:sub(-37)
    end
    
    return title_prefix .. " [" .. relative_parent .. "]"
end

M.lio_picker = function (results, title_prefix, callback)
    if not results or #results == 0 then return end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    -- Use the first result to determine the "Parent Context" for the title
    local dynamic_title = get_contextual_prompt(results[1], title_prefix)

    pickers.new({}, {
        prompt_title = dynamic_title,
        finder = finders.new_table({
            results = results,
            entry_maker = function(entry)
                -- THE SELECTOR: Only show the Basename (the 'tail')
                -- Remove trailing space if dir
                entry = entry:gsub("/%s*$", "") 
                local basename = vim.fn.fnamemodify(entry, ":t")
                if vim.fn.isdirectory(entry) == 1 then
                    basename = basename .. "/"
                end

                return {
                    value = entry,
                    display = basename,
                    ordinal = basename, -- Search by the actual filename
                }
            end
        }),
        previewer = conf.file_previewer({}),
        sorter = conf.generic_sorter({}),
        layout_strategy = "horizontal",
        layout_config = {
            width = 0.95,
            preview_width = 0.6,
        },
        attach_mappings = function(prompt_bufnr, map)
            -- Force wrap in previewer
            map('i', '<Tab>', function(bufnr)
                actions.move_selection_next(bufnr)
                local picker = action_state.get_current_picker(bufnr)
                if picker.previewer and picker.previewer.state.bufnr then
                    vim.api.nvim_buf_set_option(picker.previewer.state.bufnr, "wrap", true)
                end
            end)

            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                callback(selection.value)
            end)
            return true
        end,
    }):find()
end

return M
