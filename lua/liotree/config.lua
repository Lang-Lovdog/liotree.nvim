local parser   = require("liotree.parser")
local decor    = require("liotree.decor")
local summoner = require("liotree.summoner")

local M = {}

M.picker = "telescope"
-- Pattern list of files where the liotree should be concealed
M.liotree_affected_files = {}
-- [0] No, [1] Yes
M.open_non_existent_file = 1
-- [0] No, [1] Ask, [2] Yes
M.create_non_existent_dir = 1
parser.set_conf({
    open_non_existent_file = M.open_non_existent_file,
    create_non_existent_dir = M.create_non_existent_dir,
})

local highlights   = {
  comments   = { fg="#66ddee",             italic=true , force=false,                },
  dirname    = { fg="#ffdd88", bold=true ,               force=true ,                },
  filename   = { fg="#ffffbb",                           force=true ,                },
  pipebar    = { fg="#00dd44",             italic=false, force=true ,                },
  branchend  = { fg="#00dd44", bold=true , italic=false, force=true ,                },
  branch     = { fg="#00dd44",             italic=false, force=true ,                },
  opendir    = { fg="#fb0bdb", bold=true , italic=false, force=true ,                },
  closedir   = { fg="#f72cf7", bold=false, italic=false, force=true ,                },
  conceal    = {
    opendir      = { fg="#88ff00", bold=true , italic=false, force=true ,                },
    closedir     = { fg="#00ff88", bold=true ,               force=true ,                },
    rootsymbol   = { fg="#ffffff",                                                       },
    entry        = { fg="#00dd44",                                                       },
    commentpipe  = { fg="#00dd44",                                                       },
    line         = { fg="#00dd44",                                                       },
    pipebar      = { fg="#00dd44",                                                       },
    dirsymbol    = { fg="#eeaa77",                                                       },
    filesymbol   = { fg="#aabb00",                                                       },
    opencomment  = {                                                                     },
    closecomment = {                                                                     },
    formatspace  = { bg="#ffff00",                                                       }
  
  }
}

M.keymaps = {
--    ["<CR>"]         = "opener"              ,
--    ["<leader> lmk"] = "set_mark_copy_ref"   ,
--    ["<leader> lmc"] = "clear_mark_copy_ref" ,
--    ["<leader> lcp"] = "copy_path"           ,
}

M.functions = {
    ["LiotreeOpen"]               = "opener"              ,
    ["LiotreeSummon"]             = "liotree_summon"      ,
    ["LiotreeSetCopyReference"]   = "set_mark_copy_ref"   ,
    ["LiotreeClearCopyReference"] = "clear_mark_copy_ref" ,
    ["LiotreeCopyPath"]           = "copy_path"           ,
}

M.setup = function(opts)
  local highlight_files = { "*.liotree" }
  set_filetype_stuff()
  if opts == nil then opts = {} end
  for k, v in pairs(opts) do
    M[k] = v
  end
  vim.list_extend(highlight_files, M.liotree_affected_files)
  M.set_comands()
  M.set_keymaps()
  decor.set_colors(highlights, highlight_files)
end

local M.set_filetype_stuff = function ()
  vim.api.nvim_create_autocmd("FileType", {
  pattern = "*.liotree",
  callback = function()
      for k, v in pairs(M.keymaps) do
          if parser[v] then
              vim.keymap.set("n", k, parser[v], { buffer = true, silent = true })
          end
      end
  end,
  })
  vim.filetype.add({
    extension = {
      liotree = "liotree",
    },
  })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "*.liotree",
    callback = function()
      vim.treesitter.start()
    end,
  })
  vim.api.nvim_create_autocmd("BufNewFile", {
    pattern = "*.liotree",
    command = "set filetype=liotree",
  })
  vim.api.nvim_create_autocmd("BufRead", {
    pattern = "*.liotree",
    command = "set filetype=liotree",
  })
end

local M.set_comands = function()
    for k, v in pairs(M.functions) do
        if parser[v] ~= nil then
            vim.api.nvim_create_user_command(k, parser[v], {})
        elseif summoner[v] ~= nil then
            vim.api.nvim_create_user_command(k, summoner[v], {})
        end
    end
end


return M
