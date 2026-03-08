local M = {}



M.set_colors = function(highlights, highlight_files)
    local liotree_groups = {
        ["@liotree.comment.text"     ] = highlights.comments            ,
        ["@liotree.directory"        ] = highlights.dirname             ,
        ["@liotree.file"             ] = highlights.filename            ,
        ["@liotree.bar"              ] = highlights.pipebar             ,
        ["@liotree.leaf"             ] = highlights.branchend           ,
        ["@liotree.bridge"           ] = highlights.branch              ,
        ["@punctuation.bracket.open" ] = highlights.opendir             ,
        ["@punctuation.bracket.close"] = highlights.closedir            ,
        ["@conceal.delimiter.open"   ] = highlights.conceal.opendir     ,
        ["@conceal.delimiter.closed" ] = highlights.conceal.closedir    ,
        ["@conceal.root"             ] = highlights.conceal.rootsymbol  ,
        ["@conceal.entry"            ] = highlights.conceal.entry       ,
        ["@conceal.comment.bar"      ] = highlights.conceal.commentpipe ,
        ["@conceal.line"             ] = highlights.conceal.line        ,
        ["@conceal.pipe"             ] = highlights.conceal.pipebar     ,
        ["@conceal.dir"              ] = highlights.conceal.dirsymbol   ,
        ["@conceal.file"             ] = highlights.conceal.filesymbol  ,
        ["conceal.comment.open"      ] = highlights.conceal.opencomment ,
        ["conceal.comment.closed"    ] = highlights.conceal.closecomment,
        ["conceal.formatspace"       ] = highlights.conceal.formatspace ,
    }

    local hl = vim.api.nvim_set_hl
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = highlight_files,
      callback = function()
        for group, settings in pairs(liotree_groups) do
          if group ~= "" and settings ~= nil then
            hl(0, group, settings)
          end
        end
      end
    })
    -- If no treesitter parser is available, fallback to matchit
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

    local ns_id = vim.api.nvim_create_namespace("LiotreeDecor")
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        pattern = "*.liotree",
        callback = function(args)
            apply_liotree_decor(args.buf)
        end,
    })
end


local function apply_liotree_decor(bufnr)
    if vim.opt_local.conceallevel:get() == 0 then return end
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i, line in ipairs(lines) do
      -- if conceallevel =0 deactivate
        -- Use % to escape magic characters for literal matching
        -- We look for the start of the delimiter
        local s_open, e_open = line:find("|%=%-")
        local s_close, e_close = line:find("|%=%=")

        if s_open then
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, s_open - 1, {
                virt_text = {{ "┢┪⋄", "@conceal.delimiter.open" }},
                virt_text_pos = "overlay",
                hl_mode = "combine",
                -- This ensures the overlay ONLY covers exactly 3 characters
                end_col = s_open + 2, 
            })
        elseif s_close then
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, s_close - 1, {
                virt_text = {{ "┡┩⋄", "@conceal.delimiter.closed" }},
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
    end
end


return M
