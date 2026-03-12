local M = {}

local function get_parent_dirname_from_line(bufnr, line_num)
    local line_start = line_num - 1
    local ok, node = pcall(vim.treesitter.get_node, { pos = {line_start, 0}, bufnr = bufnr })
    if not ok or not node then return nil end
    while node do
        if node:type() == "directory_entry" then
            local name_node = node:field("name")[1]
            if name_node then
                local text = vim.treesitter.get_node_text(name_node, bufnr)
                -- Remove trailing slash and trim
                text = text:gsub("/%s*$", ""):gsub("^%s*(.-)%s*$", "%1")
                return text
            end
            break
        end
        node = node:parent()
    end
    return nil
end

local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
parser_config.liotree = {
  install_info = {
    url = "https://github.com/Lang-Lovdog/tree-sitter-liotree",
    files = {"src/parser.c"},
    branch = "main",
    queries = 'queries/liotree',
  },
  filetype = "liotree",
}

-- Install liotree parser once and for all
require("nvim-treesitter.install").ensure_installed({"liotree"})


local ns_id = vim.api.nvim_create_namespace("LiotreeDecor")

local function apply_liotree_decor(bufnr)
    if vim.opt_local.conceallevel:get() == 0 then return end
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local mode = vim.fn.mode()
    for i, line in ipairs(lines) do
        if mode:match("^i") and i == cursor_line then
            goto continue
        end
        -- if conceallevel =0 deactivate
        -- Use % to escape magic characters for literal matching
        -- We look for the start of the delimiter
        local s_open, e_open = line:find("|%=%-")
        local s_close, e_close = line:find("|%=%=")

        if s_open then
            local dirname = get_parent_dirname_from_line(bufnr, i)
            local virt = { { "┢┪⋄", "@conceal.delimiter.open" } }
            if dirname then
                table.insert(virt, { "  ::  " .. dirname, "@liotree.directory.indicator" })
            end
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, s_open - 1, {
                virt_text = virt,
                virt_text_pos = "overlay",
                hl_mode = "combine",
                end_col = s_open + 2,
            })
        elseif s_close then
            local dirname = get_parent_dirname_from_line(bufnr, i)
            local virt = { { "┡┩⋄", "@conceal.delimiter.closed" } }
            if dirname then
                table.insert(virt, { "  ::  " .. dirname, "@liotree.directory.indicator" })
            end
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, s_close - 1, {
                virt_text = virt,
                virt_text_pos = "overlay",
                hl_mode = "combine",
                end_col = s_close + 2,
            })
        end
        local s_bar, e_bar = line:find("|%s%s+") 
        if s_bar then
            -- We only want to conceal the space, which is at position s_bar + 1
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, s_bar, {
                virt_text = {{ "│", "@conceal.comment.bar" }}, -- Or "⋄" if you want a connector
                virt_text_pos = "overlay",
                -- Only overlay the second character (the space)
                end_col = s_bar + 1, 
            })
        end
        local s_pat, e_pat = line:find(";.-;")
        if s_pat then
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, s_pat - 1, {
                -- Other possible conceals ║«
                virt_text = {{ "▐", "@liotree.directory" }}, -- Use a "Pattern" symbol
                virt_text_pos = "overlay",
                end_col = s_pat,
            })
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, e_pat - 1, {
                -- Other possible conceals ◢»
                virt_text = {{ "⮞", "@liotree.directory" }},
                virt_text_pos = "overlay",
                end_col = e_pat,
            })
        end
        ::continue::
    end
        -- ========== Error checking for mismatched delimiters ==========
    local stack = {}          -- each element: {line = i, col = s_open}
    local errors = {}         -- each element: {line = i, col = s, type = "open"|"close"}

    for i, line in ipairs(lines) do
        local s_open = line:find("|=%-")
        local s_close = line:find("|==")

        if s_open then
            table.insert(stack, {line = i, col = s_open})
        elseif s_close then
            if #stack == 0 then
                -- unmatched closing delimiter
                table.insert(errors, {line = i, col = s_close, type = "close"})
            else
                table.remove(stack)   -- matched, pop the most recent open
            end
        end
    end

    -- Any remaining opens are unmatched
    for _, item in ipairs(stack) do
        table.insert(errors, {line = item.line, col = item.col, type = "open"})
    end

    -- Place error extmarks with virtual text
    for _, err in ipairs(errors) do
        local virt = {}
        if err.type == "open" then
            local dirname = get_parent_dirname_from_line(bufnr, err.line)
            if dirname then
                table.insert(virt, { "Not closed: " .. dirname, "@liotree.directory.indicator.error" })
            else
                table.insert(virt, { "Not closed", "@liotree.directory.indicator.error" })
            end
        else -- close
            table.insert(virt, { "Unexpected closing", "@liotree.directory.indicator.error" })
        end

        vim.api.nvim_buf_set_extmark(bufnr, ns_id, err.line - 1, err.col - 1, {
            end_col = err.col + 2,        -- highlight the three characters of the delimiter
            hl_group = "LiotreeError",
            virt_text = virt,
            virt_text_pos = "inline",      -- appears right after the highlighted area
            priority = 200,
        })
    end
end

M.set_colors = function(highlights, highlight_files)
    local liotree_groups = {
        ["@liotree.comment.text"              ] = highlights.comments                     ,
        ["@liotree.directory"                 ] = highlights.dirname                      ,
        ["@liotree.file"                      ] = highlights.filename                     ,
        ["@liotree.bar"                       ] = highlights.pipebar                      ,
        ["@liotree.leaf"                      ] = highlights.branchend                    ,
        ["@liotree.bridge"                    ] = highlights.branch                       ,
        ["@punctuation.bracket.open"          ] = highlights.opendir                      ,
        ["@punctuation.bracket.close"         ] = highlights.closedir                     ,
        ["@conceal.delimiter.open"            ] = highlights.conceal.opendir              ,
        ["@conceal.delimiter.closed"          ] = highlights.conceal.closedir             ,
        ["@conceal.root"                      ] = highlights.conceal.rootsymbol           ,
        ["@conceal.entry"                     ] = highlights.conceal.entry                ,
        ["@conceal.comment.bar"               ] = highlights.conceal.commentpipe          ,
        ["@conceal.line"                      ] = highlights.conceal.line                 ,
        ["@conceal.pipe"                      ] = highlights.conceal.pipebar              ,
        ["@conceal.dir"                       ] = highlights.conceal.dirsymbol            ,
        ["@conceal.file"                      ] = highlights.conceal.filesymbol           ,
        ["@conceal.comment.open"              ] = highlights.conceal.opencomment          ,
        ["@conceal.comment.closed"            ] = highlights.conceal.closecomment         ,
        ["@conceal.formatspace"               ] = highlights.conceal.formatspace          ,
        ["@liotree.directory.indicator"       ] = highlights.conceal.dirlimitname         ,
        ["@liotree.directory.indicator.error" ] = highlights.conceal.dirlimiterror        ,
        ["@liotree.error"                     ] = highlights.conceal.error                ,
    }

    local hl = vim.api.nvim_set_hl
    for group, settings in pairs(liotree_groups) do
      if group ~= "" and settings ~= nil then
        hl(0, group, settings)
      end
    end
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = highlight_files,
      callback = function()
        callback = function(args)
            apply_liotree_decor(args.buf)
        end
        for group, settings in pairs(liotree_groups) do
          if group ~= "" and settings ~= nil then
            hl(0, group, settings)
          end
        end
      end
    })
    -- If no treesitter parser is available, fallback to matchit
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "liotree",
      callback = function()
        -- The "Golden Standard" for Tree-sitter folding
        vim.opt_local.foldmethod = "expr"
        vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        
        -- Start with the tree expanded so you can see your Cyan comments
        vim.opt_local.foldlevel = 99
      end,
    })
    vim.api.nvim_create_autocmd("BufReadPost", {
      pattern = "*.liotree",
      callback = function()
        -- The "Golden Standard" for Tree-sitter folding
        vim.opt_local.foldmethod = "expr"
        vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        
        -- Start with the tree expanded so you can see your Cyan comments
        vim.opt_local.foldlevel = 99
      end,
    })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        pattern = "*.liotree",
        callback = function(args)
            apply_liotree_decor(args.buf)
        end,
    })
    vim.api.nvim_create_autocmd({ "InsertEnter", "CursorMovedI" }, {
        pattern = "*.liotree",
        callback = function(args)
            apply_liotree_decor(args.buf)
        end,
    })
end


return M
