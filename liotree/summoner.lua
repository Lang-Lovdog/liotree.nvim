local M = {}

M.liotree_summon = function()
    -- Your standard map name
    local tree_name = "structure.liotree"
    
    -- Find it relative to the current file's directory or project root
    local path = vim.fn.findfile(tree_name, ".;")
    
    if path == "" then
        print("Liotree map not found: " .. tree_name)
        return
    end

    -- Just open it in the current window
    vim.cmd.edit(path)
end


return M
